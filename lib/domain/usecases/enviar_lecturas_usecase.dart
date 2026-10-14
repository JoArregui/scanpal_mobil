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

    // 2. Capturamos el momento exacto del envío para el historial de seguridad
    final ahora = DateTime.now();

    final lecturasParaEnviar = lecturasSinFecha.map((l) {
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
        fechaEnvio: ahora,
        descripcion: descLimpia,
        referenciaArticulo: refLimpia,
        codigoArticulo: codLimpia,
      );
    }).toList();

    try {
      // 3. Enviamos al servidor remoto
      await repository.enviarLecturas(lecturasParaEnviar);

      // 4. Marcamos como sincronizadas en la DB local (Esto les pone el check de 90 días)
      await repository.marcarLecturasComoSincronizadas(lecturasParaEnviar);

      return lecturasParaEnviar.length;
    } catch (e) {
      rethrow;
    }
  }
}
