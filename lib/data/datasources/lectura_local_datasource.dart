import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/lectura.dart';
import '../../../domain/entities/tipo_operacion.dart';
import '../../core/database_helper.dart';

abstract class LecturaLocalDataSource {
  Future<void> saveLectura(Lectura lectura);
  Future<List<Lectura>> getLecturasPendientesPorTipo(TipoOperacion tipo);
  Future<void> clearLecturas();
  Future<void> markLecturaAsSynced(
    String codigoArticulo,
    DateTime fechaRegistro,
  );
  Future<void> markLecturasAsSynced(List<Lectura> lecturas);
  Future<void> updateLectura(Lectura lectura);
  Future<void> deleteLecturaById(int id);
  Future<int> deleteOldLecturas(int days);
}

class LecturaLocalDataSourceImpl implements LecturaLocalDataSource {
  final DatabaseHelper dbHelper;

  LecturaLocalDataSourceImpl({required this.dbHelper});

  String _limpiar(String texto) {
    return texto.replaceAll(RegExp(r'\u00a0'), ' ').trim();
  }

  Map<String, dynamic> _toMap(Lectura lectura) {
    final map = <String, dynamic>{};
    if (lectura.id != null) map[DatabaseHelper.colId] = lectura.id;

    map[DatabaseHelper.colReferencia] = _limpiar(lectura.referenciaArticulo);
    map[DatabaseHelper.colCodigo] = _limpiar(lectura.codigoArticulo);
    map[DatabaseHelper.colCantidad] = lectura.cantidad;
    map[DatabaseHelper.colFecha] = lectura.fechaRegistro.toIso8601String();
    map[DatabaseHelper.colFechaEnvio] = lectura.fechaEnvio?.toIso8601String();
    map[DatabaseHelper.colIdUsuario] = lectura.idUsuario;
    map[DatabaseHelper.colSincronizado] = lectura.sincronizado ? 1 : 0;
    map[DatabaseHelper.colLote] = lectura.lote != null
        ? _limpiar(lectura.lote!)
        : null;
    map[DatabaseHelper.colEsDescatalogado] = lectura.esDescatalogado ? 1 : 0;
    map[DatabaseHelper.colDescripcion] = lectura.descripcion != null
        ? _limpiar(lectura.descripcion!)
        : null;
    map[DatabaseHelper.colTipoOperacion] = lectura.tipoOperacion.name;
    map[DatabaseHelper.colFechaCaducidad] =
        lectura.fechaCaducidad?.toIso8601String();
    map[DatabaseHelper.colPesoNeto] = lectura.pesoNeto;
    map[DatabaseHelper.colPesoBruto] = lectura.pesoBruto;
    map[DatabaseHelper.colSscc] =
        lectura.sscc != null ? _limpiar(lectura.sscc!) : null;

    return map;
  }

  Lectura _fromMap(Map<String, dynamic> map) {
    return Lectura(
      id: map[DatabaseHelper.colId] as int?,
      codigoArticulo: map[DatabaseHelper.colCodigo] as String,
      referenciaArticulo: map[DatabaseHelper.colReferencia].toString(),
      cantidad: (map[DatabaseHelper.colCantidad] as num).toDouble(),
      fechaRegistro: DateTime.parse(map[DatabaseHelper.colFecha] as String),
      fechaEnvio: map[DatabaseHelper.colFechaEnvio] != null
          ? DateTime.parse(map[DatabaseHelper.colFechaEnvio] as String)
          : null,
      idUsuario: map[DatabaseHelper.colIdUsuario] as int,
      sincronizado: map[DatabaseHelper.colSincronizado] == 1,
      lote: map[DatabaseHelper.colLote] as String?,
      esDescatalogado: map[DatabaseHelper.colEsDescatalogado] == 1,
      descripcion: map[DatabaseHelper.colDescripcion] as String?,
      tipoOperacion: TipoOperacion.values.firstWhere(
        (e) => e.name == (map[DatabaseHelper.colTipoOperacion] ?? 'inventario'),
        orElse: () => TipoOperacion.inventario,
      ),
      fechaCaducidad: map[DatabaseHelper.colFechaCaducidad] != null
          ? DateTime.parse(
              map[DatabaseHelper.colFechaCaducidad].toString(),
            )
          : null,
      pesoNeto: (map[DatabaseHelper.colPesoNeto] as num?)?.toDouble(),
      pesoBruto: (map[DatabaseHelper.colPesoBruto] as num?)?.toDouble(),
      sscc: map[DatabaseHelper.colSscc]?.toString(),
    );
  }

