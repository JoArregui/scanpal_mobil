import 'tipo_operacion.dart';

class Lectura {
  final int? id;
  final String codigoArticulo;
  final String referenciaArticulo;
  final double cantidad;
  final DateTime fechaRegistro;
  final DateTime? fechaEnvio;
  final int idUsuario;
  final bool sincronizado;
  final String? lote;
  final bool esDescatalogado;
  final String? descripcion;
  final TipoOperacion tipoOperacion;
  // Datos GS1-128 de la etiqueta leída (todos opcionales).
  final DateTime? fechaCaducidad;
  final double? pesoNeto;
  final double? pesoBruto;
  final String? sscc;

  Lectura({
    this.id,
    required this.codigoArticulo,
    required this.referenciaArticulo,
    required this.cantidad,
    required this.fechaRegistro,
    this.fechaEnvio,
    this.idUsuario = 0,
    this.sincronizado = false,
    this.lote,
    this.esDescatalogado = false,
    this.descripcion,
    this.tipoOperacion = TipoOperacion.inventario,
    this.fechaCaducidad,
    this.pesoNeto,
    this.pesoBruto,
    this.sscc,
  });

  // ================== MAP PARA SQLITE ==================
  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'codigo_articulo': _limpiarTexto(codigoArticulo) ?? '',
      'referencia_articulo': _limpiarTexto(referenciaArticulo) ?? '',
      'cantidad': cantidad.toDouble(),
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_envio': fechaEnvio?.toIso8601String(),
      'id_usuario': idUsuario,
      'sincronizado': sincronizado ? 1 : 0,
      'lote': _limpiarTexto(lote),
      'es_descatalogado': esDescatalogado ? 1 : 0,
      'descripcion': _limpiarTexto(descripcion),
      'tipo_operacion': tipoOperacion.name,
      'fecha_caducidad': fechaCaducidad?.toIso8601String(),
      'peso_neto': pesoNeto,
      'peso_bruto': pesoBruto,
      'sscc': _limpiarTexto(sscc),
    };
  }

  /// Formatea los datos específicamente para el envío al servidor.
  /// La cantidad viaja como INT cuando es entera (contrato histórico) y como
  /// DOUBLE con decimales cuando viene de un peso GS1 (310n/330n); antes se
  /// truncaba con toInt() y un peso de 0.035 kg llegaba como 0.
  Map<String, dynamic> toJson() {
    // 1. Extraemos solo los números de la referencia para asegurar un INT
    // Si la referencia es "REF/123", esto tomará "123"
    final String soloNumeros = (referenciaArticulo.contains('/'))
        ? referenciaArticulo.split('/')[0].replaceAll(RegExp(r'[^0-9]'), '')
        : referenciaArticulo.replaceAll(RegExp(r'[^0-9]'), '');

    return {
      // El Servidor espera un INT, no un DOUBLE ni STRING
      'Referencia': int.tryParse(soloNumeros) ?? 0,
      'CodigoBarras': _limpiarTexto(codigoArticulo) ?? "",
      'Cantidad': _cantidadParaServidor(),
      'Usuario': idUsuario,
      'Lote': _limpiarTexto(lote) ?? "",
      // Formato YYYY-MM-DD para el Servidor
      'FechaEnvio': _formatearFechaServidor(fechaEnvio ?? DateTime.now()),
      // Trazabilidad GS1-128 (el servidor ignora lo que no use).
      'FechaCaducidad': fechaCaducidad != null
          ? _formatearFechaCorta(fechaCaducidad!)
          : "",
      'PesoNeto': pesoNeto,
      'PesoBruto': pesoBruto,
      'SSCC': _limpiarTexto(sscc) ?? "",
    };
  }

  /// INT si la cantidad es entera, DOUBLE si trae decimales (pesos).
  dynamic _cantidadParaServidor() {
    return cantidad == cantidad.truncateToDouble()
        ? cantidad.toInt()
        : cantidad;
  }

  // ================== DESDE SQLITE ==================
  factory Lectura.fromMap(Map<String, dynamic> map) {
    return Lectura(
      id: map['_id'] as int? ?? map['id'] as int?,
      codigoArticulo: map['codigo_articulo']?.toString() ?? '',
      referenciaArticulo: map['referencia_articulo']?.toString() ?? '',
      cantidad: (map['cantidad'] is int) 
          ? (map['cantidad'] as int).toDouble() 
          : (map['cantidad'] as double? ?? 0.0),
      fechaRegistro: DateTime.parse(map['fecha_registro']),
      fechaEnvio: map['fecha_envio'] != null
          ? DateTime.parse(map['fecha_envio'])
          : null,
      idUsuario: map['id_usuario'] as int? ?? 0,
      sincronizado: map['sincronizado'] == 1,
      lote: map['lote']?.toString(),
      esDescatalogado: map['es_descatalogado'] == 1,
      descripcion: map['descripcion']?.toString(),
      tipoOperacion: TipoOperacion.values.firstWhere(
        (e) => e.name == (map['tipo_operacion'] ?? 'inventario'),
        orElse: () => TipoOperacion.inventario,
      ),
      fechaCaducidad: map['fecha_caducidad'] != null
          ? DateTime.parse(map['fecha_caducidad'].toString())
          : null,
      pesoNeto: (map['peso_neto'] as num?)?.toDouble(),
      pesoBruto: (map['peso_bruto'] as num?)?.toDouble(),
      sscc: map['sscc']?.toString(),
    );
  }

  Lectura copyWith({
    int? id,
    String? codigoArticulo,
    String? referenciaArticulo,
    double? cantidad,
    DateTime? fechaRegistro,
    DateTime? fechaEnvio,
    int? idUsuario,
    bool? sincronizado,
    String? lote,
    bool? esDescatalogado,
    String? descripcion,
    TipoOperacion? tipoOperacion,
    DateTime? fechaCaducidad,
    // FIFO: permite poner la fecha a null (el ?? impediría quitarla).
    bool quitarFechaCaducidad = false,
    double? pesoNeto,
    double? pesoBruto,
    String? sscc,
  }) {
    return Lectura(
      id: id ?? this.id,
      codigoArticulo: codigoArticulo ?? this.codigoArticulo,
      referenciaArticulo: referenciaArticulo ?? this.referenciaArticulo,
      cantidad: cantidad ?? this.cantidad,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      idUsuario: idUsuario ?? this.idUsuario,
      sincronizado: sincronizado ?? this.sincronizado,
      lote: lote ?? this.lote,
      esDescatalogado: esDescatalogado ?? this.esDescatalogado,
      descripcion: descripcion ?? this.descripcion,
      tipoOperacion: tipoOperacion ?? this.tipoOperacion,
      fechaCaducidad: quitarFechaCaducidad
          ? null
          : (fechaCaducidad ?? this.fechaCaducidad),
      pesoNeto: pesoNeto ?? this.pesoNeto,
      pesoBruto: pesoBruto ?? this.pesoBruto,
      sscc: sscc ?? this.sscc,
    );
  }


  static String? _limpiarTexto(String? texto) {
    if (texto == null) return null;
    // Quitamos NBSP (160) y cualquier otro espacio extraño
    return texto.replaceAll(RegExp(r'[\u00A0\u0020\u200B]'), "").trim();
  }

  String _formatearFechaServidor(DateTime fecha) {
  return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')} "
         "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}:${fecha.second.toString().padLeft(2, '0')}";
}

  String _formatearFechaCorta(DateTime fecha) {
    return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
  }
}
