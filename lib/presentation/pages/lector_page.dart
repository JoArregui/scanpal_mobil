import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/barcode_parser.dart';
import '../providers/lector_provider.dart';
import '../providers/configuracion_provider.dart';
import '../providers/actualizar_articulo_provider.dart';

import '../widgets/camera_view_section.dart';
import '../widgets/lector_info_bar.dart';
import '../widgets/lecturas_data_table.dart';
import '../widgets/dialogos_lector.dart';
import '../widgets/dialogo_registro_articulo.dart';

class LectorPage extends StatefulWidget {
  const LectorPage({super.key});

  @override
  State<LectorPage> createState() => _LectorPageState();
}

class _LectorPageState extends State<LectorPage> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: [BarcodeFormat.all],
    autoStart: false,
    facing: CameraFacing.back,
  );

  final TextEditingController _manualCodeController = TextEditingController();

  String _ultimoCodigoEscaneado = '';
  bool _isProcessing = false;
  bool _cameraActive = false;
  bool _torchOn = false;
  double _zoomLevel = 0.0;

  String _codigoEnEspera = '';
  int _conteoEstabilidad = 0;
  final int _umbralesEstabilidad = 5;

  Timer? _bloqueoTimer;
  bool _canRead = true;
  final Duration _tiempoBloqueo = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print('🚀 [INIT] LectorPage inicializado');
    _inicializarLector();
  }

  Future<void> _inicializarLector() async {
    if (kDebugMode) print('⚙️ [INIT] Inicializando lector...');

    if (!mounted) return;
    await context.read<ActualizarArticuloProvider>().inicializarDatos();

    if (!mounted) return;
    context.read<LectorProvider>().obtenerLecturasPendientes();

    await context.read<ConfiguracionProvider>().cargarConfiguracion();
    if (!mounted) return;

    final config = context.read<ConfiguracionProvider>().configuracion;

    if (kDebugMode) {
      print('⚙️ [INIT] Configuración cargada');
      print('   ├─ Lectura automática: ${config.lecturaAutomatica}');
      print('   └─ Cantidad mínima: ${config.cantidadMinima}');
    }

    if (config.lecturaAutomatica) {
      if (kDebugMode) print('⚙️ [INIT] Activando cámara por lectura automática');
      _toggleCamera();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print('🧹 [DISPOSE] Liberando recursos');
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
        if (kDebugMode) print('📸 [CAMERA] Cámara ACTIVADA');
        _canRead = true;
        cameraController.start();
      } else {
        if (kDebugMode) print('📸 [CAMERA] Cámara DETENIDA');
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
    if (kDebugMode) {
      print('💡 [TORCH] Linterna ${_torchOn ? "ENCENDIDA" : "APAGADA"}');
    }
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

    if (kDebugMode) {
      print(
        '📸 [SCAN] En visor: "$codigo" | Tipo: ${capture.barcodes.first.format.name} | Estabilidad: $_conteoEstabilidad',
      );
    }

    final config = context.read<ConfiguracionProvider>().configuracion;
    if (config.lecturaAutomatica && _conteoEstabilidad >= _umbralesEstabilidad) {
      if (kDebugMode) print('📸 [SCAN] Auto-disparo por estabilidad detectado');
      _procesarEntradaCodigo(codigo);
    }
  }

  void _dispararEscaneo() {
    if (!_cameraActive || _isProcessing) return;

    if (_codigoEnEspera.isNotEmpty) {
      if (kDebugMode) print('🎯 [SHOT] Disparo manual sobre: "$_codigoEnEspera"');
      _procesarEntradaCodigo(_codigoEnEspera);
    } else {
      if (kDebugMode) print('🎯 [SHOT] Intento de disparo sin código en visor');
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

    if (kDebugMode) {
      print(
        '🔒 [DEBOUNCE] Lectura bloqueada por ${_tiempoBloqueo.inSeconds} segundos',
      );
    }

    _bloqueoTimer?.cancel();
    _bloqueoTimer = Timer(_tiempoBloqueo, () {
      if (mounted) {
        setState(() => _canRead = true);
        if (kDebugMode) {
          print('🔓 [DEBOUNCE] Lectura desbloqueada, listo para siguiente código');
        }
      }
    });
  }

  /// Resetea el zoom a 1x tanto en el estado como en el controlador de cámara.
  void _resetZoom() {
    setState(() => _zoomLevel = 0.0);
    cameraController.setZoomScale(0.0);
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

    final provider = context.read<LectorProvider>();
    final config = context.read<ConfiguracionProvider>().configuracion;

    provider.resetSendState();

    await provider.buscarArticulo(barcode.codigoArticulo);
    if (!mounted) return;

    // ── Fallback fuzzy ─────────────────────────────────────────────────────────
    if (provider.state == LectorState.noEncontradoFuzzy) {
      final articuloSeleccionado = await DialogosLector.mostrarBuscadorFuzzy(
        context: context,
        sugerencias: provider.sugerenciasFuzzy,
        codigoEscaneado: rawCodigo,
        onBuscar: (query) => context
            .read<LectorProvider>()
            .buscarArticuloUseCase
            .executeFuzzy(query),
      );

      if (!mounted) return;

      if (articuloSeleccionado != null) {
        provider.seleccionarArticuloDeSugerencia(articuloSeleccionado);
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
      } else {
        // Usuario canceló el buscador fuzzy
        _resetZoom();
        setState(() {
          _isProcessing = false;
          _codigoEnEspera = '';
          _conteoEstabilidad = 0;
        });
        if (config.lecturaAutomatica) {
          setState(() => _cameraActive = true);
          cameraController.start();
        }
        return;
      }
    }

    // ── Artículo encontrado (normal o tras fuzzy) ──────────────────────────────
    if (provider.state == LectorState.loadedArticulo ||
        provider.state == LectorState.descatalogadoArticulo) {
      final articulo = provider.articuloEncontrado!;
      // FIFO: aviso sonoro si la fecha del código ya pasó (solo día, sin bloquear).
      // Sin await: suena en paralelo sin retrasar el registro ni crear gaps de contexto.
      if (_esCaducada(barcode.fechaCaducidad)) {
        unawaited(provider.reproducirAvisoCaducidad());
      }
      final descripcionLimpia = _limpiarDescripcion(
        articulo.descripcion,
        articulo.codigo,
      );
      final double cantidadFinal =
          barcode.cantidad ?? config.cantidadMinima.toDouble();

      final bool tieneLoteSiLoRequiere =
          !articulo.gestionLotes ||
          (articulo.gestionLotes && barcode.lote != null);

      if (config.lecturaAutomatica &&
          !articulo.descatalogado &&
          tieneLoteSiLoRequiere &&
          cantidadFinal > 0) {
        // Registro automático
        await provider.registrarLectura(
          articulo.codigo,
          cantidadFinal,
          descripcionLimpia,
          referenciaArticulo: articulo.referencia,
          lote: barcode.lote,
          fechaCaducidad: barcode.fechaCaducidad,
          pesoNeto: double.tryParse(barcode.pesoNeto ?? ''),
          pesoBruto: double.tryParse(barcode.pesoBruto ?? ''),
          sscc: barcode.scc,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Registro Automático: ${barcode.lote ?? "Sin lote"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 700),
          ),
        );

        _iniciarBloqueoTemporal();
        _resetZoom();
        setState(() {
          _isProcessing = false;
          _cameraActive = true;
          _codigoEnEspera = '';
          _conteoEstabilidad = 0;
        });
        cameraController.start();
      } else {
        // Registro manual mediante diálogo
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
            pesoNetoExtraido: double.tryParse(barcode.pesoNeto ?? ''),
            pesoBrutoExtraido: double.tryParse(barcode.pesoBruto ?? ''),
            ssccExtraido: barcode.scc,
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

          _resetZoom();
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
      // ── Error: artículo no encontrado ────────────────────────────────────────
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );

        _resetZoom();
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

  /// FIFO: true si la fecha (solo día) es anterior a hoy. Null => false.
  bool _esCaducada(DateTime? f) {
    if (f == null) return false;
    final hoy = DateTime.now();
    return DateTime(f.year, f.month, f.day)
        .isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  void _mostrarDialogoManual() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrada Manual'),
        content: TextField(
          controller: _manualCodeController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'EAN o código GS1-128 completo',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
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
    final provider = context.watch<LectorProvider>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leer Códigos'),
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
                onConfirm: () =>
                    context.read<LectorProvider>().borrarTodasLasLecturas(),
              );
            },
            tooltip: 'Borrar todas las lecturas',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                onEditFecha: (itemVM, nuevaFecha) => prov.editarLectura(
                  lecturaViewModel: itemVM,
                  nuevaFechaCaducidad: nuevaFecha,
                  quitarFechaCaducidad: nuevaFecha == null,
                ),
              );
            },
          );

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
              cameraController.setZoomScale(val);
            },
            conteoEstabilidad: _conteoEstabilidad,
            umbralEstabilidad: _umbralesEstabilidad,
          );

          if (isWideScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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