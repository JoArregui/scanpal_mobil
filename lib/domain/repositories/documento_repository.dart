import '../entities/documento_esperado.dart';
import '../entities/tipo_operacion.dart';

abstract class DocumentoRepository {
  /// Descarga el documento del servidor. Lanza [ServerException] con el
  /// mensaje de endpoint pendiente hasta que el ERP lo exponga.
  Future<DocumentoEsperado> obtenerDocumentoRemoto(
    TipoOperacion tipo,
    String numero,
  );

  /// Guarda (o reemplaza) el documento en la caché local.
  Future<void> guardarDocumento(DocumentoEsperado documento);

  /// Recupera el documento de la caché local, o null si no existe.
  Future<DocumentoEsperado?> obtenerDocumentoLocal(
    TipoOperacion tipo,
    String numero,
  );

  /// Lista los documentos guardados, opcionalmente filtrados por tipo.
  Future<List<DocumentoEsperado>> listarDocumentos({TipoOperacion? tipo});

  /// Borra un documento de la caché local.
  Future<void> borrarDocumento(TipoOperacion tipo, String numero);
}
