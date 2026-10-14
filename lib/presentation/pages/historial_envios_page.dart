import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/database_helper.dart';
import '../providers/lector_provider.dart';
import '../../domain/entities/lectura.dart';

class HistorialEnviosPage extends StatefulWidget {
  const HistorialEnviosPage({super.key});

  @override
  State<HistorialEnviosPage> createState() => _HistorialEnviosPageState();
}

class _HistorialEnviosPageState extends State<HistorialEnviosPage> {
  DateTime _fechaSeleccionada = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Set<DateTime> _diasConDatos = {};
  bool _mostrarCalendario = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      final lectorProvider = context.read<LectorProvider>();
      await lectorProvider.obtenerHistorialPorFecha(_fechaSeleccionada);
      
      if (!mounted) return;
      await _cargarDiasConDatos();
    });
  }

  Future<void> _cargarDiasConDatos() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT DISTINCT substr(${DatabaseHelper.colFechaEnvio}, 1, 10) AS dia
        FROM ${DatabaseHelper.tableNameLecturas}
        WHERE ${DatabaseHelper.colSincronizado} = 1
          AND ${DatabaseHelper.colFechaEnvio} IS NOT NULL
        ORDER BY dia DESC
      ''');

      final Set<DateTime> fechas = {};
      for (final row in rows) {
        final String? diaStr = row['dia'] as String?;
        if (diaStr == null) continue;
        try {
          final partes = diaStr.split('-');
          if (partes.length == 3) {
            fechas.add(
              DateTime(
                int.parse(partes[0]),
                int.parse(partes[1]),
                int.parse(partes[2]),
              ),
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _diasConDatos = fechas;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [HISTORIAL] Error cargando días con envíos: $e');
    }
  }

  Future<void> _exportarTxt() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<LectorProvider>();
    final registros = provider.historialLecturas;
    
    if (registros.isEmpty) return;

    String contenido = 'COMPROBANTE DE SINCRONIZACIÓN - API\n'
        'FECHA DE CONSULTA: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}\n'
        'FECHA DE REGISTROS: ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)}\n'
        '==========================================\n\n';

    for (final r in registros) {
      final hora = r.fechaEnvio != null
          ? DateFormat('HH:mm:ss').format(r.fechaEnvio!)
          : '--:--';
      contenido += '[$hora] COD: ${r.codigoArticulo}\n'
          'REF: ${r.referenciaArticulo} | CANT: ${r.cantidad.toInt()}\n'
          'LOTE: ${r.lote ?? "-"}\n'
          'DESC: ${r.descripcion ?? "-"}\n'
          '------------------------------------------\n';
    }

    try {
      final directory = await getTemporaryDirectory();
      final fechaStr = DateFormat('yyyyMMdd').format(_fechaSeleccionada);
      final file = File('${directory.path}/comprobante_envio_$fechaStr.txt');
      await file.writeAsString(contenido);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Comprobante de envíos $fechaStr',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al exportar comprobante: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarLimpieza() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purga de Seguridad (90 días)'),
        content: const Text(
          'Esta acción eliminará permanentemente de este dispositivo los registros sincronizados con más de 3 meses de antigüedad.\n\n¿Desea proceder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MANTENER DATOS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final lectorProvider = context.read<LectorProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);

              final borrados = await lectorProvider.limpiarHistorialAntiguo();

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Auditoría completada: $borrados registros antiguos eliminados.',
                  ),
                ),
              );

              if (mounted) {
                await lectorProvider.obtenerHistorialPorFecha(_fechaSeleccionada);
                await _cargarDiasConDatos();
              }
            },
            child: const Text(
              'LIMPIAR LOCAL',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LectorProvider>();
    final registros = provider.historialLecturas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría de Envíos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir Comprobante',
            onPressed: registros.isEmpty ? null : _exportarTxt,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Limpiar antiguos',
            onPressed: _confirmarLimpieza,
          ),
          IconButton(
            icon: Icon(_mostrarCalendario ? Icons.keyboard_arrow_up : Icons.event_note),
            tooltip: 'Cambiar Fecha',
            onPressed: () => setState(() => _mostrarCalendario = !_mostrarCalendario),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mostrarCalendario) _buildCalendarioInteractivo(),
          _buildHeaderInfo(registros.length),
          Expanded(
            child: registros.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: registros.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) =>
                        _buildItemHistorial(registros[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarioInteractivo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: TableCalendar(
        locale: 'es_ES',
        firstDay: DateTime.now().subtract(const Duration(days: 90)),
        lastDay: DateTime.now(),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_fechaSeleccionada, day),
        onDaySelected: (selectedDay, focusedDay) async {
          setState(() {
            _fechaSeleccionada = selectedDay;
            _focusedDay = focusedDay;
            _mostrarCalendario = false;
          });
          final provider = context.read<LectorProvider>();
          await provider.obtenerHistorialPorFecha(selectedDay);
        },
        eventLoader: (day) {
          // Buscamos si el día evaluado está en nuestro Set de la DB
          final bool tieneDatos = _diasConDatos.any((d) => 
            d.year == day.year && d.month == day.month && d.day == day.day);
          return tieneDatos ? ['sincronizado'] : [];
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.green, //  PUNTO VERDE
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        border: const Border(
          bottom: BorderSide(color: Colors.green, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_outlined, color: Colors.green),
              const SizedBox(width: 10),
              Text(
                'Sincronizaciones del ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$total registros confirmados por el servidor',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No hay registros sincronizados\npara esta fecha.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildItemHistorial(Lectura item) {
    final hora = item.fechaEnvio != null
        ? DateFormat('HH:mm:ss').format(item.fechaEnvio!)
        : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                hora,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blueGrey,
                ),
              ),
              const Icon(Icons.arrow_downward, size: 12, color: Colors.grey),
              const Icon(Icons.computer, size: 16, color: Colors.green),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.descripcion ?? item.codigoArticulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Cod: ${item.codigoArticulo} | Ref: ${item.referenciaArticulo}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (item.lote != null && item.lote!.isNotEmpty)
                  Text(
                    'Lote: ${item.lote}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${item.cantidad.toInt()} uds',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
