import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static const _databaseName = "ScanPalDB.db";
  static const _databaseVersion = 1;

  // ==================== TABLA LECTURAS ====================
  static const tableNameLecturas = 'lecturas';
  static const colId = '_id';
  static const colCodigo = 'codigo_articulo';
  static const colReferencia = 'referencia_articulo';
  static const colCantidad = 'cantidad';
  static const colFecha = 'fecha_registro';
  static const colFechaEnvio = 'fecha_envio';
  static const colIdUsuario = 'id_usuario';
  static const colSincronizado = 'sincronizado';
  static const colLote = 'lote';
  static const colEsDescatalogado = 'es_descatalogado';
  static const colDescripcion = 'descripcion';
  static const colTipoOperacion = 'tipo_operacion';

  // ==================== TABLA ARTÍCULOS ====================
  static const tableNameArticulos = 'articulos';
  static const colArtCodigo = 'codigo';
  static const colArtDescripcion = 'descripcion';
  static const colArtReferencia = 'referencia';
  static const colArtLote = 'lote';
  static const colArtCantidadMinima = 'cantidad_minima';
  static const colArtDescatalogado = 'descatalogado';
  static const colArtGestionLotes = 'gestion_lotes';

  // ==================== TABLA DUPLICADOS ====================
  static const tableNameDuplicados = 'articulos_duplicados';
  static const colDupId = 'id';
  static const colDupMotivo = 'motivo_duplicidad';
  static const colDupFechaDeteccion = 'fecha_deteccion';

  // ==================== TABLA LOGS ====================
  static const tableNameLogs = 'logs';
  static const colLogId = 'id';
  static const colLogTimestamp = 'timestamp';
  static const colLogLevel = 'level';
  static const colLogMessage = 'message';
  static const colLogPaquete = 'paquete';

  // ==================== TABLA METADATA ====================
  static const tableNameMetadata = 'metadata';
  static const colMetaKey = 'key';
  static const colMetaValue = 'value';

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database == null || !_database!.isOpen) {
      if (kDebugMode) debugPrint('🔄 [DB_HELPER] Reabriendo conexión...');
      _database = await _initDatabase();
    }
    return _database!;
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  Future<Database> _initDatabase() async {
    String path = await getDatabasePath();
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
      await db.rawQuery('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA synchronous=NORMAL');
      await db.execute('PRAGMA temp_store=MEMORY');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Error en configuración: $e');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableNameLecturas (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colCodigo TEXT NOT NULL,
        $colReferencia TEXT NOT NULL,
        $colCantidad REAL NOT NULL,
        $colFecha TEXT NOT NULL,
        $colFechaEnvio TEXT,
        $colIdUsuario INTEGER NOT NULL,
        $colSincronizado INTEGER NOT NULL DEFAULT 0,
        $colLote TEXT,
        $colEsDescatalogado INTEGER NOT NULL DEFAULT 0,
        $colDescripcion TEXT,
        $colTipoOperacion TEXT NOT NULL DEFAULT 'inventario'
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNameArticulos (
        $colArtCodigo TEXT PRIMARY KEY,
        $colArtDescripcion TEXT NOT NULL,
        $colArtReferencia TEXT NOT NULL,
        $colArtLote TEXT,
        $colArtCantidadMinima INTEGER NOT NULL,
        $colArtDescatalogado INTEGER NOT NULL DEFAULT 0,
        $colArtGestionLotes INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNameLogs (
        $colLogId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colLogTimestamp TEXT NOT NULL,
        $colLogLevel TEXT NOT NULL,
        $colLogMessage TEXT NOT NULL,
        $colLogPaquete INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNameMetadata (
        $colMetaKey TEXT PRIMARY KEY,
        $colMetaValue TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_articulos_referencia ON $tableNameArticulos ($colArtReferencia)',
    );
    await db.execute(
      'CREATE INDEX idx_lecturas_sincronizado ON $tableNameLecturas ($colSincronizado)',
    );
    await db.execute(
      'CREATE INDEX idx_lecturas_tipo ON $tableNameLecturas ($colTipoOperacion)',
    );
  }

  void invalidate() {
    _database = null;
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final db = await database;
      final journalMode = await db.rawQuery('PRAGMA journal_mode');
      final pageSize = await db.rawQuery('PRAGMA page_size');
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final totalSizeMB =
          ((Sqflite.firstIntValue(pageCount) ?? 0) *
              (Sqflite.firstIntValue(pageSize) ?? 0)) /
          (1024 * 1024);
      return {
        'journal_mode': journalMode.first.values.first,
        'total_size_mb': totalSizeMB.toStringAsFixed(2),
        'is_open': db.isOpen,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> analyze() async {
    final db = await database;
    await db.execute('ANALYZE');
  }
}
