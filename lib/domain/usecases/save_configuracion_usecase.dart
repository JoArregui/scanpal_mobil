import '../entities/configuracion.dart';
import '../repositories/configuracion_repository.dart';

class SaveConfiguracionUseCase {
  final ConfiguracionRepository repository;

  SaveConfiguracionUseCase(this.repository);

  Future<void> execute(Configuracion config) async {
   
    if (config.urlBase.isEmpty || config.cantidadMinima < 0) {
      throw Exception("La URL no puede estar vacía.");
    }

    return await repository.guardarConfiguracion(config);
  }
}