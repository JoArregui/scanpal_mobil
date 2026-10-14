import '../entities/configuracion.dart';
import '../repositories/configuracion_repository.dart';

class GetConfiguracionUseCase {
  final ConfiguracionRepository repository;

  GetConfiguracionUseCase(this.repository);

  Future<Configuracion> execute() async {
    return await repository.getConfiguracion();
  }
}
