import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/articulo.dart';
import '../../domain/usecases/buscar_articulo_usecase.dart';
import '../../domain/usecases/obtener_articulos_usecase.dart';
import '../../domain/usecases/sincronizar_catalogo_usecase.dart';
import '../../domain/usecases/actualizar_articulo_usecase.dart';
import '../../domain/repositories/articulo_repository.dart';
import '../../data/datasources/articulo_local_datasource.dart';
import '../../core/sync_progress.dart';

enum ActualizarArticuloState {
  initial,
  searching,
  loaded,
  error,
  syncing,
  listLoaded,
  loadingMore,
  exporting,
  success,
}

class ActualizarArticuloProvider with ChangeNotifier {
  // UseCases y Repositorios inyectados desde main.dart
  final BuscarArticuloUseCase buscarArticuloUseCase;
  final ActualizarArticuloUseCase actualizarArticuloUseCase;
  final SincronizarCatalogoUseCase sincronizarCatalogoUseCase;
  final ObtenerArticulosUseCase obtenerArticulosUseCase;
  final ArticuloLocalDataSource localDataSource;
  final ArticuloRepository repository;

  ActualizarArticuloProvider({
    required this.buscarArticuloUseCase,
    required this.actualizarArticuloUseCase,
    required this.sincronizarCatalogoUseCase,
    required this.obtenerArticulosUseCase,
    required this.localDataSource,
    required this.repository,
  });

  // ==================== ESTADO PRIVADO ====================
  ActualizarArticuloState _state = ActualizarArticuloState.initial;
  Articulo? _articuloEncontrado;
  List<Articulo> _articulos = [];
  String _errorMessage = '';

  // Dashboard / Métricas reales del REMOTO
  int _totalArticulos = 0;
  int _totalActivos = 0;
  int _totalDescatalogados = 0;

  // Conteo físico local para control de integridad
  int _conteoFisicoReal = 0;

  // Paginación de la Lista
  int _page = 0;
  final int _pageSize = 50;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Sistema de Caché de Alto Rendimiento
  final Map<String, _CachedArticulo> _cacheArticulos = {};
  static const int _maxCacheSize = 150;
  static const Duration _cacheDuration = Duration(minutes: 30);

  // Timers y Control de Procesos
  Timer? _debounceTimer;
  static const Duration _timeoutDuration = Duration(seconds: 90);
  static const int _maxArticulosEnMemoria = 1000;

  // Flags de Control
  bool _yaInicializado = false;
  bool _sincronizacionEnCurso = false;
  DateTime? _ultimaSincronizacion;

  // ==================== SISTEMA DE PROGRESO REAL ====================
  SyncProgress? _progreso;
  StreamSubscription<SyncProgress>? _syncSub;

  // ==================== CONFIGURACIÓN DE REINTENTOS ====================
  static const int _maxIntentos = 3;

  // ==================== GETTERS ====================
  ActualizarArticuloState get state => _state;
  Articulo? get articuloEncontrado => _articuloEncontrado;
  List<Articulo> get articulos => _articulos;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;
  bool get isSyncing => _sincronizacionEnCurso;

  // Getters para el Dashboard
  int get totalArticulos => _totalArticulos;
  int get totalActivos => _totalActivos;
  int get totalDescatalogados => _totalDescatalogados;

  // Getter adicional por si la UI necesita saber si la tabla está vacía de verdad
  int get conteoFisicoReal => _conteoFisicoReal;

  SyncProgress? get progreso => _progreso;

  @override
  void dispose() {
    debugPrint('🗑️ Liberando recursos de ActualizarArticuloProvider...');
    _debounceTimer?.cancel();
    _syncSub?.cancel();
    _cacheArticulos.clear();
    _articulos.clear();
    super.dispose();
  }

  // ==================== LÓGICA DE PROGRESO ====================

