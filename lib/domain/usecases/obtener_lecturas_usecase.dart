import '../entities/lectura.dart';
import '../entities/tipo_operacion.dart';
import '../repositories/lectura_repository.dart';

class ObtenerLecturasUseCase {
  final LecturaRepository repository;
  
  ObtenerLecturasUseCase(this.repository);

  Future<List<Lectura>> execute(TipoOperacion tipo) async {
    // El repositorio debe filtrar por tipo de operación
    return await repository.obtenerLecturasPendientes(tipo);
  }
}