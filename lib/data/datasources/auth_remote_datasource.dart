import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../domain/repositories/configuracion_repository.dart';
import '../../domain/entities/configuracion.dart';

abstract class AuthRemoteDataSource {
  Future<String?> loginWithToken(String nombre, String password);
  Future<int> getUserCodeFromToken(String token);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;
  final ConfiguracionRepository configRepository;

  AuthRemoteDataSourceImpl({
    required this.client,
    required this.configRepository,
  });

  @override
  Future<String?> loginWithToken(String nombre, String password) async {
    final Configuracion config = await configRepository.getConfiguracion();

    String baseUrl = config.urlBase.isNotEmpty
        ? config.urlBase
        : AppConstants.baseUrl;

    if (!baseUrl.endsWith('/')) {
      baseUrl += '/';
    }

    final url = Uri.parse('${baseUrl}api/auth/login');

    final response = await client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'codigo': nombre, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 400) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'El servidor respondió HTTP ${response.statusCode} al iniciar sesión.',
      );
    }

    final dynamic decodedBody = json.decode(response.body);
    if (decodedBody is Map && decodedBody['token'] is String) {
      final configActual = await configRepository.getConfiguracion();
      await configRepository.guardarConfiguracion(
        Configuracion(
          urlBase: configActual.urlBase,
          cantidadMinima: configActual.cantidadMinima,
          lecturaAutomatica: configActual.lecturaAutomatica,
          intervaloLecturaAutomaticaSegundos:
              configActual.intervaloLecturaAutomaticaSegundos,
          gestionLotes: _parseBool(
            decodedBody['gestionLotes'] ?? decodedBody['GestionLotes'],
          ),
        ),
      );
      return decodedBody['token'] as String;
    }

    throw Exception('La respuesta del servidor no contiene un token válido.');
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  @override
  Future<int> getUserCodeFromToken(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return 0;
      }

      final payload = parts[1];
      final normalizedPayload = base64Url.normalize(payload);
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final decodedBody = json.decode(decodedPayload);

      if (decodedBody is! Map) {
        return 0;
      }

      const possibleKeys = [
        'codigo',
        'userCode',
        'user_code',
        'id',
        'nameid',
        'sub',
      ];
      for (final key in possibleKeys) {
        if (decodedBody.containsKey(key)) {
          final value = decodedBody[key];
          final parsed = int.tryParse(value?.toString() ?? '');
          if (parsed != null && parsed > 0) {
            return parsed;
          }
        }
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }
}