  void _iniciarEscuchaProgreso() {
    _syncSub?.cancel();
    _syncSub = repository.syncProgressStream.listen(
      (nuevoProgreso) {
        _progreso = nuevoProgreso;
        _notifyListenersOptimized();
      },
      onError: (error) {
        debugPrint('❌ Error en stream de progreso: $error');
      },
    );
  }

  // ==================== UTILIDADES TÉCNICAS ====================

  String _limpiarTexto(String texto) {
    if (texto.isEmpty) return texto;
    return texto.replaceAll(RegExp(r'\u00a0'), ' ').trim();
  }

  void _gestionarMemoria() {
    if (_articulos.length > _maxArticulosEnMemoria) {
      final int cantidadAEliminar = _articulos.length - _maxArticulosEnMemoria;
      _articulos.removeRange(0, cantidadAEliminar);
      debugPrint(
        '🧹 GC Memoria: Eliminados $cantidadAEliminar artículos del buffer visual.',
      );
    }
  }

  void _notifyListenersOptimized() {
    if (!hasListeners) return;
    scheduleMicrotask(() {
      if (hasListeners) notifyListeners();
    });
  }

  Future<T> _ejecutarConReintentos<T>(
    Future<T> Function() operacion,
    String nombreOperacion,
  ) async {
    int intento = 0;
    Duration retardo = const Duration(seconds: 2);

    while (intento < _maxIntentos) {
      try {
        return await operacion().timeout(_timeoutDuration);
      } catch (e) {
        intento++;
        debugPrint('⚠️ $nombreOperacion (Intento $intento/$_maxIntentos): $e');
        if (intento >= _maxIntentos) rethrow;
        await Future.delayed(retardo);
        retardo *= 2;
      }
    }
    throw Exception(
      'Error persistente tras $_maxIntentos intentos en $nombreOperacion',
    );
  }

  // ==================== INICIALIZACIÓN Y MÉTRICAS ====================

  Future<void> inicializarDatos() async {
    if (_yaInicializado) return;

    _state = ActualizarArticuloState.searching;
    _notifyListenersOptimized();

    try {
      await _cargarMetricasDashboard();
      await _ejecutarConReintentos(
        () => cargarArticulosLocal(reset: true),
        'Carga Inicial',
      );
      _yaInicializado = true;
    } catch (e) {
      _state = ActualizarArticuloState.error;
      _errorMessage = _obtenerMensajeErrorAmigable(e);
    } finally {
      _notifyListenersOptimized();
    }
  }

  /// Ahora obtenemos los totales que reportó el Servidor y se guardaron en metadata
  Future<void> _cargarMetricasDashboard() async {
    try {
      // Estos métodos leen de la tabla 'metadata' (los datos del remoto)
      _totalArticulos = await repository.getTotalArticulosAPI();
      _totalActivos = await repository.getTotalActivosAPI();
      _totalDescatalogados = await repository.getTotalDescatalogadosAPI();

      // Conteo físico de filas para control interno de la app
      _conteoFisicoReal = await localDataSource.countArticulos();

      debugPrint(
        '📊 Dashboard: Totales Remotos Cargados (API: $_totalArticulos)',
      );
    } catch (e) {
      debugPrint('⚠️ Error métricas Dashboard: $e');
    }
  }

  // ==================== GESTIÓN DE LA LISTA (SQL LOCAL) ====================

  Future<void> cargarArticulosLocal({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
      _articulos = [];
    }

    if (_isLoadingMore) return;

    _isLoadingMore = true;
    _notifyListenersOptimized();

    try {
      final nuevos = await obtenerArticulosUseCase
          .execute(limit: _pageSize, offset: _page * _pageSize)
          .timeout(_timeoutDuration);

      if (nuevos.length < _pageSize) {
        _hasMore = false;
      }

      _articulos.addAll(nuevos);
      _gestionarMemoria();

      _state = ActualizarArticuloState.listLoaded;
    } catch (e) {
      _state = ActualizarArticuloState.error;
      debugPrint('❌ Error cargando artículos locales: $e');
    } finally {
      _isLoadingMore = false;
      _notifyListenersOptimized();
    }
  }

