import '../../core/constants.dart';
import '../entities/tipo_operacion.dart';
import '../repositories/lectura_repository.dart';

class EnviarLecturasUseCase {
  final LecturaRepository repository;

  EnviarLecturasUseCase(this.repository);

  Future<int> execute(TipoOperacion tipo) async {
    // 1. Obtenemos las pendientes del tipo específico (ej. Inventario)
    final lecturasSinFecha = await repository.obtenerLecturasPendientes(tipo);

    if (lecturasSinFecha.isEmpty) {
      return 0;
    }

    final lecturasPreparadas = lecturasSinFecha.map((l) {
      String descLimpia = (l.descripcion ?? '')
          .replaceAll(RegExp(r'\u00a0'), ' ')
          .trim();
      String refLimpia = l.referenciaArticulo
          .replaceAll(RegExp(r'\u00a0'), ' ')
          .trim();
      String codLimpia = l.codigoArticulo
          .replaceAll(RegExp(r'\u00a0'), ' ')
          .trim();

      // Limpieza de códigos redundantes en la descripción
      if (codLimpia.isNotEmpty && descLimpia.contains(codLimpia)) {
        descLimpia = descLimpia.replaceAll(codLimpia, '').trim();
        descLimpia = descLimpia.replaceFirst(RegExp(r'^[.\-:/]+'), '').trim();
      }

      if (descLimpia.isEmpty) descLimpia = refLimpia;

      return l.copyWith(
        descripcion: descLimpia,
        referenciaArticulo: refLimpia,
        codigoArticulo: codLimpia,
      );
    }).toList();

    var totalEnviadas = 0;
    for (
      var inicio = 0;
      inicio < lecturasPreparadas.length;
      inicio += AppConstants.batchSize
    ) {
      final fin = (inicio + AppConstants.batchSize < lecturasPreparadas.length)
          ? inicio + AppConstants.batchSize
          : lecturasPreparadas.length;
      final fechaEnvio = DateTime.now();
      final loteParaEnviar = lecturasPreparadas
          .sublist(inicio, fin)
          .map((lectura) => lectura.copyWith(fechaEnvio: fechaEnvio))
          .toList();

      await repository.enviarLecturas(loteParaEnviar);
      await repository.marcarLecturasComoSincronizadas(loteParaEnviar);
      totalEnviadas += loteParaEnviar.length;
    }

    return totalEnviadas;
  }
}
