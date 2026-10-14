import 'package:http/http.dart' as http;
import '../../core/exceptions.dart';
import '../../domain/entities/documento_esperado.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../domain/repositories/configuracion_repository.dart';

abstract class DocumentoRemoteDataSource {
  /// Descarga el albarán (compra) o factura (venta) con sus líneas.
  Future<DocumentoEsperado> fetchDocumento(
    TipoOperacion tipo,
    String numero,
  );
}

/// Stub listo para cuando el ERP exponga el endpoint de documentos.
/// Contrato previsto (a confirmar con el servidor):
///   GET {base}/documento/GetDocumento?tipo=C|V&numero=XXX
///   → { "Numero": "...", "Fecha": "YYYY-MM-DD", "Tercero": "...",
///       "Lineas": [{ "Referencia": "...", "CodigoBarras": "...",
///                     "Descripcion": "...", "Cantidad": 0, "Lote": "..." }] }
class DocumentoRemoteDataSourceImpl implements DocumentoRemoteDataSource {
  final http.Client client;
  final ConfiguracionRepository configRepository;

  DocumentoRemoteDataSourceImpl({
    required this.client,
    required this.configRepository,
  });

  @override
  Future<DocumentoEsperado> fetchDocumento(
    TipoOperacion tipo,
    String numero,
  ) async {
    // El endpoint se integrará más adelante: se valida la configuración
    // para fallar con un mensaje útil y se deja el punto de conexión.
    final config = await configRepository.getConfiguracion();
    if (config.urlBase.isEmpty) {
      throw const ServerException('URL base no configurada.');
    }
    throw const ServerException(
      'Endpoint de documentos pendiente de integrar en el servidor.',
    );
  }
}
