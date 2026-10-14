import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_android/sqflite_android.dart';

import '../../core/exceptions.dart';
import '../../domain/entities/articulo.dart';
import '../../core/database_helper.dart';
import '../../core/sync_progress.dart';

// ==================== PARÁMETROS PARA ISOLATE ====================

class _SaveArticulosParams {
  final List<Map<String, dynamic>> articulosJson;
  final String dbPath;
  final String appDocsPath;
  final SendPort sendPort;
  final RootIsolateToken rootToken;

  _SaveArticulosParams({
    required this.articulosJson,
    required this.dbPath,
    required this.appDocsPath,
    required this.sendPort,
    required this.rootToken,
  });
}

// ==================== FUNCIÓN ISOLATE (PROCESAMIENTO PESADO) ====================

@pragma('vm:entry-point')
void _heavyInsertIsolate(_SaveArticulosParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);

  try {
    SqfliteAndroid.registerWith();
  } catch (e) {}

  Database? db;
  try {
    db = await openDatabase(
      params.dbPath,
      onConfigure: (database) async {
        try {
          await database.execute('PRAGMA journal_mode=WAL');
          await database.execute('PRAGMA synchronous=NORMAL');
          await database.execute('PRAGMA temp_store=MEMORY');
          await database.rawQuery('PRAGMA cache_size=-64000');
        } catch (e) {}
      },
    );

    // 1. Asegurar tablas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableNameMetadata} (
        ${DatabaseHelper.colMetaKey} TEXT PRIMARY KEY,
        ${DatabaseHelper.colMetaValue} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableNameArticulos} (
        ${DatabaseHelper.colArtCodigo} TEXT PRIMARY KEY,
        ${DatabaseHelper.colArtDescripcion} TEXT NOT NULL,
        ${DatabaseHelper.colArtReferencia} TEXT NOT NULL,
        ${DatabaseHelper.colArtLote} TEXT,
        ${DatabaseHelper.colArtCantidadMinima} INTEGER NOT NULL,
        ${DatabaseHelper.colArtDescatalogado} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseHelper.colArtGestionLotes} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseHelper.tableNameDuplicados} (
        ${DatabaseHelper.colDupId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseHelper.colArtCodigo} TEXT NOT NULL,
        ${DatabaseHelper.colArtDescripcion} TEXT NOT NULL,
        ${DatabaseHelper.colArtReferencia} TEXT NOT NULL,
        ${DatabaseHelper.colArtLote} TEXT,
        ${DatabaseHelper.colArtCantidadMinima} INTEGER NOT NULL,
        ${DatabaseHelper.colArtDescatalogado} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseHelper.colArtGestionLotes} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseHelper.colDupMotivo} TEXT,
        ${DatabaseHelper.colDupFechaDeteccion} TEXT NOT NULL
      )
    ''');

    // 2. Clasificación: Únicos vs Duplicados
    int brutosActivos = 0;
    int brutosDescatalogados = 0;
    final Set<String> codigosVistos = {};

    final List<Map<String, dynamic>> listaUnicos = [];
    final List<Map<String, dynamic>> listaDuplicados = [];

    final String timestampDeteccion = DateTime.now().toIso8601String();
    final stopwatch = Stopwatch()..start();

    for (final artJson in params.articulosJson) {
      final isDescatalogado = (artJson['descatalogado'] as int? ?? 0) == 1;
      if (isDescatalogado) {
        brutosDescatalogados++;
      } else {
        brutosActivos++;
      }

      final String codigo = artJson['codigo'] as String;

      if (codigosVistos.contains(codigo)) {
        listaDuplicados.add({
          DatabaseHelper.colArtCodigo: artJson['codigo'],
          DatabaseHelper.colArtDescripcion: artJson['descripcion'],
          DatabaseHelper.colArtReferencia: artJson['referencia'],
          DatabaseHelper.colArtLote: artJson['lote'],
          DatabaseHelper.colArtCantidadMinima: artJson['cantidadMinima'],
          DatabaseHelper.colArtDescatalogado: artJson['descatalogado'],
          DatabaseHelper.colArtGestionLotes: artJson['gestionLotes'],
          DatabaseHelper.colDupMotivo: "Duplicado en respuesta API",
          DatabaseHelper.colDupFechaDeteccion: timestampDeteccion,
        });
      } else {
        codigosVistos.add(codigo);
        listaUnicos.add(artJson);
      }
    }

    // 3. Transacción Atómica
    await db.transaction((txn) async {
      await txn.delete(DatabaseHelper.tableNameArticulos);
      await txn.delete(DatabaseHelper.tableNameDuplicados);

      const int chunkSize = 1500;
      int procesadosContador = 0;
      final int totalAPI = params.articulosJson.length;

      // Inserción de Operativos
      for (int i = 0; i < listaUnicos.length; i += chunkSize) {
        final endIdx = (i + chunkSize > listaUnicos.length)
            ? listaUnicos.length
            : i + chunkSize;
        final chunk = listaUnicos.sublist(i, endIdx);

        final batch = txn.batch();
        for (final art in chunk) {
          batch.insert(DatabaseHelper.tableNameArticulos, {
            DatabaseHelper.colArtCodigo: art['codigo'],
            DatabaseHelper.colArtDescripcion: art['descripcion'],
            DatabaseHelper.colArtReferencia: art['referencia'],
            DatabaseHelper.colArtLote: art['lote'],
            DatabaseHelper.colArtCantidadMinima: art['cantidadMinima'],
            DatabaseHelper.colArtDescatalogado: art['descatalogado'],
            DatabaseHelper.colArtGestionLotes: art['gestionLotes'],
          });
        }
        await batch.commit(noResult: true);

        procesadosContador += chunk.length;

        params.sendPort.send({
          'type': 'progress',
          'procesados': procesadosContador,
          'total': totalAPI,
          'porcentaje': procesadosContador / totalAPI,
          'velocidad':
              procesadosContador / (stopwatch.elapsedMilliseconds / 1000),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      }

      // Inserción de Duplicados
      if (listaDuplicados.isNotEmpty) {
        final batchDup = txn.batch();
        for (final dup in listaDuplicados) {
          batchDup.insert(DatabaseHelper.tableNameDuplicados, dup);
        }
        await batchDup.commit(noResult: true);

        procesadosContador += listaDuplicados.length;
        params.sendPort.send({
          'type': 'progress',
          'procesados': procesadosContador,
          'total': totalAPI,
          'porcentaje': 1.0,
          'velocidad':
              procesadosContador / (stopwatch.elapsedMilliseconds / 1000),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      }

      // 4. Metadatos
      final batchMeta = txn.batch();
      final stats = {
        'total_articulos_api': totalAPI.toString(),
        'total_activos_api': brutosActivos.toString(),
        'total_descatalogados_api': brutosDescatalogados.toString(),
        'total_duplicados_api': listaDuplicados.length.toString(),
      };

      stats.forEach((key, value) {
        batchMeta.insert(
          DatabaseHelper.tableNameMetadata,
          {DatabaseHelper.colMetaKey: key, DatabaseHelper.colMetaValue: value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      await batchMeta.commit(noResult: true);
    });

    if (db.isOpen) await db.close();
    await Future.delayed(const Duration(milliseconds: 200));
    params.sendPort.send({'type': 'complete', 'result': codigosVistos.length});
  } catch (e, stack) {
    if (db != null && db.isOpen) await db.close();
    params.sendPort.send({
      'type': 'error',
      'message': e.toString(),
      'stackTrace': stack.toString(),
    });
  }
}

// ==================== IMPLEMENTACIÓN DEL DATASOURCE ====================

class ArticuloLocalDataSourceImpl implements ArticuloLocalDataSource {
  final Future<Database> Function() getDatabase;
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  final Map<String, Articulo> _articuloCache = {};
  static const int _maxCacheSize = 300;

  @override
  Stream<SyncProgress> get syncProgressStream => _progressController.stream;

  ArticuloLocalDataSourceImpl({required this.getDatabase});

  /// Mapea un Map de la BD a la Entidad Articulo
  Articulo _mapToEntity(Map<String, dynamic> map) {
    final rawReferencia = map[DatabaseHelper.colArtReferencia];
    String referenciaStr;
    if (rawReferencia is num) {
      referenciaStr = rawReferencia.toInt().toString();
    } else {
      referenciaStr = rawReferencia.toString().split('.').first;
    }

    return Articulo(
      codigo: map[DatabaseHelper.colArtCodigo] as String,
      descripcion: map[DatabaseHelper.colArtDescripcion] as String,
      referencia: referenciaStr,
      lote: map[DatabaseHelper.colArtLote] as String?,
      cantidadMinima: map[DatabaseHelper.colArtCantidadMinima] as int,
      descatalogado: map[DatabaseHelper.colArtDescatalogado] == 1,
      gestionLotes: map[DatabaseHelper.colArtGestionLotes] == 1,
    );
  }

  @override
  Future<int> countArticulos() async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableNameArticulos}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> countArticulosActivos() async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableNameArticulos} WHERE ${DatabaseHelper.colArtDescatalogado} = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> countArticulosDescatalogados() async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableNameArticulos} WHERE ${DatabaseHelper.colArtDescatalogado} = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> countArticulosDuplicados() async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableNameDuplicados}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> saveStatsAPI({
    required int total,
    required int activos,
    required int descatalogados,
  }) async {
    final db = await getDatabase();
    final batch = db.batch();
    batch.insert(
      DatabaseHelper.tableNameMetadata,
      {
        DatabaseHelper.colMetaKey: 'total_articulos_api',
        DatabaseHelper.colMetaValue: total.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      DatabaseHelper.tableNameMetadata,
      {
        DatabaseHelper.colMetaKey: 'total_activos_api',
        DatabaseHelper.colMetaValue: activos.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      DatabaseHelper.tableNameMetadata,
      {
        DatabaseHelper.colMetaKey: 'total_descatalogados_api',
        DatabaseHelper.colMetaValue: descatalogados.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  Future<int> _getMetaInt(String key) async {
    try {
      final db = await getDatabase();
      final result = await db.query(
        DatabaseHelper.tableNameMetadata,
        where: '${DatabaseHelper.colMetaKey} = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (result.isNotEmpty) {
        return int.tryParse(
              result.first[DatabaseHelper.colMetaValue] as String,
            ) ??
            0;
      }
    } catch (e) {
      debugPrint('⚠️ Error meta $key: $e');
    }
    return 0;
  }

  @override
  Future<int> getTotalArticulosAPI() async =>
      await _getMetaInt('total_articulos_api');
  @override
  Future<int> getTotalActivosAPI() async =>
      await _getMetaInt('total_activos_api');
  @override
  Future<int> getTotalDescatalogadosAPI() async =>
      await _getMetaInt('total_descatalogados_api');
  @override
  Future<int> getTotalDuplicadosAPI() async =>
      await _getMetaInt('total_duplicados_api');

  @override
  Future<Articulo> getArticuloByCodigo(String codigo) async {
    final String valorBusqueda = codigo.trim();
    if (_articuloCache.containsKey(valorBusqueda)) {
      return _articuloCache[valorBusqueda]!;
    }

    final db = await getDatabase();

    // Intento 1: código exacto
    var maps = await db.query(
      DatabaseHelper.tableNameArticulos,
      where: '${DatabaseHelper.colArtCodigo} = ?',
      whereArgs: [valorBusqueda],
      limit: 1,
    );

    // Intento 2: referencia exacta
    if (maps.isEmpty) {
      maps = await db.query(
        DatabaseHelper.tableNameArticulos,
        where: '${DatabaseHelper.colArtReferencia} = ?',
        whereArgs: [valorBusqueda],
        limit: 1,
      );
    }

    // Intento 3: [NUEVO] el código de BD contiene el valor escaneado (LIKE %valor%)
    // Cubre casos como: escáner lee "10548" y en BD el código es "00010548"
    if (maps.isEmpty) {
      maps = await db.query(
        DatabaseHelper.tableNameArticulos,
        where: '${DatabaseHelper.colArtCodigo} LIKE ?',
        whereArgs: ['%$valorBusqueda%'],
        limit: 1,
      );
    }

    // Intento 4: [NUEVO] la referencia de BD contiene el valor escaneado (LIKE %valor%)
    if (maps.isEmpty) {
      maps = await db.query(
        DatabaseHelper.tableNameArticulos,
        where: '${DatabaseHelper.colArtReferencia} LIKE ?',
        whereArgs: ['%$valorBusqueda%'],
        limit: 1,
      );
    }

    if (maps.isNotEmpty) {
      final articulo = _mapToEntity(maps.first);
      _addToCache(valorBusqueda, articulo);
      return articulo;
    }
    throw NoLocalDataException('No se encontró artículo: $valorBusqueda.');
  }

  void _addToCache(String key, Articulo articulo) {
    if (_articuloCache.length >= _maxCacheSize) {
      _articuloCache.remove(_articuloCache.keys.first);
    }
    _articuloCache[key] = articulo;
  }

  void clearCache() => _articuloCache.clear();

  @override
  Future<Articulo?> getArticuloDuplicadoByCodigo(String codigo) async {
    final db = await getDatabase();
    final maps = await db.query(
      DatabaseHelper.tableNameDuplicados,
      where: '${DatabaseHelper.colArtCodigo} = ?',
      whereArgs: [codigo.trim()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return _mapToEntity(maps.first);
    }
    return null;
  }

  @override
  Future<void> saveArticulo(Articulo articulo) async {
    final db = await getDatabase();
    await db.insert(
      DatabaseHelper.tableNameArticulos,
      {
        DatabaseHelper.colArtCodigo: articulo.codigo,
        DatabaseHelper.colArtDescripcion: articulo.descripcion,
        DatabaseHelper.colArtReferencia: articulo.referencia,
        DatabaseHelper.colArtLote: articulo.lote,
        DatabaseHelper.colArtCantidadMinima: articulo.cantidadMinima,
        DatabaseHelper.colArtDescatalogado: articulo.descatalogado ? 1 : 0,
        DatabaseHelper.colArtGestionLotes: articulo.gestionLotes ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _addToCache(articulo.codigo, articulo);
  }

  @override
  Future<void> saveArticulos(List<Articulo> articulos) async {
    if (articulos.isEmpty) return;

    final articulosJson = articulos
        .map(
          (art) => {
            'codigo': art.codigo,
            'descripcion': art.descripcion,
            'referencia': art.referencia,
            'lote': art.lote,
            'cantidadMinima': art.cantidadMinima,
            'descatalogado': art.descatalogado ? 1 : 0,
            'gestionLotes': art.gestionLotes ? 1 : 0,
          },
        )
        .toList();

    await DatabaseHelper.instance.close();
    final dbPath = await DatabaseHelper.instance.getDatabasePath();
    final docsDir = await getApplicationDocumentsDirectory();
    final receivePort = ReceivePort();
    final completer = Completer<void>();

    receivePort.listen((message) {
      if (message is Map) {
        if (message['type'] == 'progress' && !_progressController.isClosed) {
          _progressController.add(
            SyncProgress(
              procesados: message['procesados'],
              total: message['total'],
              porcentaje: message['porcentaje'],
              articulosPorSegundo: (message['velocidad'] as num).toDouble(),
              elapsed: Duration(milliseconds: message['elapsed_ms']),
            ),
          );
        } else if (message['type'] == 'complete') {
          receivePort.close();
          completer.complete();
        } else if (message['type'] == 'error') {
          receivePort.close();
          completer.completeError(message['message']);
        }
      }
    });

    await Isolate.spawn(
      _heavyInsertIsolate,
      _SaveArticulosParams(
        articulosJson: articulosJson,
        dbPath: dbPath,
        appDocsPath: docsDir.path,
        sendPort: receivePort.sendPort,
        rootToken: RootIsolateToken.instance!,
      ),
    );

    try {
      await completer.future.timeout(const Duration(minutes: 15));
    } finally {
      clearCache();
      DatabaseHelper.instance.invalidate();
      await DatabaseHelper.instance.database;
    }
  }

  @override
  Future<List<Articulo>> getAllArticulos({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await getDatabase();
    final maps = await db.query(
      DatabaseHelper.tableNameArticulos,
      limit: limit,
      offset: offset,
      orderBy: '${DatabaseHelper.colArtReferencia} ASC',
    );
    return List.generate(maps.length, (i) => _mapToEntity(maps[i]));
  }

  @override
  Future<List<Articulo>> buscarArticulos(String query) async {
    final db = await getDatabase();
    final maps = await db.query(
      DatabaseHelper.tableNameArticulos,
      where:
          '${DatabaseHelper.colArtCodigo} LIKE ? OR ${DatabaseHelper.colArtDescripcion} LIKE ? OR ${DatabaseHelper.colArtReferencia} LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 100,
      orderBy: '${DatabaseHelper.colArtDescripcion} ASC',
    );
    return List.generate(maps.length, (i) => _mapToEntity(maps[i]));
  }

  @override
  Future<void> clearArticulos() async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete(DatabaseHelper.tableNameArticulos);
      await txn.delete(DatabaseHelper.tableNameDuplicados);
    });
    clearCache();
  }

  @override
  Future<File?> generarCsvCompleto() async {
    try {
      final db = await getDatabase();
      final maps = await db.query(DatabaseHelper.tableNameArticulos);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/SCANPAL_CATALOGO_COMPLETO.csv');
      final sink = file.openWrite();
      sink.write("sep=;\nCÓDIGO;DESCRIPCIÓN;REFERENCIA;LOTE;CANT_MIN;ESTADO\n");
      for (final m in maps) {
        final estado = m[DatabaseHelper.colArtDescatalogado] == 1
            ? "DESCATALOGADO"
            : "ACTIVO";
        sink.write(
          "${m[DatabaseHelper.colArtCodigo]};${m[DatabaseHelper.colArtDescripcion]};${m[DatabaseHelper.colArtReferencia]};${m[DatabaseHelper.colArtLote] ?? ''};${m[DatabaseHelper.colArtCantidadMinima]};$estado\n",
        );
      }
      await sink.close();
      return file;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<File?> generarCsvDuplicados(List<String> duplicadosRaw) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/SCANPAL_REPORT_DUPLICADOS.csv');
      final sink = file.openWrite();
      sink.write("sep=;\nCÓDIGO DUPLICADO;DESCRIPCIÓN;REFERENCIA\n");
      for (final linea in duplicadosRaw) {
        sink.write("$linea\n");
      }
      await sink.close();
      return file;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _progressController.close();
    clearCache();
  }
}

abstract class ArticuloLocalDataSource {
  Stream<SyncProgress> get syncProgressStream;
  Future<int> countArticulos();
  Future<int> countArticulosActivos();
  Future<int> countArticulosDescatalogados();
  Future<int> countArticulosDuplicados();
  Future<void> saveStatsAPI({
    required int total,
    required int activos,
    required int descatalogados,
  });
  Future<int> getTotalArticulosAPI();
  Future<int> getTotalActivosAPI();
  Future<int> getTotalDescatalogadosAPI();
  Future<int> getTotalDuplicadosAPI();
  Future<Articulo> getArticuloByCodigo(String codigo);
  Future<Articulo?> getArticuloDuplicadoByCodigo(String codigo);
  Future<void> saveArticulo(Articulo articulo);
  Future<void> saveArticulos(List<Articulo> articulos);
  Future<List<Articulo>> getAllArticulos({int limit = 100, int offset = 0});
  Future<List<Articulo>> buscarArticulos(String query);
  Future<void> clearArticulos();
  Future<File?> generarCsvCompleto();
  Future<File?> generarCsvDuplicados(List<String> duplicadosRaw);
}