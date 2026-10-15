import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/database_helper.dart';
import '../../data/datasources/auth_local_datasource.dart';
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

enum LectorState {
  initial,
  loadingArticulo,
  loadedArticulo,
  descatalogadoArticulo,
  duplicadoArticulo,
  registering,
  error,
  loadingLecturas,
  sendingLecturas,
  sendSuccess,
  sendError,
  noEncontradoFuzzy,
}

class LectorProvider with ChangeNotifier {
  // Use Cases
  final BuscarArticuloUseCase buscarArticuloUseCase;
  final RegistrarLecturaUseCase registrarLecturaUseCase;
  final EnviarLecturasUseCase enviarLecturasUseCase;
  final ObtenerLecturasUseCase obtenerLecturasUseCase;
  final ActualizarLecturaUseCase actualizarLecturaUseCase;
  final GetConfiguracionUseCase getConfiguracionUseCase;
  final ObtenerLecturasPorFechaUseCase obtenerLecturasPorFechaUseCase;

  // Data Sources
  final AuthLocalDataSource authLocalDataSource;

  // Propiedades Privadas
  final AudioPlayer _audioPlayer = AudioPlayer();
  Configuracion _configuracionActual = Configuracion.inicial();
  LectorState _state = LectorState.initial;
  Articulo? _articuloEncontrado;
  String _errorMessage = '';
  final List<LecturaViewModel> _registrosViewModel = [];
  List<Lectura> _historialLecturas = [];
  int _lecturasEnviadasCount = 0;
  int _currentUserId = 1;

  List<Articulo> _sugerenciasFuzzy = [];

  // Definimos el tipo de operación (Inventario por defecto en este Provider)
  final TipoOperacion _tipo = TipoOperacion.inventario;

  LectorProvider({
    required this.buscarArticuloUseCase,
    required this.registrarLecturaUseCase,
    required this.enviarLecturasUseCase,
    required this.obtenerLecturasUseCase,
    required this.actualizarLecturaUseCase,
    required this.getConfiguracionUseCase,
    required this.obtenerLecturasPorFechaUseCase,
    required this.authLocalDataSource,
  }) {
    if (kDebugMode) {
      print(
        '🏗️ [LIFECYCLE] Inicializando LectorProvider PRO (Modo: ${_tipo.name})',
      );
    }
    _initialize();
  }

  Future<void> _initialize() async {
    await _cargarUsuarioLogueado();
    await _loadConfiguracionInicial();
    await obtenerLecturasPendientes();
    await limpiarHistorialAntiguo(dias: 90); // Purga automática de seguridad
  }

  // --- Getters ---
  LectorState get state => _state;
  Articulo? get articuloEncontrado => _articuloEncontrado;
  String get errorMessage => _errorMessage;
  List<LecturaViewModel> get registrosViewModel => _registrosViewModel;
  List<Lectura> get historialLecturas => _historialLecturas;
  int get lecturasEnviadasCount => _lecturasEnviadasCount;
  int get currentUserId => _currentUserId;
  int get cantidadMinimaGlobal => _configuracionActual.cantidadMinima;
  List<Articulo> get sugerenciasFuzzy => _sugerenciasFuzzy;

  int get totalLecturasCantidadBaja => _registrosViewModel
      .where((vm) => vm.cantidad < cantidadMinimaGlobal)
      .length;

  // --- Lógica de Usuario y Configuración ---

  Future<void> _cargarUsuarioLogueado() async {
    try {
      final int? userCode = await authLocalDataSource.getUserCode();
      _currentUserId = (userCode != null && userCode != 0) ? userCode : 1;
      if (kDebugMode) print('👤 [AUTH] Usuario asignado: $_currentUserId');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ [AUTH] Error: $e');
    }
  }

  Future<void> refrescarUsuarioDinamico() async =>
      await _cargarUsuarioLogueado();

  Future<void> _loadConfiguracionInicial() async {
    try {
      _configuracionActual = await getConfiguracionUseCase.execute();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [CONFIG] Error: $e');
    }
  }

  // --- Utilidades ---

