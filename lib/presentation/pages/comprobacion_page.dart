import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/documento_esperado.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../providers/comprobacion_provider.dart';

/// Comprobación de un albarán (compra) o factura (venta) mediante lecturas:
/// al recepcionar o expedir mercancía se verifica si falta o sobra algo.
class ComprobacionPage extends StatefulWidget {
  final TipoOperacion tipo;

  const ComprobacionPage({super.key, required this.tipo});

  @override
  State<ComprobacionPage> createState() => _ComprobacionPageState();
}

class _ComprobacionPageState extends State<ComprobacionPage> {
  final TextEditingController _numeroController = TextEditingController();

  static const Color _azul = Color.fromARGB(255, 0, 47, 108);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ComprobacionProvider>().fijarTipo(widget.tipo);
    });
  }

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  bool get _esCompra => widget.tipo == TipoOperacion.compra;

  String get _nombreDoc => _esCompra ? 'albarán' : 'factura';

  Color _colorEstado(EstadoLinea estado) {
    switch (estado) {
      case EstadoLinea.completa:
        return Colors.green;
      case EstadoLinea.parcial:
        return Colors.deepPurple;
      case EstadoLinea.pendiente:
        return Colors.orange;
      case EstadoLinea.sobrante:
        return Colors.red;
    }
  }

  String _textoEstado(EstadoLinea estado) {
    switch (estado) {
      case EstadoLinea.completa:
        return 'Completa';
      case EstadoLinea.parcial:
        return 'Parcial';
      case EstadoLinea.pendiente:
        return 'Pendiente';
      case EstadoLinea.sobrante:
        return 'Sobrante';
    }
  }

  String _fmtCantidad(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  Future<void> _mostrarDialogoLinea(ComprobacionProvider provider) async {
    final refCtrl = TextEditingController();
    final codCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController();
    final loteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Añadir línea esperada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Referencia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de barras (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cantidad esperada',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: loteCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Lote (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final cantidad = double.tryParse(cantCtrl.text.trim()) ?? 0.0;
      await provider.agregarLinea(
        referencia: refCtrl.text,
        codigoBarras: codCtrl.text,
        descripcion: descCtrl.text,
        cantidad: cantidad,
        lote: loteCtrl.text,
      );
      if (mounted && provider.state == ComprobacionState.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    refCtrl.dispose();
    codCtrl.dispose();
    descCtrl.dispose();
    cantCtrl.dispose();
    loteCtrl.dispose();
  }

  Future<void> _confirmarBorrarDocumento(
    ComprobacionProvider provider,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text('Borrar documento'),
        content: const Text(
          'Se eliminará el documento y sus líneas de la caché local.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _numeroController.clear();
      await provider.borrarDocumento();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComprobacionProvider>();
    final doc = provider.documento;
    final res = provider.resultado;
    final cargando = provider.state == ComprobacionState.loading ||
        provider.state == ComprobacionState.saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esCompra ? 'Comprobar Compra' : 'Comprobar Venta'),
        centerTitle: true,
        actions: [
          if (doc != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recomparar con lecturas',
              onPressed:
                  cargando ? null : () => provider.refrescar(),
            ),
          if (doc != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Borrar documento',
              onPressed: cargando
                  ? null
                  : () => _confirmarBorrarDocumento(provider),
            ),
        ],
      ),
      floatingActionButton: doc == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .pushNamed(_esCompra ? '/compra' : '/venta')
                    .then((_) {
                  if (mounted) provider.refrescar();
                });
              },
              label: const Text(
                'Escanear',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              elevation: 4,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: cargando && doc == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _tarjetaDocumento(provider),
                    if (provider.state == ComprobacionState.error &&
                        provider.errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          provider.errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (doc != null) ...[
                      const SizedBox(height: 12),
                      _tarjetaResumen(res),
                      const SizedBox(height: 12),
                      _cabeceraLineas(provider),
                      ..._listaLineas(res, provider),
                      if (res != null && res.sinLinea.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _seccionSinLinea(res),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tarjetaDocumento(ComprobacionProvider provider) {
    final doc = provider.documento;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Documento de $_nombreDoc',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numeroController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Número de $_nombreDoc',
                prefixIcon: const Icon(Icons.receipt_long),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: (_) =>
                  provider.cargarDocumento(_numeroController.text),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        provider.cargarDocumento(_numeroController.text),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Cargar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.crearDocumentoVacio(
                      _numeroController.text,
                    ),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Nuevo manual'),
                  ),
                ),
              ],
            ),
            if (doc != null) ...[
              const SizedBox(height: 8),
              Text(
                'Nº ${doc.numero}'
                '${doc.tercero != null && doc.tercero!.isNotEmpty ? ' · ${doc.tercero}' : ''}'
                ' · ${doc.lineas.length} líneas',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            if (provider.avisoRemoto.isNotEmpty && doc != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  provider.avisoRemoto,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaResumen(ResultadoComprobacion? res) {
    if (res == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (res.estaCompleto) {
      return const Card(
        color: Colors.green,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Documento completo: nada falta ni sobra',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final faltanLineas = res.pendientes + res.parciales;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                _chipResumen('Completas', res.completas, Colors.green),
                _chipResumen('Parciales', res.parciales, Colors.deepPurple),
                _chipResumen('Pendientes', res.pendientes, Colors.orange),
                _chipResumen('Sobrantes', res.sobrantes, Colors.red),
                if (res.sinLinea.isNotEmpty)
                  _chipResumen(
                    'Sin línea',
                    res.sinLinea.length,
                    Colors.red.shade700,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (faltanLineas > 0)
              Text(
                'Faltan ${_fmtCantidad(res.unidadesFaltantes)} uds. en $faltanLineas línea(s)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (res.unidadesSobrantes > 0)
              Text(
                'Sobran ${_fmtCantidad(res.unidadesSobrantes)} uds. en ${res.sobrantes} línea(s)',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (res.sinLinea.isNotEmpty)
              Text(
                '${res.sinLinea.length} lectura(s) fuera de documento',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (faltanLineas == 0 &&
                res.unidadesSobrantes == 0 &&
                res.sinLinea.isEmpty)
              const Text(
                'Documento correcto',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipResumen(String texto, int valor, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$valor',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(texto),
    );
  }

  Widget _cabeceraLineas(ComprobacionProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Líneas esperadas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: () => _mostrarDialogoLinea(provider),
          icon: const Icon(Icons.add),
          label: const Text('Añadir línea'),
        ),
      ],
    );
  }

  List<Widget> _listaLineas(
    ResultadoComprobacion? res,
    ComprobacionProvider provider,
  ) {
    if (res == null) return [];
    if (res.lineas.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sin líneas. Añádalas a mano o cárguelas del servidor cuando el endpoint esté disponible.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }
    return List.generate(res.lineas.length, (i) {
      final lc = res.lineas[i];
      final color = _colorEstado(lc.estado);
      final desc = (lc.esperada.descripcion ?? '').trim();
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            child: Text(
              _fmtCantidad(lc.cantidadLeida),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            desc.isNotEmpty ? desc : 'Ref. ${lc.esperada.referencia}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Ref. ${lc.esperada.referencia}'
            '${lc.esperada.lote != null && lc.esperada.lote!.isNotEmpty ? ' · Lote ${lc.esperada.lote}' : ''}\n'
            'Leído ${_fmtCantidad(lc.cantidadLeida)} de ${_fmtCantidad(lc.esperada.cantidadEsperada)} · ${_textoEstado(lc.estado)}',
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            tooltip: 'Quitar línea',
            onPressed: () => provider.borrarLinea(i),
          ),
        ),
      );
    });
  }

  Widget _seccionSinLinea(ResultadoComprobacion res) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Leído sin línea en el documento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in res.sinLinea)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '• ${s.referencia} (${s.codigo})'
                  '${s.lote != null && s.lote!.isNotEmpty ? ' [L: ${s.lote}]' : ''}'
                  ': ${_fmtCantidad(s.cantidad)}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
