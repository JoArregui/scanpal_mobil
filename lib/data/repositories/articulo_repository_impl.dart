import 'package:flutter/foundation.dart';
import '../../core/exceptions.dart';
import '../../core/sync_progress.dart';
import '../../domain/entities/articulo.dart';
import '../../domain/repositories/articulo_repository.dart';
import '../datasources/articulo_local_datasource.dart';
import '../datasources/articulo_remote_datasource.dart';

class ArticuloRepositoryImpl implements ArticuloRepository {
  final ArticuloRemoteDataSource remoteDataSource;
  final ArticuloLocalDataSource localDataSource;

  ArticuloRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  // ==================== CONEXIÓN DEL STREAM DE PROGRESO ====================

  @override
  Stream<SyncProgress> get syncProgressStream =>
      localDataSource.syncProgressStream;

  // ==================== MÉTODOS DE CONSULTA COMPLETOS ====================

  @override
  Future<int> countArticulos() async {
    try {
      // Devuelve el conteo físico real de la tabla local para el Dashboard
      return await localDataSource.countArticulos();
    } catch (e) {
      debugPrint('❌ Error countArticulos en Repo: $e');
      return 0;
    }
  }

  // ==================== MÉTRICAS REMOTAS (METADATA) ====================

  @override
  Future<int> getTotalArticulosAPI() async {
    try {
      // Recupera el valor persistido en la tabla 'metadata' tras la última sincronización
      return await localDataSource.getTotalArticulosAPI();
    } catch (e) {
      debugPrint('❌ Error getTotalArticulosAPI en Repo: $e');
      return 0;
    }
  }

  @override
  Future<int> getTotalActivosAPI() async {
    try {
      // Recupera el conteo de activos reportado por el Servidor y guardado en metadata
      return await localDataSource.getTotalActivosAPI();
    } catch (e) {
      debugPrint('❌ Error getTotalActivosAPI en Repo: $e');
      return 0;
    }
  }

  @override
  Future<int> getTotalDescatalogadosAPI() async {
    try {
      // Recupera el conteo de descatalogados reportado por el Servidor y guardado en metadata
      return await localDataSource.getTotalDescatalogadosAPI();
    } catch (e) {
      debugPrint('❌ Error getTotalDescatalogadosAPI en Repo: $e');
      return 0;
    }
  }

  // ==================== GESTIÓN DE ARTÍCULOS ====================

  @override
  Future<Articulo?> getArticuloByCodigo(String codigo) async {
    try {
      final localArticulo = await localDataSource.getArticuloByCodigo(codigo);
      return localArticulo;
    } on NoLocalDataException {
      return null;
    } catch (e) {
      throw Exception('Error al buscar artículo localmente: ${e.toString()}');
    }
  }

  @override
  Future<Articulo?> getArticuloDuplicadoByCodigo(String codigo) async {
    try {
      return await localDataSource.getArticuloDuplicadoByCodigo(codigo);
    } catch (e) {
      debugPrint('⚠️ Error buscando en duplicados: $e');
      return null;
    }
  }

  @override
  Future<List<Articulo>> getArticulosPaginados({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await localDataSource.getAllArticulos(
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('❌ Error getArticulosPaginados: $e');
      return [];
    }
  }

  @override
  Future<List<Articulo>> buscarArticulosPorTexto(String query) async {
    try {
      // Implementación real que delega al motor de búsqueda de SQLite
      return await localDataSource.buscarArticulos(query);
    } catch (e) {
      debugPrint('❌ Error buscarArticulosPorTexto: $e');
      return [];
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  @override
  Future<void> sincronizarArticulos() async {
    try {
      debugPrint('🚀 Iniciando sincronización desde Repository...');
      // 1. Descarga desde la API remota
      final List<Articulo> listaDesdeServidor = await remoteDataSource
          .getArticulos();

      // 2. Persistencia en LocalDataSource.
      // El Isolate interno procesa la lista, detecta cambios y emite el progreso por el Stream.
      await localDataSource.saveArticulos(listaDesdeServidor);
      debugPrint('✅ Sincronización completada con éxito.');
    } catch (e) {
      debugPrint('❌ Error crítico en sincronizarArticulos: $e');
      throw Exception('Error durante la sincronización: $e');
    }
  }

  // ==================== MÉTODOS DE ACTUALIZACIÓN ====================

  @override
  Future<void> actualizarArticuloLocal(
    String codigo,
    String? nuevaDescripcion,
    int? nuevaCantidadMinima,
  ) async {
    if (nuevaDescripcion == null || nuevaCantidadMinima == null) {
      throw Exception('Datos incompletos para actualización local.');
    }

    try {
      final existing = await localDataSource.getArticuloByCodigo(codigo);

      final updated = Articulo(
        codigo: codigo,
        descripcion: nuevaDescripcion,
        referencia: existing.referencia,
        lote: existing.lote,
        cantidadMinima: nuevaCantidadMinima,
        descatalogado: existing.descatalogado,
        gestionLotes: existing.gestionLotes,
      );

      await localDataSource.saveArticulo(updated);
    } catch (e) {
      throw Exception('Error al actualizar local: $e');
    }
  }

  @override
  Future<void> actualizarArticuloRemoto(
    String codigo,
    String? nuevaDescripcion,
    int? nuevaCantidadMinima,
  ) async {
    if (nuevaDescripcion == null || nuevaCantidadMinima == null) {
      throw Exception('Datos incompletos para actualización remota.');
    }

    try {
      // 1. Obtenemos el artículo actual para no perder campos inmutables
      final existing = await localDataSource.getArticuloByCodigo(codigo);

      // 2. Petición POST al servidor con todos los campos requeridos
      await remoteDataSource.updateArticulo(
        codigo,
        nuevaDescripcion,
        nuevaCantidadMinima,
        existing.referencia,
        existing.lote,
        existing.descatalogado,
        existing.gestionLotes,
      );

      // 3. Si el servidor responde OK, actualizamos localmente
      final updated = Articulo(
        codigo: codigo,
        descripcion: nuevaDescripcion,
        referencia: existing.referencia,
        lote: existing.lote,
        cantidadMinima: nuevaCantidadMinima,
        descatalogado: existing.descatalogado,
        gestionLotes: existing.gestionLotes,
      );

      await localDataSource.saveArticulo(updated);
      debugPrint('✅ Artículo $codigo actualizado en remoto y local.');
    } on ServerException catch (e) {
      throw Exception('Error al sincronizar con el servidor: ${e.message}');
    } catch (e) {
      throw Exception('Error crítico en actualización remota: $e');
    }
  }
}
