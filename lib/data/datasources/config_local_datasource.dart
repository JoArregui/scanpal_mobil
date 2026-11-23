import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../domain/entities/configuracion.dart';

const String _kUrlBase = 'urlBaseKey';
const String _kCantidadMinima = 'cantidadMinimaKey';
const String _kLecturaAutomatica = 'lecturaAutomaticaKey';
const String _kGestionLotes = 'gestionLotesKey';
const String _kIntervaloLecturaAutomatica =
    'intervaloLecturaAutomaticaSegundosKey';

abstract class ConfigLocalDataSource {
  Future<Configuracion> fetchConfiguracion();
  Future<void> saveConfiguracion(Configuracion config);
}

class ConfigLocalDataSourceImpl implements ConfigLocalDataSource {
  final SharedPreferences sharedPreferences;

  ConfigLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<Configuracion> fetchConfiguracion() async {
    var urlBase =
        sharedPreferences.getString(_kUrlBase) ??
        Configuracion.inicial().urlBase;
    final normalizedUrlBase = urlBase.trim().replaceFirst(RegExp(r'/+$'), '');

    if (normalizedUrlBase == 'https://localhost:7251') {
      urlBase = AppConstants.baseUrl;
      await sharedPreferences.setString(_kUrlBase, urlBase);
    }

    final cantidadMinima =
        sharedPreferences.getInt(_kCantidadMinima) ??
        Configuracion.inicial().cantidadMinima;
    final lecturaAutomatica =
        sharedPreferences.getBool(_kLecturaAutomatica) ??
        Configuracion.inicial().lecturaAutomatica;
    final gestionLotes =
        sharedPreferences.getBool(_kGestionLotes) ??
        Configuracion.inicial().gestionLotes;
    final intervaloLecturaAutomaticaSegundos =
        sharedPreferences.getInt(_kIntervaloLecturaAutomatica) ??
        Configuracion.inicial().intervaloLecturaAutomaticaSegundos;

    return Configuracion(
      urlBase: urlBase,
      cantidadMinima: cantidadMinima,
      lecturaAutomatica: lecturaAutomatica,
      gestionLotes: gestionLotes,
      intervaloLecturaAutomaticaSegundos: intervaloLecturaAutomaticaSegundos,
    );
  }

  @override
  Future<void> saveConfiguracion(Configuracion config) async {
    await sharedPreferences.setString(_kUrlBase, config.urlBase);
    await sharedPreferences.setInt(_kCantidadMinima, config.cantidadMinima);
    await sharedPreferences.setBool(
      _kLecturaAutomatica,
      config.lecturaAutomatica,
    );
    await sharedPreferences.setBool(_kGestionLotes, config.gestionLotes);
    await sharedPreferences.setInt(
      _kIntervaloLecturaAutomatica,
      config.intervaloLecturaAutomaticaSegundos,
    );
  }
}
