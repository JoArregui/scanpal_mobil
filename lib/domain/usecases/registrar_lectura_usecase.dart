import '../entities/lectura.dart';
import '../entities/tipo_operacion.dart';
import '../repositories/lectura_repository.dart';

class RegistrarLecturaUseCase {
  final LecturaRepository repository;

  RegistrarLecturaUseCase(this.repository);

  Future<void> execute({
    required String codigo,
    required String referencia,
    required double cantidad,
    required int idUsuario,
    String? lote,
    bool esDescatalogado = false,
    String? descripcion,
    TipoOperacion tipoOperacion = TipoOperacion.inventario,
    DateTime? fechaCaducidad,
    double? pesoNeto,
    double? pesoBruto,
    String? sscc,
  }) async {
    if (cantidad <= 0) {
      throw Exception("La cantidad debe ser mayor que cero.");
    }

    final String cleanCodigo = _limpiarTexto(codigo);
    final String cleanReferencia = _limpiarTexto(referencia);
    final String? cleanLote = (lote != null && lote.isNotEmpty) ? _limpiarTexto(lote) : null;

    String? finalDescripcion = (descripcion != null && descripcion.isNotEmpty)
        ? _limpiarTexto(descripcion)
        : null;

    if (finalDescripcion == null || finalDescripcion == cleanCodigo) {
      finalDescripcion = cleanReferencia;
    }

    final lectura = Lectura(
      codigoArticulo: cleanCodigo,
      referenciaArticulo: cleanReferencia,
      cantidad: cantidad,
      fechaRegistro: DateTime.now(),
      idUsuario: idUsuario,
      lote: cleanLote,
      sincronizado: false,
      esDescatalogado: esDescatalogado,
      descripcion: finalDescripcion,
      tipoOperacion: tipoOperacion,
      fechaCaducidad: fechaCaducidad,
      pesoNeto: pesoNeto,
      pesoBruto: pesoBruto,
      sscc: (sscc != null && sscc.isNotEmpty) ? _limpiarTexto(sscc) : null,
    );

    return await repository.registrarLectura(lectura);
  }

  String _limpiarTexto(String texto) {
    return texto.replaceAll(String.fromCharCode(160), ' ').trim();
  }
}