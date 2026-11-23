import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scanpalphone_app/data/datasources/auth_remote_datasource.dart';
import 'package:scanpalphone_app/data/datasources/config_local_datasource.dart';
import 'package:scanpalphone_app/domain/entities/configuracion.dart';
import 'package:scanpalphone_app/domain/repositories/configuracion_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('login persists the global lot-management flag', () async {
    final configRepository = _FakeConfiguracionRepository(
      Configuracion(
        urlBase: 'https://example.test/',
        cantidadMinima: 4,
        lecturaAutomatica: true,
        intervaloLecturaAutomaticaSegundos: 6,
      ),
    );
    final dataSource = AuthRemoteDataSourceImpl(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'token': 'valid-token', 'gestionLotes': true}),
          200,
        ),
      ),
      configRepository: configRepository,
    );

    final token = await dataSource.loginWithToken('usuario', 'clave');

    expect(token, 'valid-token');
    expect(configRepository.configuracion.gestionLotes, isTrue);
    expect(configRepository.configuracion.cantidadMinima, 4);
    expect(configRepository.configuracion.lecturaAutomatica, isTrue);
    expect(
      configRepository.configuracion.intervaloLecturaAutomaticaSegundos,
      6,
    );
  });

  test(
    'login disables global lot management when the server returns false',
    () async {
      final configRepository = _FakeConfiguracionRepository(
        Configuracion(
          urlBase: 'https://example.test/',
          cantidadMinima: 4,
          lecturaAutomatica: true,
          gestionLotes: true,
          intervaloLecturaAutomaticaSegundos: 6,
        ),
      );
      final dataSource = AuthRemoteDataSourceImpl(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'token': 'valid-token', 'gestionLotes': false}),
            200,
          ),
        ),
        configRepository: configRepository,
      );

      await dataSource.loginWithToken('usuario', 'clave');

      expect(configRepository.configuracion.gestionLotes, isFalse);
      expect(
        configRepository.configuracion.intervaloLecturaAutomaticaSegundos,
        6,
      );
    },
  );

  test(
    'configuration datasource persists the global lot-management flag',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final dataSource = ConfigLocalDataSourceImpl(
        sharedPreferences: preferences,
      );
      final config = Configuracion(
        urlBase: 'https://example.test/',
        cantidadMinima: 2,
        lecturaAutomatica: false,
        gestionLotes: true,
        intervaloLecturaAutomaticaSegundos: 6,
      );

      await dataSource.saveConfiguracion(config);

      expect((await dataSource.fetchConfiguracion()).gestionLotes, isTrue);
      expect(
        (await dataSource.fetchConfiguracion())
            .intervaloLecturaAutomaticaSegundos,
        6,
      );
    },
  );

  test(
    'uses the default automatic reading interval for older preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final dataSource = ConfigLocalDataSourceImpl(
        sharedPreferences: preferences,
      );

      expect(
        (await dataSource.fetchConfiguracion())
            .intervaloLecturaAutomaticaSegundos,
        3,
      );
    },
  );
}

class _FakeConfiguracionRepository implements ConfiguracionRepository {
  _FakeConfiguracionRepository(this.configuracion);

  Configuracion configuracion;

  @override
  Future<Configuracion> getConfiguracion() async => configuracion;

  @override
  Future<void> guardarConfiguracion(Configuracion config) async {
    configuracion = config;
  }
}
