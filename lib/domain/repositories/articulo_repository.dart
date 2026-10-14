import '../entities/articulo.dart';
import '../../core/sync_progress.dart';

abstract class ArticuloRepository {
  /// Stream que expone el progreso detallado de la sincronización para la UI
  Stream<SyncProgress> get syncProgressStream;

  /// Sincronización completa del catálogo: descarga de API y guarda en SQLite.
  Future<void> sincronizarArticulos();

  /// Cuenta el total de artículos en la base de datos local (SQLite).
  Future<int> countArticulos();

  // ==================== MÉTRICAS REMOTAS (METADATA) ====================

  /// Devuelve el total bruto de artículos recibidos de la API (incluyendo duplicados)
  Future<int> getTotalArticulosAPI();

  /// Devuelve el total de artículos marcados como ACTIVO en el remoto
  Future<int> getTotalActivosAPI();

  /// Devuelve el total de artículos marcados como DESCATALOGADO en el remoto
  Future<int> getTotalDescatalogadosAPI();

  // ==================== GESTIÓN DE ARTÍCULOS ====================

  /// Busca un artículo específico por su código exacto en la base de datos local.
  Future<Articulo?> getArticuloByCodigo(String codigo);

  /// Busca un artículo duplicado por su código exacto en la base de datos local.
  Future<Articulo?> getArticuloDuplicadoByCodigo(String codigo);

  /// Obtiene la lista de artículos con soporte para paginación (Local).
  /// Utilizado para el scroll infinito de la vista principal.
  Future<List<Articulo>> getArticulosPaginados({
    int limit = 100,
    int offset = 0,
  });

  /// Realiza una búsqueda global por texto (LIKE) en campos clave: codigo, descripcion y referencia.
  Future<List<Articulo>> buscarArticulosPorTexto(String query);

  // ==================== ACTUALIZACIONES ====================

  /// Actualiza los datos del artículo únicamente en la base de datos SQLite.
  Future<void> actualizarArticuloLocal(
    String codigo,
    String? nuevaDescripcion,
    int? nuevaCantidadMinima,
  );

  /// Envía la actualización al servidor remoto y sincroniza el cambio en local tras el éxito.
  Future<void> actualizarArticuloRemoto(
    String codigo,
    String? nuevaDescripcion,
    int? nuevaCantidadMinima,
  );
}