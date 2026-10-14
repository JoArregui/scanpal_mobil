import '../entities/lectura.dart';
import '../entities/tipo_operacion.dart';

abstract class LecturaRepository {
  /// Guarda el registro localmente 
  Future<void> registrarLectura(Lectura lectura); 
  
  /// Obtiene los registros guardados localmente y no enviados filtrados por tipo
  Future<List<Lectura>> obtenerLecturasPendientes(TipoOperacion tipo);

  /// Obtiene lecturas filtradas por un día específico (Historial)
  Future<List<Lectura>> obtenerLecturasPorFecha(DateTime fecha);
  
  /// Envía la lista de registros a la API remota 
  Future<void> enviarLecturas(List<Lectura> lecturas);
  
  /// Borra todas las lecturas locales (con limpieza automática de 90 días)
  Future<void> borrarLecturas();
  
  /// Actualiza el estado de sincronización de un registro a true
  Future<void> marcarLecturaComoSincronizada(String codigoArticulo, DateTime fechaRegistro);
  
  /// Marca múltiples lecturas como sincronizadas
  Future<void> marcarLecturasComoSincronizadas(List<Lectura> lecturas);

  /// Para la edición de una lectura específica
  Future<void> actualizarLectura(Lectura lectura);

  /// Borra un registro de lectura local específico por su ID
  Future<void> borrarLecturaPorId(int id);
}