import '../entities/configuracion.dart';

abstract class ConfiguracionRepository {
  Future<Configuracion> getConfiguracion();

  Future<void> guardarConfiguracion(Configuracion config);
}