  @override
  Future<void> saveLectura(Lectura lectura) async {
    final db = await dbHelper.database;

    final lecturaLimpia = lectura.copyWith(
      codigoArticulo: _limpiar(lectura.codigoArticulo),
      referenciaArticulo: _limpiar(lectura.referenciaArticulo),
      lote: lectura.lote != null ? _limpiar(lectura.lote!) : null,
      descripcion: lectura.descripcion != null
          ? _limpiar(lectura.descripcion!)
          : null,
    );

    await db.insert(
      DatabaseHelper.tableNameLecturas,
      _toMap(lecturaLimpia),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> updateLectura(Lectura lectura) async {
    final db = await dbHelper.database;
    final lecturaLimpia = lectura.copyWith(
      codigoArticulo: _limpiar(lectura.codigoArticulo),
      referenciaArticulo: _limpiar(lectura.referenciaArticulo),
      lote: lectura.lote != null ? _limpiar(lectura.lote!) : null,
      descripcion: lectura.descripcion != null
          ? _limpiar(lectura.descripcion!)
          : null,
    );

    final map = _toMap(lecturaLimpia);

    if (lecturaLimpia.id == null) {
      await db.update(
        DatabaseHelper.tableNameLecturas,
        map,
        where:
            '${DatabaseHelper.colCodigo} = ? AND ${DatabaseHelper.colFecha} = ?',
        whereArgs: [
          lecturaLimpia.codigoArticulo,
          lecturaLimpia.fechaRegistro.toIso8601String(),
        ],
      );
    } else {
      await db.update(
        DatabaseHelper.tableNameLecturas,
        map,
        where: '${DatabaseHelper.colId} = ?',
        whereArgs: [lecturaLimpia.id],
      );
    }

    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<List<Lectura>> getLecturasPendientesPorTipo(TipoOperacion tipo) async {
    final db = await dbHelper.database;
    await Future.delayed(const Duration(milliseconds: 30));

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNameLecturas,
      where:
          '${DatabaseHelper.colSincronizado} = ? AND ${DatabaseHelper.colTipoOperacion} = ?',
      whereArgs: [0, tipo.name],
      orderBy: '${DatabaseHelper.colFecha} DESC',
    );
    return List.generate(maps.length, (i) => _fromMap(maps[i]));
  }

  @override
  Future<void> deleteLecturaById(int id) async {
    final db = await dbHelper.database;
    await db.delete(
      DatabaseHelper.tableNameLecturas,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
    );
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> clearLecturas() async {
    final db = await dbHelper.database;
    await db.delete(DatabaseHelper.tableNameLecturas);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> markLecturaAsSynced(
    String codigoArticulo,
    DateTime fechaRegistro,
  ) async {
    final db = await dbHelper.database;
    await db.update(
      DatabaseHelper.tableNameLecturas,
      {
        DatabaseHelper.colSincronizado: 1,
        DatabaseHelper.colFechaEnvio: DateTime.now().toIso8601String(),
      },
      where:
          '${DatabaseHelper.colCodigo} = ? AND ${DatabaseHelper.colFecha} = ?',
      whereArgs: [_limpiar(codigoArticulo), fechaRegistro.toIso8601String()],
    );
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> markLecturasAsSynced(List<Lectura> lecturas) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    final String fechaSincronizacion = DateTime.now().toIso8601String();

    for (var lectura in lecturas) {
      batch.update(
        DatabaseHelper.tableNameLecturas,
        {
          DatabaseHelper.colSincronizado: 1,
          DatabaseHelper.colFechaEnvio:
              lectura.fechaEnvio?.toIso8601String() ?? fechaSincronizacion,
        },
        where:
            '${DatabaseHelper.colCodigo} = ? AND ${DatabaseHelper.colFecha} = ?',
        whereArgs: [
          lectura.codigoArticulo,
          lectura.fechaRegistro.toIso8601String(),
        ],
      );
    }
    await batch.commit(noResult: true);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<int> deleteOldLecturas(int days) async {
    final db = await dbHelper.database;
    final String fechaLimite = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

    final count = await db.delete(
      DatabaseHelper.tableNameLecturas,
      where: '${DatabaseHelper.colFecha} < ?',
      whereArgs: [fechaLimite],
    );
    
    await Future.delayed(const Duration(milliseconds: 50));
    return count;
  }
}