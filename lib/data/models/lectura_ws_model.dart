import '../../../domain/entities/lectura.dart';

class LecturaWSModel {
  final String codigoBarras;
  final int referencia;
  final double cantidad;
  final int usuario;
  final String? lote;
  final DateTime fecha;
  final DateTime? fechaCaducidad;
  final double? pesoNeto;
  final double? pesoBruto;
  final String? sscc;

  LecturaWSModel({
    required this.codigoBarras,
    required this.referencia,
    required this.cantidad,
    required this.usuario,
    this.lote,
    required this.fecha,
    this.fechaCaducidad,
    this.pesoNeto,
    this.pesoBruto,
    this.sscc,
  });

  factory LecturaWSModel.fromEntity(Lectura lectura) {
    // Limpieza de caracteres
    String refBruta = lectura.referenciaArticulo.replaceAll(RegExp(r'\u00a0'), ' ').trim();
    String codLimpio = lectura.codigoArticulo.replaceAll(RegExp(r'\u00a0'), ' ').trim();
    
    String parteReferencia = refBruta;
    String? parteLote = lectura.lote;

    // Lógica separador "/" (Viveros Navas)
    if (refBruta.contains('/')) {
      List<String> partes = refBruta.split('/');
      parteReferencia = partes[0].trim();
      parteLote ??= partes.length > 1 ? partes.sublist(1).join('/').trim() : null;
    }

    final int refInt = int.tryParse(parteReferencia.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    return LecturaWSModel(
      codigoBarras: codLimpio,
      referencia: refInt,
      cantidad: lectura.cantidad,
      usuario: lectura.idUsuario,
      lote: parteLote,
      fecha: lectura.fechaEnvio ?? DateTime.now(),
      fechaCaducidad: lectura.fechaCaducidad,
      pesoNeto: lectura.pesoNeto,
      pesoBruto: lectura.pesoBruto,
      sscc: lectura.sscc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Referencia": referencia,
      "CodigoBarras": codigoBarras,
      "Cantidad": cantidad == cantidad.truncateToDouble()
          ? cantidad.toInt()
          : cantidad,
      "Usuario": usuario,
      "Lote": lote ?? "",
      "FechaEnvio": "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}",
      "FechaCaducidad": fechaCaducidad != null
          ? "${fechaCaducidad!.year}-${fechaCaducidad!.month.toString().padLeft(2, '0')}-${fechaCaducidad!.day.toString().padLeft(2, '0')}"
          : "",
      "PesoNeto": pesoNeto,
      "PesoBruto": pesoBruto,
      "SSCC": sscc ?? "",
    };
  }
}
