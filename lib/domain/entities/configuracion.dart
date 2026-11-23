import '../../core/constants.dart';

class Configuracion {
  final String urlBase;
  final int cantidadMinima;
  final bool lecturaAutomatica;
  final bool gestionLotes;
  final int intervaloLecturaAutomaticaSegundos;

  Configuracion({
    required this.urlBase,
    required this.cantidadMinima,
    required this.lecturaAutomatica,
    this.gestionLotes = false,
    this.intervaloLecturaAutomaticaSegundos = 3,
  });

  Configuracion.inicial()
    : urlBase = AppConstants.baseUrl,
      cantidadMinima = 1,
      lecturaAutomatica = false,
      gestionLotes = false,
      intervaloLecturaAutomaticaSegundos = 3;

  factory Configuracion.fromJson(Map<String, dynamic> json) {
    final String urlRaw = json['urlBase'] as String? ?? AppConstants.baseUrl;
    final String urlLimpia = urlRaw.replaceAll(RegExp(r'\u00a0'), ' ').trim();

    return Configuracion(
      urlBase: urlLimpia,
      cantidadMinima: (json['cantidadMinima'] as num?)?.toInt() ?? 0,
      lecturaAutomatica: json['lecturaAutomatica'] as bool? ?? false,
      gestionLotes: _parseBool(json['gestionLotes']),
      intervaloLecturaAutomaticaSegundos:
          (json['intervaloLecturaAutomaticaSegundos'] as num?)?.toInt() ?? 3,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'urlBase': urlBase,
      'cantidadMinima': cantidadMinima,
      'lecturaAutomatica': lecturaAutomatica,
      'gestionLotes': gestionLotes,
      'intervaloLecturaAutomaticaSegundos':
          intervaloLecturaAutomaticaSegundos,
    };
  }
}
