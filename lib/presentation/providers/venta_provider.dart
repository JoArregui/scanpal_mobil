import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/database_helper.dart';
import '../widgets/lectura_view_model.dart';
import '../../domain/entities/articulo.dart';
import '../../domain/entities/lectura.dart';
import '../../domain/entities/configuracion.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../domain/usecases/buscar_articulo_usecase.dart';
import '../../domain/usecases/registrar_lectura_usecase.dart';
import '../../domain/usecases/enviar_lecturas_usecase.dart';
import '../../domain/usecases/obtener_lecturas_usecase.dart';
import '../../domain/usecases/actualizar_lectura_usecase.dart';
import '../../domain/usecases/get_configuracion_usecase.dart';
import '../../domain/usecases/obtener_lecturas_por_fecha_usecase.dart';

enum VentaState {
  initial,
  loadingArticulo,
  loadedArticulo,
  descatalogadoArticulo,
  registering,
  error,
  loadingLecturas,
  sendingLecturas,
  sendSuccess,
  sendError,
}

class VentaProvider with ChangeNotifier {
  final BuscarArticuloUseCase buscarArticuloUseCase;
  final RegistrarLecturaUseCase registrarLecturaUseCase;
  final EnviarLecturasUseCase enviarLecturasUseCase;
  final ObtenerLecturasUseCase obtenerLecturasUseCase;
  final ActualizarLecturaUseCase actualizarLecturaUseCase;
  final GetConfiguracionUseCase getConfiguracionUseCase;
  final ObtenerLecturasPorFechaUseCase obtenerLecturasPorFechaUseCase;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Configuracion _configuracionActual = Configuracion.inicial();

  VentaState _state = VentaState.initial;
  Articulo? _articuloEncontrado;
  String _errorMessage = '';
  final List<LecturaViewModel> _registrosViewModel = [];
  List<Lectura> _historialLecturas = [];
  int _lecturasEnviadasCount = 0;
  final int _currentUserId = 1;

  final TipoOperacion _tipo = TipoOperacion.venta;

  VentaProvider({
    required this.buscarArticuloUseCase,
    required this.registrarLecturaUseCase,
    required this.enviarLecturasUseCase,
    required this.obtenerLecturasUseCase,
    required this.actualizarLecturaUseCase,
    required this.getConfiguracionUseCase,
    required this.obtenerLecturasPorFechaUseCase,
  }) {
    if (kDebugMode) {
      print('🏗️ [LIFECYCLE] Constructor VentaProvider inicializado.');
    }
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadConfiguracionInicial();
    await obtenerLecturasPendientes();
    await limpiarHistorialAntiguo();
  }

  // --- Getters ---
  VentaState get state => _state;
  Articulo? get articuloEncontrado => _articuloEncontrado;
  String get errorMessage => _errorMessage;
  List<LecturaViewModel> get registrosViewModel => _registrosViewModel;
  List<Lectura> get historialLecturas => _historialLecturas;
  int get lecturasEnviadasCount => _lecturasEnviadasCount;
  int get cantidadMinimaGlobal => _configuracionActual.cantidadMinima;

  String _limpiarTexto(String texto) {
    if (texto.isEmpty) return texto;
    return texto.replaceAll(RegExp(r'\u00a0'), ' ').trim();
  }