  String _limpiarTexto(String texto) {
    if (texto.isEmpty) return texto;
    return texto.replaceAll(RegExp(r'\u00a0'), ' ').trim();
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

  /// FIFO: aviso sonoro de caducidad (una reproducción). Se llama desde
  /// LectorPage al detectar fecha caducada en el código escaneado.
  Future<void> reproducirAvisoCaducidad() async {
    await _playSound(AppConstants.soundAvisoCaducidad);
  }

  // --- Gestión de Lecturas Pendientes ---

  Future<void> obtenerLecturasPendientes() async {
    _state = LectorState.loadingLecturas;
    _errorMessage = '';
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
      _state = LectorState.initial;
    } catch (e) {
      _errorMessage = 'Error al obtener lecturas locales.';
      _state = LectorState.error;
    }
    notifyListeners();
  }

  // --- Gestión del Historial ---

  Future<void> obtenerHistorialPorFecha(DateTime fecha) async {
    _state = LectorState.loadingLecturas;
    _historialLecturas = [];
    _errorMessage = '';
    notifyListeners();

    try {
      final registros = await obtenerLecturasPorFechaUseCase.execute(fecha);

      // Filtrar por tipo y que estén sincronizados (fechaEnvio no nula)
      _historialLecturas = registros
          .where((l) => l.tipoOperacion == _tipo && l.fechaEnvio != null)
          .toList();

      _historialLecturas.sort((a, b) => b.fechaEnvio!.compareTo(a.fechaEnvio!));
      _state = LectorState.initial;
    } catch (e) {
      _errorMessage = 'Error al cargar historial.';
      _state = LectorState.error;
    }
    notifyListeners();
  }

  // --- Búsqueda de Artículos (Con Fallbacks) ---

  Future<void> buscarArticulo(String codigo) async {
    _state = LectorState.loadingArticulo;
    _articuloEncontrado = null;
    _errorMessage = '';
    notifyListeners();

    final String cod = _limpiarTexto(codigo);

    try {
      Articulo? art = await buscarArticuloUseCase.execute(cod);

      // Fallback 1: EAN-13 incompleto
      if (art == null && cod.length == 12) {
        art = await buscarArticuloUseCase.execute('0$cod');
      }

      // Fallback 2: Relleno de ceros (GTIN-13/14)
      if (art == null && cod.length < 13) {
        art = await buscarArticuloUseCase.execute(cod.padLeft(13, '0'));
        art ??= await buscarArticuloUseCase.execute(cod.padLeft(14, '0'));
      }

      // Fallback 3: Artículos de peso variable (Prefijo 7 dígitos)
      if (art == null && cod.startsWith('2') && cod.length == 13) {
        art = await buscarArticuloUseCase.execute(cod.substring(0, 7));
      }

      if (art != null) {
        _procesarArticuloEncontrado(art);
      } else {
        // [NUEVO] Fallback 4: Búsqueda fuzzy por dígitos numéricos
        if (kDebugMode) {
          print('🔍 [FUZZY] Iniciando búsqueda fuzzy para: "$cod"');
        }
        final sugerencias = await buscarArticuloUseCase.executeFuzzy(cod);

        if (sugerencias.isNotEmpty) {
          // Hay sugerencias: notificar a la UI para mostrar el selector
          _sugerenciasFuzzy = sugerencias;
          _errorMessage =
              '⚠️ Código no reconocido. Selecciona el artículo correcto.';
          _state = LectorState.noEncontradoFuzzy;
          if (kDebugMode) {
            print('🔍 [FUZZY] ${sugerencias.length} sugerencias encontradas');
          }
          notifyListeners();
        } else {
          await _setArticuloNoEncontrado();
        }
      }
    } catch (e) {
      await _setArticuloNoEncontrado();
    }
  }

  void seleccionarArticuloDeSugerencia(Articulo articulo) {
    _sugerenciasFuzzy = [];
    _procesarArticuloEncontrado(articulo);
  }

  void _procesarArticuloEncontrado(Articulo art) async {
    _articuloEncontrado = art.copyWith(
      descripcion: _limpiarTexto(art.descripcion),
    );

    if (_articuloEncontrado!.descatalogado) {
      _errorMessage = '⚠️ ARTÍCULO DESCATALOGADO';
      _state = LectorState.descatalogadoArticulo;
      await _playTripleWarning();
    } else {
      _state = LectorState.loadedArticulo;
    }
    notifyListeners();
  }

