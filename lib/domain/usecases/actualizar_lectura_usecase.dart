import '../entities/lectura.dart';
import '../repositories/lectura_repository.dart';

class ActualizarLecturaUseCase {
  final LecturaRepository repository;

  ActualizarLecturaUseCase(this.repository);

  Future<void> execute({
    required Lectura lectura,
    double? nuevaCantidad,
    DateTime? nuevaFechaCaducidad,
    // true => quitar la fecha (null). Si es false y nuevaFechaCaducidad
    // es null, la fecha se conserva.
    bool quitarFechaCaducidad = false,
  }) async {
    if (nuevaCantidad != null && nuevaCantidad <= 0) {
      throw Exception("La cantidad a actualizar debe ser mayor que cero.");
    }

    final lecturaActualizada = lectura.copyWith(
      cantidad: nuevaCantidad,
      fechaCaducidad: nuevaFechaCaducidad,
      quitarFechaCaducidad: quitarFechaCaducidad,
      sincronizado: false,
      fechaEnvio: null,
    );

    return await repository.actualizarLectura(lecturaActualizada);
  }

  Future<void> delete(int id) async {
    return await repository.borrarLecturaPorId(id);
  }
}