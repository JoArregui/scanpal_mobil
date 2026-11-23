import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scanpalphone_app/core/database_helper.dart';
import 'package:scanpalphone_app/core/exceptions.dart';
import 'package:scanpalphone_app/data/datasources/auth_local_datasource.dart';
import 'package:scanpalphone_app/data/datasources/lectura_remote_datasource.dart';
import 'package:scanpalphone_app/domain/entities/configuracion.dart';
import 'package:scanpalphone_app/domain/entities/lectura.dart';
import 'package:scanpalphone_app/domain/repositories/configuracion_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'lectura_remote_datasource_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDirectory.path;
            }
            return null;
          },
        );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tempDirectory.delete(recursive: true);
  });

  test('sends a lecture array with an ISO 8601 date', () async {
    http.Request? capturedRequest;
    final fechaEnvio = DateTime(2026, 11, 18, 12, 0);
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response('{"lecturasRecibidas":1}', 200);
    });

    final dataSource = LecturaRemoteDataSourceImpl(
      client: client,
      configRepository: _FakeConfiguracionRepository(),
      authLocalDataSource: _FakeAuthLocalDataSource(),
    );

    await dataSource.sendLecturas([
      Lectura(
        codigoArticulo: '8412345678901',
        referenciaArticulo: 'REF-123',
        cantidad: 2,
        fechaRegistro: DateTime(2026, 11, 17, 11, 30),
        fechaEnvio: fechaEnvio,
        idUsuario: 1661,
      ),
    ]);

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.headers['Authorization'], 'Bearer test-token');

    final body = jsonDecode(capturedRequest!.body) as List<dynamic>;
    expect(body, hasLength(1));
    final lectura = body.single as Map<String, dynamic>;

    expect(lectura['Usuario'], 1661);
    expect(lectura['FechaEnvio'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
    expect(DateTime.parse(lectura['FechaEnvio'] as String), fechaEnvio);
  });

  test(
    'does not retry when the server confirms zero received lectures',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('{"lecturasRecibidas":0}', 200);
      });

      final dataSource = LecturaRemoteDataSourceImpl(
        client: client,
        configRepository: _FakeConfiguracionRepository(),
        authLocalDataSource: _FakeAuthLocalDataSource(),
      );

      await expectLater(
        dataSource.sendLecturas([
          Lectura(
            codigoArticulo: '8412345678901',
            referenciaArticulo: 'REF-123',
            cantidad: 2,
            fechaRegistro: DateTime(2026, 11, 17, 11, 30),
            idUsuario: 1661,
          ),
        ]),
        throwsA(isA<ServerException>()),
      );

      expect(requestCount, 1);
    },
  );
}

class _FakeConfiguracionRepository implements ConfiguracionRepository {
  @override
  Future<Configuracion> getConfiguracion() async => Configuracion(
    urlBase: 'https://api.example.test',
    cantidadMinima: 1,
    lecturaAutomatica: false,
  );

  @override
  Future<void> guardarConfiguracion(Configuracion config) async {}
}

class _FakeAuthLocalDataSource implements AuthLocalDataSource {
  @override
  Future<String?> getToken() async => 'test-token';

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}

  @override
  Future<int?> getUserCode() async => 1661;

  @override
  Future<void> saveUserCode(int userCode) async {}

  @override
  Future<void> clearUserCode() async {}
}
