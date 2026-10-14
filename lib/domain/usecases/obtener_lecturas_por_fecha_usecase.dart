import '../entities/lectura.dart';
import '../repositories/lectura_repository.dart';

class ObtenerLecturasPorFechaUseCase {
  final LecturaRepository repository;

  ObtenerLecturasPorFechaUseCase(this.repository);

  Future<List<Lectura>> execute(DateTime fecha) async {
    return await repository.obtenerLecturasPorFecha(fecha);
  }
}