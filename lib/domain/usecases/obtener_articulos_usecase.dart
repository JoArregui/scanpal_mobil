import '../entities/articulo.dart';
import '../repositories/articulo_repository.dart';

class ObtenerArticulosUseCase {
  final ArticuloRepository repository;
  ObtenerArticulosUseCase(this.repository);

  /// Obtiene artículos de la base de datos local con paginación.
  Future<List<Articulo>> execute({int limit = 500, int offset = 0}) async {
    // Cambiado para coincidir con la interfaz del repositorio
    return await repository.getArticulosPaginados(limit: limit, offset: offset);
  }
}