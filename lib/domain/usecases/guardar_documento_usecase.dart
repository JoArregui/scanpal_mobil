import '../entities/documento_esperado.dart';
import '../repositories/documento_repository.dart';

/// Guarda el documento esperado en local (carga manual o futura
/// importación) validando su contenido mínimo.
class GuardarDocumentoUseCase {
  final DocumentoRepository repository;

  GuardarDocumentoUseCase(this.repository);

  Future<void> execute(DocumentoEsperado documento) async {
    if (documento.numero.trim().isEmpty) {
      throw Exception('El número de documento no puede estar vacío.');
    }
    for (final linea in documento.lineas) {
      if (linea.referencia.trim().isEmpty &&
          (linea.codigoBarras ?? '').trim().isEmpty) {
        throw Exception(
          'Cada línea necesita referencia o código de barras.',
        );
      }
      if (linea.cantidadEsperada <= 0) {
        throw Exception('La cantidad esperada debe ser mayor que cero.');
      }
    }
    await repository.guardarDocumento(documento);
  }
}
