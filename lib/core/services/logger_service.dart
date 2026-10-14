import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../database_helper.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // Usamos la instancia Singleton de DatabaseHelper
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  File? _logFile;

  /// Registra un evento en Base de Datos y en Archivo de Texto
  Future<void> log(String message, {String level = 'INFO', int? paquete}) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    
    // 1. Guardar en SQLite (Usando las constantes de DatabaseHelper)
    try {
      final db = await _dbHelper.database;
      await db.insert(DatabaseHelper.tableNameLogs, {
        DatabaseHelper.colLogTimestamp: timestamp,
        DatabaseHelper.colLogLevel: level,
        DatabaseHelper.colLogMessage: message,
        DatabaseHelper.colLogPaquete: paquete,
      });
    } catch (e) {
      // Evitamos bucles infinitos si falla la base de datos
      print('Error local en Logger (DB): $e');
    }

    // 2. Guardar en archivo de texto (Para exportación rápida)
    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/sync_logs.txt');
      }
      final logLine = '[$timestamp] [$level] ${paquete != null ? "Pkg $paquete: " : ""}$message\n';
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      print('Error local en Logger (Archivo): $e');
    }
  }

  /// Recupera los últimos logs de la base de datos usando las constantes
  Future<List<Map<String, dynamic>>> getDbLogs({int limit = 100}) async {
    final db = await _dbHelper.database;
    return await db.query(
      DatabaseHelper.tableNameLogs, 
      orderBy: '${DatabaseHelper.colLogId} DESC', 
      limit: limit
    );
  }

  /// Limpia el historial de logs en ambos sitios
  Future<void> clearLogs() async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableNameLogs);
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  /// Devuelve el archivo físico de logs para compartirlo
  Future<File?> getLogFile() async {
    if (_logFile == null) {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/sync_logs.txt');
    }
    return (await _logFile!.exists()) ? _logFile : null;
  }
}