import '../../core/constants.dart';

class Configuracion {
  final String urlBase;
  final int cantidadMinima;
  final bool lecturaAutomatica;

  Configuracion({
    required this.urlBase,
    required this.cantidadMinima,
    required this.lecturaAutomatica,
  });


  Configuracion.inicial()
      : urlBase = AppConstants.baseUrl,
        cantidadMinima = 1,
        lecturaAutomatica = false;

  factory Configuracion.fromJson(Map<String, dynamic> json) {

    final String urlRaw = json['urlBase'] as String? ?? AppConstants.baseUrl;
    final String urlLimpia = urlRaw.replaceAll(RegExp(r'\u00a0'), ' ').trim();

    return Configuracion(
      urlBase: urlLimpia,
      cantidadMinima: (json['cantidadMinima'] as num?)?.toInt() ?? 0,
      lecturaAutomatica: json['lecturaAutomatica'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'urlBase': urlBase,
      'cantidadMinima': cantidadMinima,
      'lecturaAutomatica': lecturaAutomatica,
    };
  }
}