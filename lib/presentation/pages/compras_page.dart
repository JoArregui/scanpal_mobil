import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/barcode_parser.dart';
import '../providers/compra_provider.dart';
import '../providers/configuracion_provider.dart';

import '../widgets/camera_view_section.dart';
import '../widgets/lector_info_bar.dart';
import '../widgets/lecturas_data_table.dart';
import '../widgets/dialogos_lector.dart';
import '../widgets/dialogo_registro_articulo.dart';

class ComprasPage extends StatefulWidget {
  const ComprasPage({super.key});

  @override
  State<ComprasPage> createState() => _ComprasPageState();
}

class _ComprasPageState extends State<ComprasPage> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.all],
    autoStart: false,
    facing: CameraFacing.back,
  );

  final TextEditingController _manualCodeController = TextEditingController();

  String _ultimoCodigoEscaneado = '';
  bool _isProcessing = false;
  bool _cameraActive = false;
  bool _torchOn = false;
  double _zoomLevel = 0.0; // Añadido para compatibilidad con CameraViewSection

  String _codigoEnEspera = '';
  int _conteoEstabilidad = 0;
  final int _umbralesEstabilidad = 5;

  // ======== DEBOUNCE / ANTIREBOTE ========
  bool _canRead = true;
  Timer? _bloqueoTimer;
  final Duration _tiempoBloqueo = const Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _inicializarLector();
  }

  Future<void> _inicializarLector() async {
    if (!mounted) return;

    // Cargar lecturas locales de compras
    context.read<CompraProvider>().obtenerLecturasPendientes();

    await context.read<ConfiguracionProvider>().cargarConfiguracion();
    if (!mounted) return;

    final config = context.read<ConfiguracionProvider>().configuracion;

    if (config.lecturaAutomatica) {
      _toggleCamera();
    }
  }

  @override
  void dispose() {
    _bloqueoTimer?.cancel();
    cameraController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  // =================== CÁMARA ===================

  void _toggleCamera() {
    setState(() {
      _cameraActive = !_cameraActive;
      _codigoEnEspera = '';
      _conteoEstabilidad = 0;

      if (_cameraActive) {
        _canRead = true;
        cameraController.start();
      } else {
        _torchOn = false;
        _bloqueoTimer?.cancel();
        cameraController.stop();
      }
    });
  }

  void _toggleTorch() async {
    if (!_cameraActive) return;
    await cameraController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_cameraActive || _isProcessing || !_canRead) return;

    final raw = capture.barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    final codigo = raw.trim();

    setState(() {
      if (codigo == _codigoEnEspera) {
        _conteoEstabilidad++;
      } else {
        _codigoEnEspera = codigo;
        _conteoEstabilidad = 1;
      }
    });

    final config = context.read<ConfiguracionProvider>().configuracion;
    if (config.lecturaAutomatica &&
        _conteoEstabilidad >= _umbralesEstabilidad) {
      _procesarEntradaCodigo(codigo);
    }
  }

  void _dispararEscaneo() {
    if (!_cameraActive || _isProcessing) return;

    if (_codigoEnEspera.isNotEmpty) {
      _procesarEntradaCodigo(_codigoEnEspera);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ningún código detectado en el visor'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _iniciarBloqueoTemporal() {
    setState(() => _canRead = false);
    _bloqueoTimer?.cancel();
    _bloqueoTimer = Timer(_tiempoBloqueo, () {
      if (mounted) {
        setState(() => _canRead = true);
      }
    });
  }

  // =================== PROCESAMIENTO ===================

  Future<void> _procesarEntradaCodigo(String rawCodigo) async {
    if (_isProcessing || rawCodigo.isEmpty) return;

    final barcode = BarcodeParser.parse(rawCodigo);

    setState(() {
      _isProcessing = true;
      _cameraActive = false;
      _torchOn = false;
      _ultimoCodigoEscaneado = rawCodigo;
    });

    await cameraController.stop();
    if (!mounted) return;

    final provider = context.read<CompraProvider>();
    final config = context.read<ConfiguracionProvider>().configuracion;

    provider.resetState();

    await provider.buscarArticulo(barcode.codigoArticulo);
    if (!mounted) return;

    if (provider.state == CompraState.loadedArticulo ||
        provider.state == CompraState.descatalogadoArticulo) {
      final articulo = provider.articuloEncontrado!;
      final descripcionLimpia = _limpiarDescripcion(
        articulo.descripcion,
        articulo.codigo,
      );

      final double cantidadFinal =
          barcode.cantidad ?? config.cantidadMinima.toDouble();

      bool tieneLoteSiLoRequiere =
          !articulo.gestionLotes ||
          (articulo.gestionLotes && barcode.lote != null);

      if (config.lecturaAutomatica &&
          !articulo.descatalogado &&
          tieneLoteSiLoRequiere &&
          cantidadFinal > 0) {
        await provider.registrarLectura(
          articulo.codigo,
          cantidadFinal,
          descripcionLimpia,
          referenciaArticulo: articulo.referencia,
          lote: barcode.lote,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Registro de Compra: ${barcode.lote ?? "Sin lote"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 700),
          ),
        );

        _iniciarBloqueoTemporal();

        setState(() {
          _isProcessing = false;
          _cameraActive = true;
          _codigoEnEspera = '';
          _conteoEstabilidad = 0;
        });
        cameraController.start();
      } else {
        final resultado = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => DialogoRegistroArticulo(
            codigo: articulo.codigo,
            articulo: articulo,
            cantidadConfigurada: cantidadFinal.toInt(),
            descripcionLimpia: descripcionLimpia,
            provider: provider,
            loteExtraido: barcode.lote,
            fechaExtraida: barcode.fechaCaducidad,
          ),
        );

        if (mounted) {
          if (resultado == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Registro completado'),
                backgroundColor: Colors.green,
                duration: Duration(milliseconds: 700),
              ),
            );
            _iniciarBloqueoTemporal();
          }

          setState(() {
            _isProcessing = false;
            _codigoEnEspera = '';
            _conteoEstabilidad = 0;
          });

          if (config.lecturaAutomatica) {
            setState(() => _cameraActive = true);
            cameraController.start();
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isProcessing = false;
          _codigoEnEspera = '';
          _conteoEstabilidad = 0;
        });
        if (config.lecturaAutomatica) {
          setState(() => _cameraActive = true);
          cameraController.start();
        }
      }
    }
  }

  String _limpiarDescripcion(String desc, String cod) {
    desc = desc.trim();
    if (desc.isEmpty) return 'Sin descripción';
    if (desc == cod) return 'Art. $cod';
    return desc.replaceAll(cod, '').trim();
  }

  void _mostrarDialogoManual() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrada Manual Compra'),
        content: TextField(
          controller: _manualCodeController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'EAN o código GS1-128',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualCodeController.text;
              Navigator.pop(ctx);
              _manualCodeController.clear();
              _procesarEntradaCodigo(code);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompraProvider>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada de Mercancía'),
        backgroundColor: Colors.green.shade800,
        centerTitle: true,
        actions: [
          if (_cameraActive)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: _torchOn ? Colors.amber : null,
              ),
              onPressed: _toggleTorch,
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              DialogosLector.confirmarBorrarTodo(
                context: context,
                onConfirm: () => context.read<CompraProvider>().borrarTodasLasLecturas(),
              );
            },
            tooltip: 'Borrar todas las compras locales',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'btn_scan_compra',
        onPressed: () {
          if (!_cameraActive) {
            _toggleCamera();
          } else {
            _dispararEscaneo();
          }
        },
        backgroundColor: _cameraActive
            ? Colors.green.shade600
            : Colors.blue.shade700,
        child: Icon(
          _cameraActive ? Icons.camera_alt : Icons.qr_code_scanner,
          color: Colors.white,
          size: 40,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          
          Widget tablaLecturas = LecturasDataTable(
            provider: provider,
            onRowDoubleTap: (ctx, prov, vm) {
              DialogosLector.mostrarDialogoEdicion(
                context: ctx,
                viewModel: vm,
                onDelete: (itemVM) => prov.borrarLectura(itemVM.lectura),
                onEdit: (itemVM, nuevaCant) => prov.editarLectura(
                  lecturaViewModel: itemVM,
                  nuevaCantidad: nuevaCant,
                ),
              );
            },
          );

          // Widget de cámara extraído para manejar los parámetros requeridos por CameraViewSection
          Widget seccionCamara = CameraViewSection(
            cameraController: cameraController,
            cameraActive: _cameraActive,
            isProcessing: _isProcessing,
            canRead: _canRead,
            onDetect: _onBarcodeDetected,
            onToggleCamera: _toggleCamera,
            onDisparo: _dispararEscaneo,
            zoomLevel: _zoomLevel,
            onZoomChanged: (val) {
              setState(() => _zoomLevel = val);
              cameraController.setZoomScale(val); // Método corregido para mobile_scanner
            },
            conteoEstabilidad: _conteoEstabilidad,
            umbralEstabilidad: _umbralesEstabilidad,
          );

          if (isWideScreen) {
            return Row(
              children: [
                SizedBox(
                  width: screenWidth * 0.3,
                  child: Column(
                    children: [
                      Expanded(child: seccionCamara),
                      LectorInfoBar(
                        ultimoCodigo: _ultimoCodigoEscaneado,
                        onManualEntryTap: _mostrarDialogoManual,
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: tablaLecturas),
              ],
            );
          } else {
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.30,
                  child: seccionCamara,
                ),
                LectorInfoBar(
                  ultimoCodigo: _ultimoCodigoEscaneado,
                  onManualEntryTap: _mostrarDialogoManual,
                ),
                Expanded(child: tablaLecturas),
              ],
            );
          }
        },
      ),
    );
  }
}