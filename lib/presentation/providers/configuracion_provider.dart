import 'package:flutter/foundation.dart';
import '../../domain/entities/configuracion.dart';
import '../../domain/usecases/get_configuracion_usecase.dart';
import '../../domain/usecases/save_configuracion_usecase.dart';

enum ConfiguracionState { initial, loading, loaded, saving, success, error }

class ConfiguracionProvider with ChangeNotifier {
  final GetConfiguracionUseCase getConfiguracionUseCase;
  final SaveConfiguracionUseCase saveConfiguracionUseCase;

  ConfiguracionProvider({
    required this.getConfiguracionUseCase,
    required this.saveConfiguracionUseCase,
  });

  Configuracion _configuracion = Configuracion.inicial();
  ConfiguracionState _state = ConfiguracionState.initial;
  String _errorMessage = '';

  Configuracion get configuracion => _configuracion;
  ConfiguracionState get state => _state;
  String get errorMessage => _errorMessage;

  /// Carga la configuración desde el repositorio local (SharedPreferences/SecureStorage)
  Future<void> cargarConfiguracion() async {
    // Si ya estamos cargando, evitamos duplicar la petición
    if (_state == ConfiguracionState.loading) return;

    _state = ConfiguracionState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _configuracion = await getConfiguracionUseCase.execute();
      _state = ConfiguracionState.loaded;
    } catch (e) {
      _configuracion = Configuracion.inicial();
      _errorMessage = 'Error al cargar la configuración: $e';
      _state = ConfiguracionState.error;
    }
    notifyListeners();
  }

  /// Guarda la nueva configuración y actualiza el estado global
  Future<bool> guardarConfiguracion(
    String url, 
    int cantidad, 
    {required bool lecturaAutomatica}
  ) async {
    _state = ConfiguracionState.saving;
    _errorMessage = '';
    notifyListeners();

    final nuevaConfig = Configuracion(
      urlBase: url, 
      cantidadMinima: cantidad,
      lecturaAutomatica: lecturaAutomatica,
    );

    try {
      await saveConfiguracionUseCase.execute(nuevaConfig);

      _configuracion = nuevaConfig;
      _state = ConfiguracionState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar: ${e.toString()}';
      _state = ConfiguracionState.error;
      notifyListeners();
      return false;
    }
  }

  /// Limpia la URL base y resetea la configuración a los valores iniciales
  Future<void> clearBaseUrl() async {
    final configVacia = Configuracion.inicial();

    try {
      await saveConfiguracionUseCase.execute(configVacia);

      _configuracion = configVacia;
      _state = ConfiguracionState.initial;
      _errorMessage = '';

      notifyListeners();

      if (kDebugMode) {
        print(
          '✅ [ConfiguracionProvider] URL base limpiada a vacío. Estado: ${_configuracion.urlBase.isEmpty ? "Vacío" : "NO Vacío"}',
        );
      }
    } catch (e) {
      _errorMessage = 'Error al limpiar la configuración: $e';
      _state = ConfiguracionState.error;
      notifyListeners();
      if (kDebugMode) {
        print('⚠️ Error FATAL al limpiar la URL base: $e');
      }
    }
  }
}