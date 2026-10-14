import 'articulo.dart';

class ArticuloDuplicado {
  final int? id; // ID autoincremental para SQLite
  final Articulo articulo;
  final String motivo;
  final DateTime fechaDeteccion;

  ArticuloDuplicado({
    this.id,
    required this.articulo,
    required this.motivo,
    required this.fechaDeteccion,
  });
}