  Future<void> _loadConfiguracionInicial() async {
    try {
      _configuracionActual = await getConfiguracionUseCase.execute();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [CONFIG] Error en Ventas: $e');
    }
  }

  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(_limpiarTexto(assetPath)));
    } catch (e) {
      if (kDebugMode) print('❌ [AUDIO] Error: $e');
    }
  }

  Future<void> _playTripleWarning() async {
    for (int i = 0; i < 3; i++) {
      await _playSound(AppConstants.soundWarningDescatalogado);
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  void resetState() {
    _state = VentaState.initial;
    _articuloEncontrado = null;
    _errorMessage = '';
    notifyListeners();
  }

  // --- Lógica de Lecturas Pendientes ---

  Future<void> obtenerLecturasPendientes() async {
    _state = VentaState.loadingLecturas;
    notifyListeners();

    try {
      final lecturas = await obtenerLecturasUseCase.execute(_tipo);
      _registrosViewModel.clear();

      for (var lectura in lecturas) {
        String descLimpia = _limpiarTexto(lectura.descripcion ?? '');
        if (descLimpia.isEmpty || descLimpia == lectura.codigoArticulo) {
          descLimpia = _limpiarTexto(lectura.referenciaArticulo);
        }

        final infoLote = (lectura.lote != null && lectura.lote!.isNotEmpty)
            ? ' [L: ${_limpiarTexto(lectura.lote!)}]'
            : '';

        _registrosViewModel.add(
          LecturaViewModel(
            lectura: lectura,
            descripcionArticulo: '$descLimpia$infoLote',
          ),
        );
      }
      _state = VentaState.initial;
    } catch (e) {
      _errorMessage = 'Error al obtener ventas locales.';
      _state = VentaState.error;
    }
    notifyListeners();
  }

  // --- Lógica del Historial ---

  Future<void> obtenerHistorialPorFecha(DateTime fecha) async {
    _state = VentaState.loadingLecturas;
    _historialLecturas = [];
    _errorMessage = '';
    notifyListeners();

    try {
      final registros = await obtenerLecturasPorFechaUseCase.execute(fecha);
      _historialLecturas = registros
          .where((l) => l.tipoOperacion == _tipo && l.fechaEnvio != null)
          .toList();

      _historialLecturas.sort((a, b) {
        if (a.fechaEnvio == null || b.fechaEnvio == null) return 0;
        return b.fechaEnvio!.compareTo(a.fechaEnvio!);
      });

      _state = VentaState.initial;
    } catch (e) {
      _errorMessage = 'Error al cargar historial de ventas.';
      _state = VentaState.error;
    }
    notifyListeners();
  }

  // --- Acciones de Artículos ---

  Future<void> buscarArticulo(String codigo) async {
    _state = VentaState.loadingArticulo;
    _articuloEncontrado = null;
    _errorMessage = '';
    notifyListeners();

    final String cod = _limpiarTexto(codigo);

    try {
      Articulo? art = await buscarArticuloUseCase.execute(cod);

      if (art == null && cod.length == 12) {
        art = await buscarArticuloUseCase.execute('0$cod');
      }
      if (art == null && cod.length < 13) {
        art = await buscarArticuloUseCase.execute(cod.padLeft(13, '0'));
        art ??= await buscarArticuloUseCase.execute(cod.padLeft(14, '0'));
      }

      if (art != null) {
        _articuloEncontrado = art.copyWith(
          descripcion: _limpiarTexto(art.descripcion),
        );

        if (art.descatalogado) {
          _errorMessage = '⚠️ ARTÍCULO DESCATALOGADO';
          _state = VentaState.descatalogadoArticulo;
          await _playTripleWarning();
        } else {
          _state = VentaState.loadedArticulo;
        }
      } else {
        _errorMessage = '❌ ARTÍCULO NO ENCONTRADO';
        _state = VentaState.error;
        await _playSound(AppConstants.soundErrorNoEncontrado);
      }
    } catch (e) {
      _state = VentaState.error;
      _errorMessage = 'Error en la búsqueda.';
    }
    notifyListeners();
  }

  // --- Registro de Lecturas ---

  Future<bool> registrarLectura(
    String codigo,
    double? cantidad,
    String descripcion, {
    required String referenciaArticulo,
    String? lote,
    bool? esDescatalogado,
    DateTime? fechaCaducidad,
    double? pesoNeto,
    double? pesoBruto,
    String? sscc,
  }) async {
    _state = VentaState.registering;
    notifyListeners();

    final double cantAFijar = (cantidad == null || cantidad <= 0)
        ? (_configuracionActual.cantidadMinima > 0
              ? _configuracionActual.cantidadMinima.toDouble()
              : 0.0)
        : cantidad;

    try {
      await registrarLecturaUseCase.execute(
        codigo: _limpiarTexto(codigo),
        referencia: referenciaArticulo.trim(),
        cantidad: cantAFijar,
        idUsuario: _currentUserId,
        lote: lote != null && lote.trim().isNotEmpty
            ? _limpiarTexto(lote)
            : null,
        esDescatalogado:
            esDescatalogado ?? (_articuloEncontrado?.descatalogado ?? false),
        descripcion: _limpiarTexto(descripcion),
        tipoOperacion: _tipo,
        fechaCaducidad: fechaCaducidad,
        pesoNeto: pesoNeto,
        pesoBruto: pesoBruto,
        sscc: sscc,
      );

      await obtenerLecturasPendientes();
      _state = VentaState.initial;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _state = VentaState.error;
      notifyListeners();
      return false;
    }
  }

  // --- Envío de Datos ---

  Future<void> enviarVentasAlServidor() async {
    if (_registrosViewModel.isEmpty) return;

    _state = VentaState.sendingLecturas;
    _errorMessage = '';
    notifyListeners();

    try {
      final totalEnviadas = await enviarLecturasUseCase.execute(_tipo);
      _lecturasEnviadasCount = totalEnviadas;

      await obtenerLecturasPendientes();
      _state = VentaState.sendSuccess;
    } catch (e) {
      _errorMessage = _limpiarTexto(e.toString());
      _state = VentaState.sendError;
      if (kDebugMode) print('❌ [VENTA] Error envío: $e');
    } finally {
      notifyListeners();
    }
  }

  // --- Gestión de Borrado y Edición ---

  Future<bool> borrarLectura(Lectura lectura) async {
    if (lectura.id == null) return false;
    try {
      await actualizarLecturaUseCase.delete(lectura.id!);
      await obtenerLecturasPendientes();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> borrarTodasLasLecturas() async {
    _state = VentaState.registering;
    notifyListeners();
    try {
      for (var vm in _registrosViewModel) {
        if (vm.lectura.id != null) {
          await actualizarLecturaUseCase.delete(vm.lectura.id!);
        }
      }
      await obtenerLecturasPendientes();
      return true;
    } catch (e) {
      _errorMessage = 'Error al vaciar la lista de ventas.';
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> editarLectura({
    required LecturaViewModel lecturaViewModel,
    required double nuevaCantidad,
  }) async {
    try {
      await actualizarLecturaUseCase.execute(
        lectura: lecturaViewModel.lectura,
        nuevaCantidad: nuevaCantidad,
      );
      await obtenerLecturasPendientes();
      return true;
    } catch (e) {
      _errorMessage = 'Error al editar venta.';
      notifyListeners();
      return false;
    }
  }

  void resetSendState() {
    _state = VentaState.initial;
    _errorMessage = '';
    _lecturasEnviadasCount = 0;
    _articuloEncontrado = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Purga de Historial (AUTOMÁTICA 90 DÍAS) ---

  Future<int> limpiarHistorialAntiguo() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      final fechaCorte = DateTime.now().subtract(const Duration(days: 90));
      final fechaStr = DateFormat('yyyy-MM-dd').format(fechaCorte);

      final filasBorradas = await db.delete(
        DatabaseHelper.tableNameLecturas,
        where:
            '${DatabaseHelper.colSincronizado} = ? AND ${DatabaseHelper.colFechaEnvio} < ? AND ${DatabaseHelper.colTipoOperacion} = ?',
        whereArgs: [1, '$fechaStr%', _tipo.name],
      );

      if (kDebugMode && filasBorradas > 0) {
        print(
          '🧹 [PURGA VENTA] Se han eliminado $filasBorradas registros antiguos del historial local.',
        );
      }

      return filasBorradas;
    } catch (e) {
      if (kDebugMode) print('❌ [PURGA VENTA] Error en limpieza automática: $e');
      return 0;
    }
  }
}