  Future<void> _setArticuloNoEncontrado() async {
    _errorMessage = '❌ CÓDIGO DE BARRAS NO ENCONTRADO';
    _state = LectorState.error;
    await _playSound(AppConstants.soundErrorNoEncontrado);
    notifyListeners();
  }

  // --- Registro y Sincronización ---

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
    _state = LectorState.registering;
    notifyListeners();

    final double cantAFijar = (cantidad == null || cantidad <= 0)
        ? (_configuracionActual.cantidadMinima > 0
            ? _configuracionActual.cantidadMinima.toDouble()
            : 0.0)
        : cantidad;

    if (cantAFijar <= 0) {
      _errorMessage = 'Debe introducir una cantidad válida.';
      _state = LectorState.error;
      notifyListeners();
      return false;
    }

    try {
      await registrarLecturaUseCase.execute(
        codigo: _limpiarTexto(codigo),
        referencia: _limpiarTexto(referenciaArticulo),
        cantidad: cantAFijar,
        idUsuario: _currentUserId,
        lote: (lote != null && lote.trim().isNotEmpty)
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
      _state = LectorState.initial;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar lectura.';
      _state = LectorState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> enviarLecturasAlServidor() async {
    if (_registrosViewModel.isEmpty) return;

    _state = LectorState.sendingLecturas;
    _errorMessage = '';
    notifyListeners();

    try {
      final totalEnviadas = await enviarLecturasUseCase.execute(_tipo);
      _lecturasEnviadasCount = totalEnviadas;

      await obtenerLecturasPendientes();
      _state = LectorState.sendSuccess;
    } catch (e) {
      _errorMessage = 'Error de envío: ${_limpiarTexto(e.toString())}';
      _state = LectorState.sendError;
    } finally {
      notifyListeners();
    }
  }

  // --- Acciones de Edición y Borrado ---

  Future<bool> borrarTodasLasLecturas() async {
    _state = LectorState.registering;
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
      _errorMessage = 'Error al vaciar la lista.';
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
      _errorMessage = 'Error al editar.';
      notifyListeners();
      return false;
    }
  }

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

  void resetSendState() {
    _state = LectorState.initial;
    _errorMessage = '';
    _lecturasEnviadasCount = 0;
    _articuloEncontrado = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (kDebugMode) print('💀 [LIFECYCLE] Dispose LectorProvider.');
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Mantenimiento de BD ---

  Future<int> limpiarHistorialAntiguo({int dias = 90}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final fechaCorte = DateTime.now().subtract(Duration(days: dias));
      final fechaStr = DateFormat('yyyy-MM-dd').format(fechaCorte);

      final filasBorradas = await db.delete(
        DatabaseHelper.tableNameLecturas,
        where:
            '${DatabaseHelper.colSincronizado} = ? AND ${DatabaseHelper.colFechaEnvio} < ? AND ${DatabaseHelper.colTipoOperacion} = ?',
        whereArgs: [1, '$fechaStr%', _tipo.name],
      );

      if (kDebugMode && filasBorradas > 0) {
        print(
          '🧹 [MANTENIMIENTO] Se han purgado $filasBorradas registros antiguos de ${_tipo.name}.',
        );
      }
      return filasBorradas;
    } catch (e) {
      return 0;
    }
  }

  // --- Implementación para la leyenda del calendario ---

  Future<List<DateTime>> obtenerDiasConLecturas() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // Consultamos solo las fechas únicas que tienen registros sincronizados para este tipo de operación
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT substr(${DatabaseHelper.colFechaEnvio}, 1, 10) as fecha 
        FROM ${DatabaseHelper.tableNameLecturas} 
        WHERE ${DatabaseHelper.colSincronizado} = 1 
        AND ${DatabaseHelper.colTipoOperacion} = ?
        AND ${DatabaseHelper.colFechaEnvio} IS NOT NULL
      ''', [_tipo.name]);

      return List.generate(maps.length, (i) {
        return DateTime.parse(maps[i]['fecha']);
      });
    } catch (e) {
      if (kDebugMode) print('❌ [DB] Error obteniendo días con lecturas: $e');
      return [];
    }
  }
}