import '../repositories/articulo_repository.dart';

class ActualizarArticuloUseCase {
  final ArticuloRepository repository;

  ActualizarArticuloUseCase(this.repository);

  /// Actualiza el artículo en el servidor y luego refresca el caché local.
  Future<void> executeRemoto(
    String codigo,
    String nuevaDescripcion,
    int nuevaCantidadMinima,
  ) async {
    return await repository.actualizarArticuloRemoto(
      codigo,
      nuevaDescripcion,
      nuevaCantidadMinima,
    );
  }

  /// Actualiza el artículo únicamente en la base de datos local SQLite.
  /// Útil para cambios rápidos o modos offline.
  Future<void> executeLocal(
    String codigo,
    String nuevaDescripcion,
    int nuevaCantidadMinima,
  ) async {
    return await repository.actualizarArticuloLocal(
      codigo,
      nuevaDescripcion,
      nuevaCantidadMinima,
    );
  }
}