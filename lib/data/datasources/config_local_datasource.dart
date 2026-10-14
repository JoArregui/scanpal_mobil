import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/configuracion.dart';

const String _kUrlBase = 'urlBaseKey';
const String _kCantidadMinima = 'cantidadMinimaKey';
const String _kLecturaAutomatica = 'lecturaAutomaticaKey'; 

abstract class ConfigLocalDataSource {
  Future<Configuracion> fetchConfiguracion();
  Future<void> saveConfiguracion(Configuracion config);
}

class ConfigLocalDataSourceImpl implements ConfigLocalDataSource {
  final SharedPreferences sharedPreferences;

  ConfigLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<Configuracion> fetchConfiguracion() async {
    final urlBase = sharedPreferences.getString(_kUrlBase) ?? Configuracion.inicial().urlBase;
    final cantidadMinima = sharedPreferences.getInt(_kCantidadMinima) ?? Configuracion.inicial().cantidadMinima;
    final lecturaAutomatica = sharedPreferences.getBool(_kLecturaAutomatica) ?? Configuracion.inicial().lecturaAutomatica;

    return Configuracion(
      urlBase: urlBase,
      cantidadMinima: cantidadMinima,
      lecturaAutomatica: lecturaAutomatica, 
    );
  }

  @override
  Future<void> saveConfiguracion(Configuracion config) async {
    await sharedPreferences.setString(_kUrlBase, config.urlBase);
    await sharedPreferences.setInt(_kCantidadMinima, config.cantidadMinima);
    await sharedPreferences.setBool(_kLecturaAutomatica, config.lecturaAutomatica);
  }
}