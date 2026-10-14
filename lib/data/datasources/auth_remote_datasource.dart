import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../domain/repositories/configuracion_repository.dart';
import '../../domain/entities/configuracion.dart';

abstract class AuthRemoteDataSource {
  Future<int> login(String nombre, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;
  final ConfiguracionRepository configRepository;

  AuthRemoteDataSourceImpl({
    required this.client,
    required this.configRepository,
  });

  @override
  Future<int> login(String nombre, String password) async {
    final Configuracion config = await configRepository.getConfiguracion();

    // Priorizamos la URL de configuración, si no existe usamos la constante
    String baseUrl = config.urlBase.isNotEmpty 
        ? config.urlBase 
        : AppConstants.baseUrl;

    // Aseguramos que la URL base termine con /
    if (!baseUrl.endsWith('/')) {
      baseUrl += '/';
    }

    // La estructura es: baseUrl + persona/GetCodigo/{nombre}/{password}
    final url = Uri.parse('${baseUrl}persona/GetCodigo/${Uri.encodeComponent(nombre)}/${Uri.encodeComponent(password)}');
    
    try {
      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);
        
        // Según tu ejemplo, el Servidor devuelve una lista: [{ "Codigo": 1, ... }]
        if (decodedBody is List && decodedBody.isNotEmpty) {
          final firstItem = decodedBody.first;
          if (firstItem is Map && firstItem.containsKey('Codigo')) {
            // Convertimos a int por si viniera como String en otros casos
            return int.tryParse(firstItem['Codigo'].toString()) ?? 0;
          }
        } 
        
        // Si el cuerpo no es una lista pero contiene el campo directamente
        if (decodedBody is Map && decodedBody.containsKey('Codigo')) {
          return int.tryParse(decodedBody['Codigo'].toString()) ?? 0;
        }

        // Caso en el que devuelva el entero directamente
        if (decodedBody is int) {
          return decodedBody;
        }

        return 0; // Si no se encuentra el Código o la lista está vacía
      } else {
        // Si el servidor responde con error (404, 500, etc)
        return 0;
      }
    } catch (e) {
      // Error de red o timeout
      throw Exception('Error de conexión con el servidor: $e');
    }
  }
}