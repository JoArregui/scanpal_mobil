import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
class Articulo {
  final String codigo;
  final String descripcion;
  final String referencia;
  final String? lote;
  final int cantidadMinima;
  final bool descatalogado;
  final bool gestionLotes;

  @pragma('vm:entry-point')
  const Articulo({
    required this.codigo,
    required this.descripcion,
    required this.referencia,
    this.lote,
    required this.cantidadMinima,
    required this.descatalogado,
    required this.gestionLotes,
  });

  @pragma('vm:entry-point')
  factory Articulo.fromJson(Map<String, dynamic> json) {
    try {
      // Manejo robusto de campos que pueden venir como int o String
      String codigoStr = json['CodigoBarras']?.toString() ?? '';
      String referenciaStr = json['Referencia']?.toString() ?? '';

      // Limpieza de referencia si viene como decimal
      if (referenciaStr.contains('.')) {
        referenciaStr = referenciaStr.split('.').first;
      }

      int cantidadMin = 0;
      if (json['CantidadMinima'] != null) {
        if (json['CantidadMinima'] is int) {
          cantidadMin = json['CantidadMinima'];
        } else if (json['CantidadMinima'] is String) {
          cantidadMin = int.tryParse(json['CantidadMinima']) ?? 0;
        } else if (json['CantidadMinima'] is double) {
          cantidadMin = (json['CantidadMinima'] as double).toInt();
        }
      }

      // Manejo de booleanos que pueden venir como int (0/1) o bool
      bool descatalogadoBool = false;
      if (json['Descatalogado'] != null) {
        if (json['Descatalogado'] is bool) {
          descatalogadoBool = json['Descatalogado'];
        } else if (json['Descatalogado'] is int) {
          descatalogadoBool = json['Descatalogado'] == 1;
        } else if (json['Descatalogado'] is String) {
          descatalogadoBool =
              json['Descatalogado'] == '1' ||
              json['Descatalogado'].toLowerCase() == 'true';
        }
      }

      bool gestionLotesBool = false;
      if (json['GestionLotes'] != null) {
        if (json['GestionLotes'] is bool) {
          gestionLotesBool = json['GestionLotes'];
        } else if (json['GestionLotes'] is int) {
          gestionLotesBool = json['GestionLotes'] == 1;
        } else if (json['GestionLotes'] is String) {
          gestionLotesBool =
              json['GestionLotes'] == '1' ||
              json['GestionLotes'].toLowerCase() == 'true';
        }
      }

      return Articulo(
        codigo: codigoStr,
        descripcion: json['Descripcion']?.toString() ?? '',
        referencia: referenciaStr,
        lote: json['Lote']?.toString(),
        cantidadMinima: cantidadMin,
        descatalogado: descatalogadoBool,
        gestionLotes: gestionLotesBool,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ Error parseando Articulo: $e');
        debugPrint('JSON recibido: $json');
        debugPrint('Stack: $stack');
      }
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  Map<String, dynamic> toJson() {
    return {
      'CodigoBarras': codigo,
      'Descripcion': descripcion,
      'Referencia': referencia,
      'Lote': lote,
      'CantidadMinima': cantidadMinima,
      'Descatalogado': descatalogado ? 1 : 0,
      'GestionLotes': gestionLotes ? 1 : 0,
    };
  }

  @override
  String toString() {
    return 'Articulo(codigo: $codigo, desc: $descripcion, ref: $referencia)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Articulo && other.codigo == codigo;
  }

  @override
  int get hashCode => codigo.hashCode;

  // Método copyWith para crear copias con modificaciones
  @pragma('vm:entry-point')
  Articulo copyWith({
    String? codigo,
    String? descripcion,
    String? referencia,
    String? lote,
    int? cantidadMinima,
    bool? descatalogado,
    bool? gestionLotes,
  }) {
    return Articulo(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      referencia: referencia ?? this.referencia,
      lote: lote ?? this.lote,
      cantidadMinima: cantidadMinima ?? this.cantidadMinima,
      descatalogado: descatalogado ?? this.descatalogado,
      gestionLotes: gestionLotes ?? this.gestionLotes,
    );
  }
}
