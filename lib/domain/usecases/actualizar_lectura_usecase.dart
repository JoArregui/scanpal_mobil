import '../entities/lectura.dart';
import '../repositories/lectura_repository.dart';

class ActualizarLecturaUseCase {
  final LecturaRepository repository;

  ActualizarLecturaUseCase(this.repository);

  Future<void> execute({
    required Lectura lectura,
    required double nuevaCantidad,
  }) async {
    if (nuevaCantidad <= 0) {
      throw Exception("La cantidad a actualizar debe ser mayor que cero.");
    }

    final lecturaActualizada = lectura.copyWith(
      cantidad: nuevaCantidad,
      sincronizado: false,
      fechaEnvio: null,
    );

    return await repository.actualizarLectura(lecturaActualizada);
  }

  Future<void> delete(int id) async {
    return await repository.borrarLecturaPorId(id);
  }
}