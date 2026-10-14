import 'dart:convert';
import 'lectura.dart';
import 'tipo_operacion.dart';

/// Estado de una línea del documento frente a lo leído.
enum EstadoLinea { pendiente, parcial, completa, sobrante }

/// Una línea esperada de un albarán (compra) o factura (venta).
class LineaDocumentoEsperada {
  final String referencia;
  final String? codigoBarras;
  final String? descripcion;
  final double cantidadEsperada;
  final String? lote;

  const LineaDocumentoEsperada({
    required this.referencia,
    this.codigoBarras,
    this.descripcion,
    required this.cantidadEsperada,
    this.lote,
  });

  Map<String, dynamic> toMap() {
    return {
      'referencia': referencia,
      'codigoBarras': codigoBarras,
      'descripcion': descripcion,
      'cantidadEsperada': cantidadEsperada,
      'lote': lote,
    };
  }

  factory LineaDocumentoEsperada.fromMap(Map<String, dynamic> map) {
    return LineaDocumentoEsperada(
      referencia: map['referencia']?.toString() ?? '',
      codigoBarras: map['codigoBarras']?.toString(),
      descripcion: map['descripcion']?.toString(),
      cantidadEsperada:
          (map['cantidadEsperada'] as num?)?.toDouble() ?? 0.0,
      lote: map['lote']?.toString(),
    );
  }
}

/// Documento esperado (albarán de compra / factura de venta) contra el que
/// se comprueban las lecturas al recepcionar o expedir mercancía.
class DocumentoEsperado {
  final int? id;
  final TipoOperacion tipo;
  final String numero;
  final DateTime? fecha;
  final String? tercero;
  final List<LineaDocumentoEsperada> lineas;

  const DocumentoEsperado({
    this.id,
    required this.tipo,
    required this.numero,
    this.fecha,
    this.tercero,
    this.lineas = const [],
  });

  DocumentoEsperado copyWith({
    int? id,
    TipoOperacion? tipo,
    String? numero,
    DateTime? fecha,
    String? tercero,
    List<LineaDocumentoEsperada>? lineas,
  }) {
    return DocumentoEsperado(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      numero: numero ?? this.numero,
      fecha: fecha ?? this.fecha,
      tercero: tercero ?? this.tercero,
      lineas: lineas ?? this.lineas,
    );
  }

  /// Serialización para la tabla local `documentos` (líneas como JSON).
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo.name,
      'numero': numero,
      'fecha': fecha?.toIso8601String(),
      'tercero': tercero,
      'lineas_json':
          jsonEncode(lineas.map((l) => l.toMap()).toList()),
    };
  }

  factory DocumentoEsperado.fromMap(Map<String, dynamic> map) {
    final List<LineaDocumentoEsperada> lineas = [];
    final rawLineas = map['lineas_json']?.toString() ?? '[]';
    try {
      final decoded = jsonDecode(rawLineas) as List;
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          lineas.add(LineaDocumentoEsperada.fromMap(e));
        } else if (e is Map) {
          lineas.add(
            LineaDocumentoEsperada.fromMap(
              Map<String, dynamic>.from(e),
            ),
          );
        }
      }
    } catch (_) {
      // Líneas corruptas: documento sin líneas, no se rompe la lectura.
    }
    return DocumentoEsperado(
      id: map['id'] as int?,
      tipo: TipoOperacion.values.firstWhere(
        (e) => e.name == (map['tipo'] ?? 'compra'),
        orElse: () => TipoOperacion.compra,
      ),
      numero: map['numero']?.toString() ?? '',
      fecha: map['fecha'] != null
          ? DateTime.tryParse(map['fecha'].toString())
          : null,
      tercero: map['tercero']?.toString(),
      lineas: lineas,
    );
  }
}

/// Línea del documento con lo realmente leído y su estado.
class LineaComprobada {
  final LineaDocumentoEsperada esperada;
  final double cantidadLeida;

  const LineaComprobada({
    required this.esperada,
    required this.cantidadLeida,
  });

  EstadoLinea get estado {
    const eps = 1e-9;
    final diff = cantidadLeida - esperada.cantidadEsperada;
    if (cantidadLeida <= eps) return EstadoLinea.pendiente;
    if (diff < -eps) return EstadoLinea.parcial;
    if (diff > eps) return EstadoLinea.sobrante;
    return EstadoLinea.completa;
  }
}

/// Lectura que no corresponde a ninguna línea del documento.
class LecturaSobrante {
  final String codigo;
  final String referencia;
  final String? lote;
  final double cantidad;

  const LecturaSobrante({
    required this.codigo,
    required this.referencia,
    this.lote,
    required this.cantidad,
  });
}

/// Resultado de comparar un documento con las lecturas pendientes.
class ResultadoComprobacion {
  final List<LineaComprobada> lineas;
  final List<LecturaSobrante> sinLinea;

