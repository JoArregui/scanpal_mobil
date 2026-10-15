import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/lector_provider.dart';
// PRESENTACION: Ventas/Compras ocultos en Enviar Lecturas.
// import '../providers/compra_provider.dart';
// import '../providers/venta_provider.dart';
import '../providers/configuracion_provider.dart';

// Widgets
import '../widgets/loading_overlay.dart';

class EnviarLecturasPage extends StatefulWidget {
  const EnviarLecturasPage({super.key});

  @override
  State<EnviarLecturasPage> createState() => _EnviarLecturasPageState();
}

class _EnviarLecturasPageState extends State<EnviarLecturasPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargarTodosLosDatos();
      }
    });
  }

  void _cargarTodosLosDatos() {
    context.read<LectorProvider>().obtenerLecturasPendientes();
    // PRESENTACION: sin Compras/Ventas.
    // context.read<CompraProvider>().obtenerLecturasPendientes();
    // context.read<VentaProvider>().obtenerLecturasPendientes();
    context.read<ConfiguracionProvider>().cargarConfiguracion();
  }

  // --- LÓGICA DE SINCRONIZACIÓN GLOBAL ---

  Future<void> _sincronizarTodo() async {
    int totalEnviados = 0;
    List<String> errores = [];

    // 1. Sincronizar Inventario
    final invProv = context.read<LectorProvider>();
    if (invProv.registrosViewModel.isNotEmpty) {
      await invProv.enviarLecturasAlServidor();
      if (invProv.state == LectorState.sendSuccess) {
        totalEnviados += invProv.lecturasEnviadasCount;
      } else {
        errores.add("Inventario: ${invProv.errorMessage}");
      }
    }

    if (!mounted) return;

    // PRESENTACION: sincronización de Compras/Ventas oculta.
    // // 2. Sincronizar Compras
    // final compProv = context.read<CompraProvider>();
    // if (compProv.registrosViewModel.isNotEmpty) {
    //   await compProv.enviarComprasAlServidor();
    //   if (compProv.state == CompraState.sendSuccess) {
    //     totalEnviados += compProv.lecturasEnviadasCount;
    //   } else {
    //     errores.add("Compras: ${compProv.errorMessage}");
    //   }
    // }
    //
    // if (!mounted) return;
    //
    // // 3. Sincronizar Ventas
    // final ventProv = context.read<VentaProvider>();
    // if (ventProv.registrosViewModel.isNotEmpty) {
    //   await ventProv.enviarVentasAlServidor();
    //   if (ventProv.state == VentaState.sendSuccess) {
    //     totalEnviados += ventProv.lecturasEnviadasCount;
    //   } else {
    //     errores.add("Ventas: ${ventProv.errorMessage}");
    //   }
    // }
    //
    // if (!mounted) return;

    if (errores.isEmpty) {
      _mostrarDialogoExito(totalEnviados, "Total General");
    } else {
      _mostrarDialogoError("Sincronización parcial.\n\n${errores.join('\n')}");
    }
  }

  Future<void> _ejecutarSincronizacionIndividual(dynamic provider, String tipo) async {
    if (provider.registrosViewModel.isEmpty) return;
    
    if (tipo == "Inventario") {
      await provider.enviarLecturasAlServidor();
    }
    // PRESENTACION: sin Compras/Ventas.
    // else if (tipo == "Compras") {
    //   await provider.enviarComprasAlServidor();
    // } else if (tipo == "Ventas") {
    //   await provider.enviarVentasAlServidor();
    // }

    if (!mounted) return;

   
    bool isError = false;
    bool isSuccess = false;
    
    if (tipo == "Inventario") {
      isError = provider.state == LectorState.sendError;
      isSuccess = provider.state == LectorState.sendSuccess;
    }
    // PRESENTACION: estados de Compras/Ventas ocultos.
    // else if (tipo == "Compras") {
    //   isError = provider.state == CompraState.sendError;
    //   isSuccess = provider.state == CompraState.sendSuccess;
    // } else if (tipo == "Ventas") {
    //   isError = provider.state == VentaState.sendError;
    //   isSuccess = provider.state == VentaState.sendSuccess;
    // }

    if (isError) {
      _mostrarDialogoError("$tipo: ${provider.errorMessage}");
    } else if (isSuccess) {
      _mostrarDialogoExito(provider.lecturasEnviadasCount, tipo);
    }
  }

  // --- DIÁLOGOS ---

  void _mostrarDialogoExito(int cantidad, String tipo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Sincronización Exitosa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 10),
            Text(
              tipo == "Total General" ? "Resumen Global" : tipo,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),
            Text('Se han enviado $cantidad registros correctamente.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoError(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('Error de Envío', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invProv = context.watch<LectorProvider>();
    // PRESENTACION: sin Compras/Ventas.
    // final compProv = context.watch<CompraProvider>();
    // final ventProv = context.watch<VentaProvider>();
    
    final configProv = context.watch<ConfiguracionProvider>();
    final int cantidadMinima = configProv.configuracion.cantidadMinima;

    final bool isSyncing = invProv.state == LectorState.sendingLecturas;
    // PRESENTACION: estados de Compras/Ventas ocultos.
    // final bool isSyncing = invProv.state == LectorState.sendingLecturas ||
    //                        compProv.state == CompraState.sendingLecturas ||
    //                        ventProv.state == VentaState.sendingLecturas;

    final int totalPendiente = invProv.registrosViewModel.length;
    // PRESENTACION: total solo Inventario.
    // final int totalPendiente = invProv.registrosViewModel.length + 
    //                            compProv.registrosViewModel.length + 
    //                            ventProv.registrosViewModel.length;

    return LoadingOverlay(
      isLoading: isSyncing,
      message: 'Comunicando con el servidor...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enviar Lecturas'), 
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildTotalHeader(totalPendiente),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildExpansionTable(
                    titulo: "Inventario / Lecturas",
                    registros: invProv.registrosViewModel,
                    color: Colors.blue,
                    cantidadMin: cantidadMinima,
                    onSync: () => _ejecutarSincronizacionIndividual(invProv, "Inventario"),
                  ),
                  // PRESENTACION: secciones Compras/Ventas ocultas.
                  // const SizedBox(height: 12),
                  // _buildExpansionTable(
                  //   titulo: "Compras (Entradas)",
                  //   registros: compProv.registrosViewModel,
                  //   color: Colors.green,
                  //   cantidadMin: cantidadMinima,
                  //   onSync: () => _ejecutarSincronizacionIndividual(compProv, "Compras"),
                  // ),
                  // const SizedBox(height: 12),
                  // _buildExpansionTable(
                  //   titulo: "Ventas (Salidas)",
                  //   registros: ventProv.registrosViewModel,
                  //   color: Colors.orange,
                  //   cantidadMin: cantidadMinima,
                  //   onSync: () => _ejecutarSincronizacionIndividual(ventProv, "Ventas"),
                  // ),
                ],
              ),
            ),

      
            Padding(
             
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 70.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: isSyncing || totalPendiente == 0 ? null : _sincronizarTodo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload, color: Colors.white, size: 28),
                  label: Text(
                    isSyncing ? 'Sincronizando...' : 'Sincronizar Lecturas',
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers FIFO informativos (sin fecha al final, sin bloqueos) ---
  bool _estaCaducada(DateTime? f) {
    if (f == null) return false;
    final hoy = DateTime.now();
    return DateTime(f.year, f.month, f.day)
        .isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  String _fmtCadCorta(DateTime? f) {
    if (f == null) return '-';
    final dd = f.day.toString().padLeft(2, '0');
    final mm = f.month.toString().padLeft(2, '0');
    final yy = (f.year % 100).toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  Widget _buildTotalHeader(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text("REGISTROS TOTALES POR ENVIAR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text('$total', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildExpansionTable({
    required String titulo,
    required List<dynamic> registros,
    required Color color,
    required int cantidadMin,
    required VoidCallback onSync,
  }) {
    // FIFO informativo: ordenar por caducidad (sin fecha al final).
    final List<dynamic> ordenados = [...registros]..sort((a, b) {
      final DateTime? fa = a.lectura?.fechaCaducidad as DateTime?;
      final DateTime? fb = b.lectura?.fechaCaducidad as DateTime?;
      if (fa == null && fb == null) return 0;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: Icon(Icons.list_alt, color: color),
        title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        subtitle: Text("${registros.length} pendientes"),
        children: [
          if (registros.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text("No hay datos."))
          else ...[
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 25,
                  headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                  columns: const [
                    DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Lote', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Cad.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ref.', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: ordenados.map((vm) {
                    final bool esDescatalogado = vm.esDescatalogado;
                    final bool esCantidadBaja = vm.cantidad < cantidadMin;
                    final DateTime? fCad = vm.lectura?.fechaCaducidad as DateTime?;
                    final bool caducada = _estaCaducada(fCad);

                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (caducada) return Colors.red.withValues(alpha: 0.10);
                        if (esDescatalogado) return Colors.orange.withValues(alpha: 0.1);
                        if (esCantidadBaja) return Colors.red.withValues(alpha: 0.05);
                        return null;
                      }),
                      cells: [
                        DataCell(Text(vm.codigo, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(vm.lote ?? '-', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(
                          _fmtCadCorta(fCad),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: caducada ? FontWeight.bold : FontWeight.normal,
                            color: caducada ? Colors.red : (fCad != null ? Colors.black87 : Colors.grey),
                          ),
                        )),
                        DataCell(Text(vm.cantidad.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(vm.referencia, style: const TextStyle(fontSize: 11))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: onSync,
                  style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.upload, color: Colors.white),
                  label: Text("Enviar $titulo", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ],
      ),
    );
  }
}