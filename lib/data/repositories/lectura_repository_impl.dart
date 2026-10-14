import '../../domain/entities/lectura.dart';
import '../../domain/entities/tipo_operacion.dart';
import '../../domain/repositories/lectura_repository.dart';
import '../../core/database_helper.dart';
import '../datasources/lectura_local_datasource.dart';
import '../datasources/lectura_remote_datasource.dart';
import 'package:flutter/foundation.dart';

class LecturaRepositoryImpl implements LecturaRepository {
  final LecturaLocalDataSource localDataSource;
  final LecturaRemoteDataSource remoteDataSource;

  LecturaRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<void> registrarLectura(Lectura lectura) {
    return localDataSource.saveLectura(lectura);
  }

  @override
  Future<List<Lectura>> obtenerLecturasPendientes(TipoOperacion tipo) {
    return localDataSource.getLecturasPendientesPorTipo(tipo);
  }

  @override
  Future<List<Lectura>> obtenerLecturasPorFecha(DateTime fecha) async {
    final db = await DatabaseHelper.instance.database;

    // Formato YYYY-MM-DD
    final String fechaStr =
        "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableNameLecturas,
      where: "date(${DatabaseHelper.colFecha}) = ?",
      whereArgs: [fechaStr],
      orderBy: '${DatabaseHelper.colFecha} DESC',
    );

    return List.generate(maps.length, (i) {
      return Lectura(
        id: maps[i][DatabaseHelper.colId] as int?,
        codigoArticulo: maps[i][DatabaseHelper.colCodigo] as String,
        referenciaArticulo: maps[i][DatabaseHelper.colReferencia] as String,
        cantidad: (maps[i][DatabaseHelper.colCantidad] as num).toDouble(),
        fechaRegistro:
            DateTime.parse(maps[i][DatabaseHelper.colFecha] as String),
        fechaEnvio: maps[i][DatabaseHelper.colFechaEnvio] != null
            ? DateTime.parse(maps[i][DatabaseHelper.colFechaEnvio] as String)
            : null,
        idUsuario: maps[i][DatabaseHelper.colIdUsuario] as int,
        sincronizado: maps[i][DatabaseHelper.colSincronizado] == 1,
        lote: maps[i][DatabaseHelper.colLote] as String?,
        esDescatalogado: maps[i][DatabaseHelper.colEsDescatalogado] == 1,
        descripcion: maps[i][DatabaseHelper.colDescripcion] as String?,
        tipoOperacion: TipoOperacion.values.firstWhere(
          (e) =>
              e.name == (maps[i][DatabaseHelper.colTipoOperacion] ?? 'inventario'),
          orElse: () => TipoOperacion.inventario,
        ),
      );
    });
  }

  @override
  Future<void> enviarLecturas(List<Lectura> lecturas) async {
    await remoteDataSource.sendLecturas(lecturas);
  }

  @override
  Future<void> borrarLecturas() async {
    try {
      // Primero realizamos la limpieza automática de registros de más de 90 días
      final count = await localDataSource.deleteOldLecturas(90);
      
      if (kDebugMode) {
        print('🧹 [REPO] Borrado automático: $count registros antiguos eliminados (+90 días).');
      }

      // Segundo, ejecutamos el borrado físico total solicitado por la lógica del Repository.
      // Si se desea que "Borrar Lecturas" actúe como limpieza general:
      await localDataSource.clearLecturas();
      
      if (kDebugMode) {
        print('✅ [REPO] Borrado manual completado.');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [REPO] Error en borrarLecturas: $e');
    }
  }

  @override
  Future<void> marcarLecturaComoSincronizada(
      String codigoArticulo, DateTime fechaRegistro) {
    return localDataSource.markLecturaAsSynced(codigoArticulo, fechaRegistro);
  }

  @override
  Future<void> marcarLecturasComoSincronizadas(List<Lectura> lecturas) async {
    await localDataSource.markLecturasAsSynced(lecturas);
  }

  @override
  Future<void> actualizarLectura(Lectura lectura) {
    return localDataSource.updateLectura(lectura);
  }

  @override
  Future<void> borrarLecturaPorId(int id) {
    return localDataSource.deleteLecturaById(id);
  }
}