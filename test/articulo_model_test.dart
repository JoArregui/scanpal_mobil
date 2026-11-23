import 'package:flutter_test/flutter_test.dart';
import 'package:scanpalphone_app/data/models/articulo_model.dart';

void main() {
  group('ArticuloModel.fromJson', () {
    test('maps camelCase API fields', () {
      final articulo = ArticuloModel.fromJson({
        'codigoBarras': '8412345678901',
        'descripcion': 'Artículo de prueba',
        'referencia': 'REF-123',
        'cantidadMinima': 4,
        'descatalogado': false,
        'gestionLotes': true,
      });

      expect(articulo.codigo, '8412345678901');
      expect(articulo.descripcion, 'Artículo de prueba');
      expect(articulo.referencia, 'REF-123');
      expect(articulo.cantidadMinima, 4);
      expect(articulo.descatalogado, isFalse);
      expect(articulo.gestionLotes, isTrue);
    });

    test('continues to map PascalCase API fields', () {
      final articulo = ArticuloModel.fromJson({
        'CodigoBarras': '8412345678901',
        'Descripcion': 'Artículo de prueba',
        'Referencia': 123,
        'CantidadMinima': 2,
        'Descatalogado': 0,
        'GestionLotes': 1,
      });

      expect(articulo.codigo, '8412345678901');
      expect(articulo.descripcion, 'Artículo de prueba');
      expect(articulo.referencia, '123');
      expect(articulo.cantidadMinima, 2);
      expect(articulo.descatalogado, isFalse);
      expect(articulo.gestionLotes, isTrue);
    });

    test('rejects records without an article code', () {
      expect(
        () => ArticuloModel.fromJson({'descripcion': 'Sin código'}),
        throwsFormatException,
      );
    });
  });
}
