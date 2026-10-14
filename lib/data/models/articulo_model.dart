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
    // 1. Obtención segura del código principal
    final String fullCodigo = (json['CodigoBarras'] ?? json['Codigo'] ?? '')
        .toString();

    // 2. Lógica de separación de referencia/lote por '/'
    String refPart = fullCodigo;
    String? lotePart;

    if (fullCodigo.contains('/')) {
      List<String> parts = fullCodigo.split('/');
      refPart = parts[0];
      lotePart = parts.sublist(1).join('/');
    }

    // 3. Parseo robusto de booleanos (maneja bool, int 0/1 y String "true"/"false")
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

    // 4. Parseo robusto de enteros para cantidad mínima
    int parseCantMin(dynamic value) {
      if (value == null) return 1;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 1;
      return 1;
    }

    return ArticuloModel(
      codigo: fullCodigo,
      // Usamos .toString() y un fallback para evitar errores de tipo si viene nulo
      descripcion: (json['Descripcion'] ?? json['Nombre'] ?? 'SIN DESCRIPCIÓN')
          .toString(),
      referencia: refPart,
      lote: lotePart,
      cantidadMinima: parseCantMin(
        json['StockMinimo'] ?? json['CantidadMinima'],
      ),
      descatalogado: parseBool(json['Descatalogado']),
      gestionLotes: parseBool(json['GestionLotes']),
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
