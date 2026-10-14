import '../../domain/entities/configuracion.dart';
import '../../domain/repositories/configuracion_repository.dart';
import '../datasources/config_local_datasource.dart';

class ConfiguracionRepositoryImpl implements ConfiguracionRepository {
  final ConfigLocalDataSource localDataSource;

  ConfiguracionRepositoryImpl({required this.localDataSource});

  @override
  Future<Configuracion> getConfiguracion() {
    return localDataSource.fetchConfiguracion();
  }

  @override
  Future<void> guardarConfiguracion(Configuracion config) {
    return localDataSource.saveConfiguracion(config);
  }
}