  Future<void> cargarMasArticulos() async {
    if (!_hasMore ||
        _isLoadingMore ||
        _state == ActualizarArticuloState.syncing) {
      return;
    }
    _page++;
    await cargarArticulosLocal();
  }

  // ==================== BÚSQUEDA AVANZADA Y GLOBAL ====================

  Future<void> buscarGlobalmenteEnBDLocal(String query) async {
    if (query.isEmpty) {
      _yaInicializado = false;
      await inicializarDatos();
      return;
    }

    _state = ActualizarArticuloState.searching;
    _errorMessage = '';
    _notifyListenersOptimized();

    try {
      final String q = query.toLowerCase().trim();
      final resultados = await repository.buscarArticulosPorTexto(q);

      _articulos = resultados
          .map(
            (art) => art.copyWith(descripcion: _limpiarTexto(art.descripcion)),
          )
          .toList();

      _hasMore = false;
      _state = ActualizarArticuloState.listLoaded;

      debugPrint(
        '🔍 Búsqueda global: Encontrados ${resultados.length} para "$q"',
      );
    } catch (e) {
      _state = ActualizarArticuloState.error;
      _errorMessage = 'Error en la búsqueda global de artículos.';
      debugPrint('❌ Error buscarGlobalmenteEnBDLocal: $e');
    } finally {
      _notifyListenersOptimized();
    }
  }

  Future<void> buscarArticulo(String codigo) async {
    if (codigo.isEmpty) return;

    // 1. Limpiamos el código por si el lector trae espacios o saltos de línea
    final String codigoLimpio = codigo.trim();

    // 2. Comprobación de caché del Provider
    final cached = _obtenerDeCache(codigoLimpio);
    if (cached != null) {
      _articuloEncontrado = cached;
      _state = ActualizarArticuloState.loaded;
      _notifyListenersOptimized();
      return;
    }

    _state = ActualizarArticuloState.searching;
    _errorMessage = '';
    _notifyListenersOptimized();

    try {
      // 3. Ejecución del UseCase
      final resultado = await buscarArticuloUseCase.execute(codigoLimpio);

      // Verificación de nulidad antes de usar copyWith
      if (resultado != null) {
        final artLimpio = resultado.copyWith(
          descripcion: _limpiarTexto(resultado.descripcion),
        );

        _articuloEncontrado = artLimpio;
        _agregarACache(codigoLimpio, artLimpio);
        _state = ActualizarArticuloState.loaded;
      } else {
        // Si el UseCase devuelve null, tratamos como no encontrado
        _articuloEncontrado = null;
        _state = ActualizarArticuloState.error;
        _errorMessage =
            'El artículo $codigoLimpio no existe en el catálogo local.';
      }
    } catch (e) {
      _articuloEncontrado = null;
      _state = ActualizarArticuloState.error;

      if (e.toString().contains('No se encontró')) {
        _errorMessage =
            'El artículo $codigoLimpio no existe en el catálogo local.';
      } else {
        _errorMessage = 'Error de lectura: Compruebe la base de datos.';
      }
      debugPrint('❌ Error en búsqueda: $e');
    } finally {
      _notifyListenersOptimized();
    }
  }

  List<Articulo> buscarEnListaActual(String query) {
    if (query.isEmpty) return _articulos;
    final String q = query.toLowerCase().trim();
    return _articulos.where((a) {
      return a.descripcion.toLowerCase().contains(q) ||
          a.codigo.toLowerCase().contains(q) ||
          a.referencia.toLowerCase().contains(q);
    }).toList();
  }

  // ==================== ACTUALIZACIÓN DE ARTÍCULO ====================

