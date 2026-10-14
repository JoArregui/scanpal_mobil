import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;
import '../../core/exceptions.dart';
import '../../domain/entities/articulo.dart';
import '../../domain/repositories/configuracion_repository.dart';

abstract class ArticuloRemoteDataSource {
  Future<Articulo> getArticulo(String codigo);
  Future<List<Articulo>> getArticulos();
  Future<void> updateArticulo(
    String codigo,
    String descripcion,
    int cantidadMinima,
    String referencia,
    String? lote,
    bool descatalogado, 
    bool gestionLotes,
  );
}

class ArticuloRemoteDataSourceImpl implements ArticuloRemoteDataSource {
  final http.Client client;
  final ConfiguracionRepository configRepository;

  ArticuloRemoteDataSourceImpl({
    required this.client,
    required this.configRepository,
  });

  Future<String> _buildUrl(String path) async {
    final config = await configRepository.getConfiguracion();
    final urlBase = config.urlBase;

    if (urlBase.isEmpty) {
      throw ServerException('URL base no configurada.');
    }

    final sanitizedUrlBase = urlBase.endsWith('/') 
        ? urlBase.substring(0, urlBase.length - 1) 
        : urlBase;

    return '$sanitizedUrlBase/$path';
  }

  @override
  Future<Articulo> getArticulo(String codigo) async {
    final url = await _buildUrl('articulo/GetCodigos');
    final uri = Uri.parse('$url?Filtro=CodigoBarras=\'$codigo\'');

    try {
      final response = await client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> jsonList = json.decode(responseBody);
        
        if (jsonList.isEmpty) {
          throw NotFoundException(
            'Artículo no encontrado con el código: $codigo',
          );
        }

        return Articulo.fromJson(jsonList.first as Map<String, dynamic>);
      } else {
        throw ServerException(
          'Error al buscar artículo: ${response.statusCode}',
        );
      }
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException('Fallo de conexión o parseo: ${e.toString()}');
    }
  }

  @override
  Future<List<Articulo>> getArticulos() async {
    final url = await _buildUrl('articulo/GetCodigos');
    final uri = Uri.parse(url);

    debugPrint('🌐 [REMOTE_DS] Conectando a: $uri');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(minutes: 5));

      debugPrint('📥 [REMOTE_DS] HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String decoded = utf8.decode(response.bodyBytes);
        
        // Validar que no sea HTML 
        if (decoded.trim().startsWith('<')) {
          debugPrint('❌ [REMOTE_DS] Respuesta es HTML, no JSON');
          throw ServerException('El servidor devolvió HTML en lugar de JSON');
        }

        final dynamic jsonData = json.decode(decoded);
        
        if (jsonData is! List) {
          debugPrint('⚠️ [REMOTE_DS] JSON no es lista. Tipo: ${jsonData.runtimeType}');
          throw ServerException('Formato de respuesta inválido');
        }

        debugPrint('📦 [REMOTE_DS] Lista recibida con ${jsonData.length} elementos');

        // Mapeo síncrono (NO usar compute en Release)
        final List<Articulo> articulos = [];
        int errores = 0;

        for (int i = 0; i < jsonData.length; i++) {
          try {
            final articulo = Articulo.fromJson(jsonData[i] as Map<String, dynamic>);
            articulos.add(articulo);
            
            // Log cada 1000 artículos
            if ((i + 1) % 1000 == 0) {
              debugPrint('📦 [REMOTE_DS] Procesados ${i + 1}/${jsonData.length}');
            }
          } catch (e) {
            errores++;
            if (kDebugMode && errores <= 10) {
              debugPrint('⚠️ [REMOTE_DS] Error en artículo ${i + 1}: $e');
              debugPrint('   Datos: ${jsonData[i]}');
            }
          }
        }

        debugPrint('✅ [REMOTE_DS] Parseo completo:');
        debugPrint('   - Exitosos: ${articulos.length}');
        debugPrint('   - Errores: $errores');

        if (articulos.isEmpty && jsonData.isNotEmpty) {
          throw ServerException('Todos los artículos fallaron al parsear');
        }

        return articulos;

      } else {
        final body = response.body.length > 200 
            ? response.body.substring(0, 200) 
            : response.body;
        debugPrint('❌ [REMOTE_DS] Error ${response.statusCode}: $body');
        throw ServerException('Error de servidor: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('❌ [REMOTE_DS] Error fatal: $e');
      if (kDebugMode) debugPrint('Stack: $stack');
      
      if (e is ServerException) rethrow;
      throw ServerException('Fallo de conexión: $e');
    }
  }

  @override
  Future<void> updateArticulo(
    String codigo,
    String descripcion,
    int cantidadMinima,
    String referencia,
    String? lote,
    bool descatalogado,
    bool gestionLotes,
  ) async {
    final url = await _buildUrl('articulo/guardar');

    final Map<String, dynamic> body = {
      'CodigoBarras': codigo,
      'Descripcion': descripcion,
      'CantidadMinima': cantidadMinima,
      'Referencia': referencia,
      'Lote': lote,
      'Descatalogado': descatalogado ? 1 : 0, 
      'GestionLotes': gestionLotes ? 1 : 0,
    };

    try {
      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Fallo al actualizar artículo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw ServerException(
        'Fallo de conexión al actualizar: ${e.toString()}',
      );
    }
  }
}