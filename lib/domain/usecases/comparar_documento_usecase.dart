import '../entities/documento_esperado.dart';
import '../repositories/documento_repository.dart';
import '../repositories/lectura_repository.dart';

/// Compara el documento guardado con las lecturas pendientes del mismo
/// tipo: indica qué falta, qué va parcial y qué sobra.
class CompararDocumentoUseCase {
  final DocumentoRepository documentoRepository;
  final LecturaRepository lecturaRepository;

  CompararDocumentoUseCase(
    this.documentoRepository,
    this.lecturaRepository,
  );

  Future<ResultadoComprobacion?> execute(
    DocumentoEsperado documento,
  ) async {
    final lecturas = await lecturaRepository.obtenerLecturasPendientes(
      documento.tipo,
    );
    return compararDocumentoConLecturas(documento, lecturas);
  }
}