  Future<void> actualizarArticulo({
    required String codigo,
    required String nuevaDescripcion,
    required int nuevaCantidadMinima,
    bool esRemoto = true,
  }) async {
    _state = ActualizarArticuloState.syncing;
    _notifyListenersOptimized();

    try {
      if (esRemoto) {
        await actualizarArticuloUseCase.executeRemoto(
          codigo,
          nuevaDescripcion,
          nuevaCantidadMinima,
        );
      } else {
        await actualizarArticuloUseCase.executeLocal(
          codigo,
          nuevaDescripcion,
          nuevaCantidadMinima,
        );
      }

      _cacheArticulos.remove(codigo);
      _yaInicializado = false;
      await inicializarDatos();

      _state = ActualizarArticuloState.success;
    } catch (e) {
      _state = ActualizarArticuloState.error;
      _errorMessage = _obtenerMensajeErrorAmigable(e);
      debugPrint('❌ Error al actualizar: $e');
    } finally {
      _notifyListenersOptimized();
    }
  }

  // ==================== EXPORTACIÓN DE REPORTES ====================

  Future<void> compartirReportes() async {
    if (_articulos.isEmpty) return;

    _state = ActualizarArticuloState.exporting;
    _notifyListenersOptimized();

    try {
      final StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Codigo;Referencia;Descripcion;Estado');

      for (var art in _articulos) {
        final estado = art.descatalogado ? 'DESCATALOGADO' : 'ACTIVO';
        csvContent.writeln(
          '${art.codigo};${art.referencia};"${art.descripcion}";$estado',
        );
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/reporte_articulos_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      await file.writeAsString(csvContent.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Reporte de Catálogo de Artículos',
        ),
      );

      _state = ActualizarArticuloState.success;
    } catch (e) {
      _errorMessage = 'No se pudo generar el reporte.';
      _state = ActualizarArticuloState.error;
    } finally {
      _notifyListenersOptimized();
    }
  }

  // ==================== SINCRONIZACIÓN MAESTRA ====================

  Future<void> sincronizarYRecargar() async {
    if (_sincronizacionEnCurso) return;

    _sincronizacionEnCurso = true;
    _state = ActualizarArticuloState.syncing;
    _progreso = null;
    _errorMessage = '';
    _notifyListenersOptimized();

    try {
      _iniciarEscuchaProgreso();
      _cacheArticulos.clear();

      await _ejecutarConReintentos(
        () => sincronizarCatalogoUseCase.execute(),
        'Sincronización ',
      );

      await Future.delayed(const Duration(milliseconds: 300));

      _yaInicializado = false;
      await inicializarDatos();

      _ultimaSincronizacion = DateTime.now();
      _state = ActualizarArticuloState.success;
    } catch (e) {
      _state = ActualizarArticuloState.error;
      _errorMessage = 'Error crítico en sincronización: $e';
    } finally {
      _sincronizacionEnCurso = false;
      _syncSub?.cancel();
      _notifyListenersOptimized();
    }
  }

  // ==================== CACHÉ Y GESTIÓN ====================

  void _agregarACache(String codigo, Articulo articulo) {
    if (_cacheArticulos.length >= _maxCacheSize) {
      _cacheArticulos.remove(_cacheArticulos.keys.first);
    }
    _cacheArticulos[codigo] = _CachedArticulo(
      articulo: articulo,
      timestamp: DateTime.now(),
    );
  }

  Articulo? _obtenerDeCache(String codigo) {
    final cached = _cacheArticulos[codigo];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.timestamp) > _cacheDuration) {
      _cacheArticulos.remove(codigo);
      return null;
    }
    return cached.articulo;
  }

  void reset() {
    _articuloEncontrado = null;
    _errorMessage = '';
    _state = ActualizarArticuloState.listLoaded;
    _notifyListenersOptimized();
  }

  String _obtenerMensajeErrorAmigable(dynamic e) {
    final String err = e.toString().toLowerCase();
    if (err.contains('timeout')) return 'Tiempo de espera agotado.';
    if (err.contains('socket')) return 'Sin conexión de datos.';
    return 'Error al procesar el catálogo.';
  }
}

class _CachedArticulo {
  final Articulo articulo;
  final DateTime timestamp;
  _CachedArticulo({required this.articulo, required this.timestamp});
}
