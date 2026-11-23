// ignore_for_file: avoid_print
import '../../domain/entities/articulo.dart';

class ArticuloModel extends Articulo {
  ArticuloModel({
    required super.codigo,
    required super.descripcion,
    required super.referencia,
    super.lote,
    required super.cantidadMinima,
    required super.descatalogado,
    required super.gestionLotes,
  });

  factory ArticuloModel.fromJson(Map<String, dynamic> json) {
    final normalizedJson = {
      for (final entry in json.entries)
        entry.key.toLowerCase(): entry.value,
    };

    dynamic valueFor(List<String> keys) {
      for (final key in keys) {
        final value = normalizedJson[key.toLowerCase()];
        if (value != null) return value;
      }
      return null;
    }

    final fullCodigo =
        valueFor(['CodigoBarras', 'Codigo', 'CodigoArticulo'])
            ?.toString()
            .trim() ??
        '';
    if (fullCodigo.isEmpty) {
      throw const FormatException('El artículo no contiene un código.');
    }

    String refPart = fullCodigo;
    String? lotePart;

    if (fullCodigo.contains('/')) {
      final parts = fullCodigo.split('/');
      refPart = parts[0];
      lotePart = parts.sublist(1).join('/');
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value == 1;
      if (value is String) {
        final lower = value.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    int parseCantMin(dynamic value) {
      if (value == null) return 1;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 1;
      return 1;
    }

    final referencia = valueFor(['Referencia', 'Ref'])?.toString() ?? refPart;
    final lote = valueFor(['Lote'])?.toString() ?? lotePart;

    return ArticuloModel(
      codigo: fullCodigo,
      descripcion:
          valueFor(['Descripcion', 'Nombre'])?.toString() ??
          'SIN DESCRIPCIÓN',
      referencia: referencia,
      lote: lote,
      cantidadMinima: parseCantMin(
        valueFor(['StockMinimo', 'CantidadMinima']),
      ),
      descatalogado: parseBool(valueFor(['Descatalogado'])),
      gestionLotes: parseBool(valueFor(['GestionLotes'])),
    );
  }

  Articulo toEntity() => this;

  static List<Articulo> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) {
          try {
            return ArticuloModel.fromJson(
              json as Map<String, dynamic>,
            ).toEntity();
          } catch (e) {
            // Si un registro falla, lo logueamos pero permitimos que los demás continúen
            print('ERROR parseando artículo individual: $e - JSON: $json');
            return null;
          }
        })
        .whereType<Articulo>()
        .toList();
  }
}
