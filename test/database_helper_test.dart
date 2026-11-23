import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanpalphone_app/core/exceptions.dart';
import 'package:scanpalphone_app/core/database_helper.dart';
import 'package:scanpalphone_app/data/datasources/articulo_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return Directory.systemTemp.path;
            }
            return null;
          },
        );

    SharedPreferences.setMockInitialValues({});
    dbHelper = DatabaseHelper.instance;
    await dbHelper.close();
    await deleteDatabase(await dbHelper.getDatabasePath());
    dbHelper.invalidate();
    await dbHelper.database;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('DatabaseHelper', () {
    test('singleton inicializado correctamente', () async {
      final helper = DatabaseHelper.instance;
      await helper.database;
      expect(helper.database, isNotNull);
    });

    test('ejecutar rawQuery tramite database', () async {
      final helper = DatabaseHelper.instance;
      final db = await helper.database;
      final result = await db.rawQuery('PRAGMA table_info(lecturas)');
      expect(result.length, greaterThan(0));
      final columnNames = result.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('codigo_articulo'));
    });

    test('migra bases v3 creando tabla de artículos duplicados', () async {
      final path = await dbHelper.getDatabasePath();
      await dbHelper.close();
      await deleteDatabase(path);
      final oldDatabase = await openDatabase(
        path,
        version: 3,
        onCreate: (_, _) async {},
      );
      await oldDatabase.close();

      dbHelper.invalidate();
      final migratedDatabase = await dbHelper.database;
      final tables = await migratedDatabase.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [DatabaseHelper.tableNameDuplicados],
      );

      expect(tables, hasLength(1));
      expect(
        await migratedDatabase.delete(DatabaseHelper.tableNameDuplicados),
        0,
      );
    });

    test('insertar y recuperar lectura', () async {
      final helper = DatabaseHelper.instance;
      final db = await helper.database;

      await db.insert('lecturas', {
        'codigo_articulo': '7501043100218',
        'referencia_articulo': 'REF-TEST',
        'cantidad': 5.0,
        'fecha_registro': '2024-01-15 10:30:00',
        'id_usuario': 1,
      });

      final List<Map<String, dynamic>> rows = await db.query(
        'lecturas',
        where: 'codigo_articulo = ?',
        whereArgs: ['7501043100218'],
      );
      expect(rows.length, equals(1));
      expect(rows.first['referencia_articulo'], equals('REF-TEST'));
      expect(rows.first['cantidad'], equals(5.0));
    });

    test('no encuentra artículos por coincidencia parcial del código', () async {
      final db = await dbHelper.database;
      await db.insert(DatabaseHelper.tableNameArticulos, {
        DatabaseHelper.colArtCodigo: '0123456789012',
        DatabaseHelper.colArtDescripcion: 'Producto electrónico',
        DatabaseHelper.colArtReferencia: 'REF-001',
        DatabaseHelper.colArtCantidadMinima: 1,
      });
      final dataSource = ArticuloLocalDataSourceImpl(
        getDatabase: () async => db,
      );

      await expectLater(
        dataSource.getArticuloByCodigo('12345'),
        throwsA(isA<NoLocalDataException>()),
      );
    });

    test('actualizar lectura existente', () async {
      final helper = DatabaseHelper.instance;
      final db = await helper.database;

      await db.insert('lecturas', {
        'codigo_articulo': '7501043100218',
        'referencia_articulo': 'REF-TEST',
        'cantidad': 5.0,
        'fecha_registro': '2024-01-15 10:30:00',
        'id_usuario': 1,
      });

      await db.update(
        'lecturas',
        {'cantidad': 10.0},
        where: 'codigo_articulo = ?',
        whereArgs: ['7501043100218'],
      );

      final List<Map<String, dynamic>> rows = await db.query(
        'lecturas',
        where: 'codigo_articulo = ?',
        whereArgs: ['7501043100218'],
      );
      expect(rows.length, equals(1));
      expect(rows.first['cantidad'], equals(10.0));
    });

    test('borrar lectura', () async {
      final helper = DatabaseHelper.instance;
      final db = await helper.database;

      await db.insert('lecturas', {
        'codigo_articulo': '7501043100218',
        'referencia_articulo': 'REF-TEST',
        'cantidad': 5.0,
        'fecha_registro': '2024-01-15 10:30:00',
        'id_usuario': 1,
      });

      await db.delete(
        'lecturas',
        where: 'codigo_articulo = ?',
        whereArgs: ['7501043100218'],
      );

      final List<Map<String, dynamic>> rows = await db.query(
        'lecturas',
        where: 'codigo_articulo = ?',
        whereArgs: ['7501043100218'],
      );
      expect(rows.length, equals(0));
    });

    test('obtener diagnóstico de la BD', () async {
      final helper = DatabaseHelper.instance;
      await helper.database;

      final diag = await helper.getDiagnostics();
      expect(diag, isNotNull);
    });

    test('vaciar y analizar BD', () async {
      final helper = DatabaseHelper.instance;
      await helper.database;

      await helper.vacuum();
      await helper.analyze();

      final diag = await helper.getDiagnostics();
      expect(diag, isNotNull);
    });
  });
}
