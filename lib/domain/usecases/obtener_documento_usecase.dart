import '../entities/documento_esperado.dart';
import '../entities/tipo_operacion.dart';
import '../repositories/documento_repository.dart';

/// Obtiene el documento: intenta servidor y cachea; si el endpoint aún no
/// existe o falla la red, devuelve la copia local (o null si no hay).
class ObtenerDocumentoUseCase {
  final DocumentoRepository repository;

  ObtenerDocumentoUseCase(this.repository);

  Future<DocumentoEsperado?> execute(
    TipoOperacion tipo,
    String numero, {
    bool forzarRemoto = false,
  }) async {
    final num = numero.trim();
    if (num.isEmpty) {
      throw Exception('El número de documento no puede estar vacío.');
    }

    try {
      return await repository.obtenerDocumentoRemoto(tipo, num);
    } catch (_) {
      if (forzarRemoto) rethrow;
      return await repository.obtenerDocumentoLocal(tipo, num);
    }
  }
}
