import '../../domain/entities/lectura.dart';

class LecturaViewModel {
  final Lectura lectura;
  final String descripcionArticulo;

  LecturaViewModel({required this.lectura, required this.descripcionArticulo});

  String get codigo =>
      lectura.codigoArticulo.replaceAll(String.fromCharCode(160), ' ').trim();

  String get referencia => lectura.referenciaArticulo
      .replaceAll(String.fromCharCode(160), ' ')
      .trim();

  double get cantidad => lectura.cantidad;

  /// Obtiene el lote limpio. Si es nulo o vacío, devuelve null.
  String? get lote =>
      lectura.lote?.replaceAll(String.fromCharCode(160), ' ').trim();

  /// Indica si el artículo está marcado como descatalogado.
  bool get esDescatalogado => lectura.esDescatalogado;

  String get descripcionLimpia {
    String desc = descripcionArticulo
        .replaceAll(String.fromCharCode(160), ' ')
        .trim();
    String cod = codigo;

    if (cod.isNotEmpty) {
      desc = desc.replaceAll(cod, '').trim();
    }

    desc = desc.replaceFirst(RegExp(r'^[.\-:/]+'), '').trim();

    return desc.isEmpty ? referencia : desc;
  }
}
