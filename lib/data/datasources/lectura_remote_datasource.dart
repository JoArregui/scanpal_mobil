import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/exceptions.dart';
import '../../core/constants.dart';
import '../../core/services/logger_service.dart';
import '../../../domain/entities/lectura.dart';
import '../../../domain/entities/tipo_operacion.dart';
import '../../../domain/repositories/configuracion_repository.dart';

abstract class LecturaRemoteDataSource {
  Future<void> sendLecturas(List<Lectura> lecturas);
}

class LecturaRemoteDataSourceImpl implements LecturaRemoteDataSource {
  final http.Client client;
  final ConfiguracionRepository configRepository;
  final LoggerService _logger = LoggerService();

  LecturaRemoteDataSourceImpl({
    required this.client,
    required this.configRepository,
  });


  String _limpiarTexto(String texto) {
    return texto.replaceAll(String.fromCharCode(160), ' ').trim();
  }

  /// Formatea la fecha con hora para el Servidor (YYYY-MM-DD HH:mm:ss)
  String _formatearFecha(DateTime fecha) {
  return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')} "
         "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}:${fecha.second.toString().padLeft(2, '0')}";
}

  Future<String> _buildUrl(String path) async {
    final config = await configRepository.getConfiguracion();
    if (config.urlBase.isEmpty) {
      throw const ServerException('URL base no configurada.');
    }

    final urlBase = config.urlBase.endsWith('/')
        ? config.urlBase.substring(0, config.urlBase.length - 1)
        : config.urlBase;

    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$urlBase/$cleanPath';
  }

  @override
  Future<void> sendLecturas(List<Lectura> lecturas) async {
    if (lecturas.isEmpty) return;

    final url = await _buildUrl('Lectura/Guardar');
    // Esta fecha es la que marcará el historial de seguridad local
    final DateTime ahora = DateTime.now();

    await _logger.log(
      'Iniciando envío de ${lecturas.length} lecturas a $url',
      level: 'START',
    );

    for (var i = 0; i < lecturas.length; i += AppConstants.batchSize) {
      final end = (i + AppConstants.batchSize < lecturas.length)
          ? i + AppConstants.batchSize
          : lecturas.length;

      final List<Lectura> chunk = lecturas.sublist(i, end);
      final int nPaquete = (i ~/ AppConstants.batchSize) + 1;

      final List<Map<String, dynamic>> listaPayload = chunk.map((lectura) {
        String refOriginal = _limpiarTexto(lectura.referenciaArticulo);
        String parteReferencia = refOriginal;
        String? parteLote = lectura.lote != null
            ? _limpiarTexto(lectura.lote!)
            : null;

        // Lógica de separación de referencia/lote por "/"
        if (refOriginal.contains('/')) {
          final partes = refOriginal.split('/');
          parteReferencia = partes[0].trim();
          if (parteLote == null || parteLote.isEmpty) {
            parteLote = partes.sublist(1).join('/').trim();
          }
        }

        final soloNumerosRef = parteReferencia.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

        // Mapeo del tipo (I=Inventario, C=Compra, V=Venta)
        String tipoWS = "I";
        switch (lectura.tipoOperacion) {
          case TipoOperacion.inventario:
            tipoWS = "I";
            break;
          case TipoOperacion.compra:
            tipoWS = "C";
            break;
          case TipoOperacion.venta:
            tipoWS = "V";
            break;
        }

        return {
          "Referencia": int.tryParse(soloNumerosRef) ?? 0,
          "CodigoBarras": _limpiarTexto(lectura.codigoArticulo),
          "Cantidad": lectura.cantidad.toInt(),
          "Usuario": lectura.idUsuario, 
          "Lote": parteLote ?? "",
          "FechaEnvio": _formatearFecha(ahora),
          "Tipo": tipoWS,
        };
      }).toList();

      final String jsonBody = jsonEncode(listaPayload);

      // Log técnico para validar el ID de usuario antes de la petición
      if (kDebugMode) {
        print('🚀 [API_SEND] Paquete $nPaquete (Usuario ${listaPayload[0]['Usuario']}): $jsonBody');
      }

      bool success = false;
      int attempts = 0;

      while (!success && attempts < AppConstants.maxRetries) {
        attempts++;
        try {
          final response = await client.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json', 
              'Accept': 'application/json'
            },
            body: jsonBody,
          ).timeout(const Duration(seconds: AppConstants.apiTimeoutSeconds));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final jsonResponse = jsonDecode(response.body);
            final int recibidas = int.tryParse(jsonResponse['LecturasRecibidas']?.toString() ?? '0') ?? 0;

            if (recibidas != listaPayload.length) {
             
              throw ServerException(
                recibidas == 0 
                ? 'El Servidor rechazó los datos (Recibidas: 0). Verifique si el Usuario ${listaPayload[0]['Usuario']} tiene permisos en el Servidor.'
                : 'Desfase: Enviadas ${listaPayload.length}, Servidor recibió $recibidas.'
              );
            }

            success = true;
            await _logger.log(
              'Paquete $nPaquete enviado correctamente',
              level: 'SUCCESS',
              paquete: nPaquete,
            );
          } else {
            throw ServerException('Servidor respondió error ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          await _logger.log(
            'Fallo en intento $attempts: $e',
            level: 'WARNING',
            paquete: nPaquete,
          );
          if (attempts >= AppConstants.maxRetries) {
            await _logger.log(
              'Sincronización abortada por errores persistentes',
              level: 'CRITICAL',
              paquete: nPaquete,
            );
            rethrow;
          }
          await Future.delayed(
            const Duration(seconds: AppConstants.retryDelaySeconds),
          );
        }
      }
    }
    await _logger.log(
      'Proceso de sincronización finalizado íntegramente',
      level: 'END',
    );
  }
}
