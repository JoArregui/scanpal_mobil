import '../../domain/entities/documento_esperado.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../domain/repositories/documento_repository.dart';
import '../datasources/documento_local_datasource.dart';
import '../datasources/documento_remote_datasource.dart';

class DocumentoRepositoryImpl implements DocumentoRepository {
  final DocumentoLocalDataSource localDataSource;
  final DocumentoRemoteDataSource remoteDataSource;

  DocumentoRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<DocumentoEsperado> obtenerDocumentoRemoto(
    TipoOperacion tipo,
    String numero,
  ) async {
    final documento = await remoteDataSource.fetchDocumento(tipo, numero);
    await localDataSource.saveDocumento(documento);
    return documento;
  }

  @override
  Future<void> guardarDocumento(DocumentoEsperado documento) {
    return localDataSource.saveDocumento(documento);
  }

  @override
  Future<DocumentoEsperado?> obtenerDocumentoLocal(
    TipoOperacion tipo,
    String numero,
  ) {
    return localDataSource.getDocumento(tipo, numero);
  }

  @override
  Future<List<DocumentoEsperado>> listarDocumentos({TipoOperacion? tipo}) {
    return localDataSource.listDocumentos(tipo: tipo);
  }

  @override
  Future<void> borrarDocumento(TipoOperacion tipo, String numero) {
    return localDataSource.deleteDocumento(tipo, numero);
  }
}