  const ResultadoComprobacion({
    required this.lineas,
    required this.sinLinea,
  });

  int get totalLineas => lineas.length;
  int get completas =>
      lineas.where((l) => l.estado == EstadoLinea.completa).length;
  int get parciales =>
      lineas.where((l) => l.estado == EstadoLinea.parcial).length;
  int get pendientes =>
      lineas.where((l) => l.estado == EstadoLinea.pendiente).length;
  int get sobrantes =>
      lineas.where((l) => l.estado == EstadoLinea.sobrante).length;

  double get cantidadEsperadaTotal =>
      lineas.fold(0.0, (s, l) => s + l.esperada.cantidadEsperada);
  double get cantidadLeidaTotal =>
      lineas.fold(0.0, (s, l) => s + l.cantidadLeida);

  /// Unidades que faltan por leer (pendientes + parciales).
  double get unidadesFaltantes => lineas
      .where((l) =>
          l.estado == EstadoLinea.pendiente ||
          l.estado == EstadoLinea.parcial)
      .fold(0.0, (s, l) => s + (l.esperada.cantidadEsperada - l.cantidadLeida));

  /// Unidades leídas de más (líneas sobrantes).
  double get unidadesSobrantes => lineas
      .where((l) => l.estado == EstadoLinea.sobrante)
      .fold(0.0, (s, l) => s + (l.cantidadLeida - l.esperada.cantidadEsperada));

  bool get estaCompleto =>
      lineas.isNotEmpty &&
      pendientes == 0 &&
      parciales == 0 &&
      sobrantes == 0 &&
      sinLinea.isEmpty;
}

/// Indica si una lectura encaja en alguna línea del documento (sin importar
/// la cantidad): referencia por dígitos, código exacto y lote si se exige.
/// Se usa para resaltar en la tabla las lecturas fuera de documento.
bool documentoContieneLectura(DocumentoEsperado documento, Lectura lectura) {
  String digitos(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');
  String limpio(String? v) => (v ?? '').trim();

  final refLec = digitos(lectura.referenciaArticulo);
  final codLec = limpio(lectura.codigoArticulo);
  final loteLec = limpio(lectura.lote);

  for (final linea in documento.lineas) {
    final refEsp = digitos(linea.referencia);
    final codEsp = limpio(linea.codigoBarras);
    final coincideRef =
        refEsp.isNotEmpty && refLec == refEsp;
    final coincideCod =
        codEsp.isNotEmpty && codLec == codEsp;
    if (!coincideRef && !coincideCod) continue;
    final loteEsp = limpio(linea.lote);
    if (loteEsp.isNotEmpty && loteLec != loteEsp) continue;
    return true;
  }
  return false;
}

/// Compara las líneas esperadas con las lecturas pendientes del mismo tipo.
/// Empareja por referencia (solo dígitos) o código de barras exacto; si la
/// línea exige lote, solo suman las lecturas con ese mismo lote.
ResultadoComprobacion compararDocumentoConLecturas(
  DocumentoEsperado documento,
  List<Lectura> lecturas,
) {
  String digitos(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');
  String limpio(String? v) => (v ?? '').trim();

  final pendientes = lecturas
      .where((l) => l.tipoOperacion == documento.tipo)
      .toList();

  final consumidas = <int>{};
  final comprobadas = <LineaComprobada>[];

  for (final linea in documento.lineas) {
    double suma = 0.0;
    final refEsperada = digitos(linea.referencia);
    final codEsperado = limpio(linea.codigoBarras);
    final loteEsperado = limpio(linea.lote);

    for (int i = 0; i < pendientes.length; i++) {
      if (consumidas.contains(i)) continue;
      final l = pendientes[i];
      final coincideRef = refEsperada.isNotEmpty &&
          digitos(l.referenciaArticulo) == refEsperada;
      final coincideCod =
          codEsperado.isNotEmpty && limpio(l.codigoArticulo) == codEsperado;
      if (!coincideRef && !coincideCod) continue;
      if (loteEsperado.isNotEmpty && limpio(l.lote) != loteEsperado) {
        continue;
      }
      suma += l.cantidad;
      consumidas.add(i);
    }

    comprobadas.add(
      LineaComprobada(esperada: linea, cantidadLeida: suma),
    );
  }

  final sinLinea = <LecturaSobrante>[];
  for (int i = 0; i < pendientes.length; i++) {
    if (consumidas.contains(i)) continue;
    final l = pendientes[i];
    sinLinea.add(
      LecturaSobrante(
        codigo: l.codigoArticulo,
        referencia: l.referenciaArticulo,
        lote: l.lote,
        cantidad: l.cantidad,
      ),
    );
  }

  return ResultadoComprobacion(lineas: comprobadas, sinLinea: sinLinea);
}
