import '../../domain/entities/documento_esperado.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../core/database_helper.dart';

abstract class DocumentoLocalDataSource {
  Future<void> saveDocumento(DocumentoEsperado documento);
  Future<DocumentoEsperado?> getDocumento(TipoOperacion tipo, String numero);
  Future<List<DocumentoEsperado>> listDocumentos({TipoOperacion? tipo});
  Future<void> deleteDocumento(TipoOperacion tipo, String numero);
}

class DocumentoLocalDataSourceImpl implements DocumentoLocalDataSource {
  final DatabaseHelper dbHelper;

  DocumentoLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<void> saveDocumento(DocumentoEsperado documento) async {
    final db = await dbHelper.database;
    final map = documento.toMap()..remove('id');
    // Un documento por (tipo, numero): el más reciente manda.
    await db.delete(
      DatabaseHelper.tableNameDocumentos,
      where:
          '${DatabaseHelper.colDocTipo} = ? AND ${DatabaseHelper.colDocNumero} = ?',
      whereArgs: [documento.tipo.name, documento.numero.trim()],
    );
    map['numero'] = documento.numero.trim();
    await db.insert(DatabaseHelper.tableNameDocumentos, map);
  }

  @override
  Future<DocumentoEsperado?> getDocumento(
    TipoOperacion tipo,
    String numero,
  ) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNameDocumentos,
      where:
          '${DatabaseHelper.colDocTipo} = ? AND ${DatabaseHelper.colDocNumero} = ?',
      whereArgs: [tipo.name, numero.trim()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DocumentoEsperado.fromMap(_rowToMap(maps.first));
  }

  @override
  Future<List<DocumentoEsperado>> listDocumentos({
    TipoOperacion? tipo,
  }) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableNameDocumentos,
      where: tipo == null ? null : '${DatabaseHelper.colDocTipo} = ?',
      whereArgs: tipo == null ? null : [tipo.name],
      orderBy: '${DatabaseHelper.colDocId} DESC',
    );
    return maps.map((m) => DocumentoEsperado.fromMap(_rowToMap(m))).toList();
  }

  @override
  Future<void> deleteDocumento(TipoOperacion tipo, String numero) async {
    final db = await dbHelper.database;
    await db.delete(
      DatabaseHelper.tableNameDocumentos,
      where:
          '${DatabaseHelper.colDocTipo} = ? AND ${DatabaseHelper.colDocNumero} = ?',
      whereArgs: [tipo.name, numero.trim()],
    );
  }

  Map<String, dynamic> _rowToMap(Map<String, dynamic> row) {
    return {
      'id': row[DatabaseHelper.colDocId],
      'tipo': row[DatabaseHelper.colDocTipo],
      'numero': row[DatabaseHelper.colDocNumero],
      'fecha': row[DatabaseHelper.colDocFecha],
      'tercero': row[DatabaseHelper.colDocTercero],
      'lineas_json': row[DatabaseHelper.colDocLineas],
    };
  }
}
