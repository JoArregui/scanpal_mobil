import 'dart:math';
import 'package:flutter/foundation.dart';

/* ─────────────────────────────────────────────────────────────
   Decodificación GS1-128 según "Iniciación a la codificación
   GS1-128" (AECOC / GS1 España).
   - Solo capa de decodificación: no contiene UI.
   - API pública sin cambios: TipoCodigo, BarcodeData,
     GS1AI, gs1Catalog, BarcodeParser.parse().
   ───────────────────────────────────────────────────────────── */

enum TipoCodigo { ean13, ean8, upc, gs1, code128, nava, code39, desconocido }

class BarcodeData {
  final TipoCodigo tipo;
  final String codigoArticulo;
  final String? lote;
  final DateTime? fechaCaducidad;
  final DateTime? fechaProduccion;
  final DateTime? fechaEnvasado;
  final DateTime? fechaConsumoPreferente;
  final double? cantidad;
  final String? pesoNeto;
  final String? pesoBruto;
  final String? scc;
  final String? numeroPedido;
  final String? variante;
  final String? numeroSerie;
  final String? glnDestino;
  final String? codigoPostal;
  final Map<String, String> todosLosIAs;
  final String rawData;

  const BarcodeData({
    required this.tipo,
    required this.codigoArticulo,
    this.lote,
    this.fechaCaducidad,
    this.fechaProduccion,
    this.fechaEnvasado,
    this.fechaConsumoPreferente,
    this.cantidad,
    this.pesoNeto,
    this.pesoBruto,
    this.scc,
    this.numeroPedido,
    this.variante,
    this.numeroSerie,
    this.glnDestino,
    this.codigoPostal,
    this.todosLosIAs = const {},
    required this.rawData,
  });
}

/* ─────────────────────────────────────────────────────────────
   CATÁLOGO GS1 (Anexo II del documento GS1-128).
   nX = numérico fijo de X. n..X = numérico variable máx X.
   an..X = alfanumérico variable máx X.
   requiresFnc1 = separador FNC1 obligatorio si el IA no cierra
   la línea de símbolo (pág. 10-11: no lo precisan 00, 01, 02,
   20, pesos/medidas, fechas y puntos operacionales 41X).
   ───────────────────────────────────────────────────────────── */

class GS1AI {
  final String prefix;
  final int min;
  final int max;
  final bool variable;
  final bool requiresFnc1;
  final String tipo;
  final String descripcion;

  const GS1AI({
    required this.prefix,
    required this.min,
    required this.max,
    required this.variable,
    required this.requiresFnc1,
    required this.tipo,
    this.descripcion = '',
  });
}

final Map<String, GS1AI> gs1Catalog = {
  // Unidad de envío y referencias (pág. 4-7)
  '00': GS1AI(
    prefix: '00',
    min: 18,
    max: 18,
    variable: false,
    requiresFnc1: false,
    tipo: 'sscc',
    descripcion: 'SSCC',
  ),
  '01': GS1AI(
    prefix: '01',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'gtin01',
    descripcion: 'GTIN agrupación logística',
  ),
  '02': GS1AI(
    prefix: '02',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'gtin02',
    descripcion: 'GTIN unidad inmediatamente inferior',
  ),
  '37': GS1AI(
    prefix: '37',
    min: 1,
    max: 8,
    variable: true,
    requiresFnc1: true,
    tipo: 'cantidad',
    descripcion: 'Cantidad (acompaña al IA 02)',
  ),
  // Fechas AAMMDD, 6 dígitos fijos (pág. 7)
  '11': GS1AI(
    prefix: '11',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
    descripcion: 'Fecha de producción',
  ),
  '12': GS1AI(
    prefix: '12',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
    descripcion: 'Fecha de pago',
  ),
  '13': GS1AI(
    prefix: '13',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
    descripcion: 'Fecha de envasado',
  ),
  '15': GS1AI(
    prefix: '15',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
    descripcion: 'Fecha de mínima duración',
  ),
  '17': GS1AI(
    prefix: '17',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
    descripcion: 'Fecha de máxima duración',
  ),
  // Trazabilidad (pág. 8-9)
  '10': GS1AI(
    prefix: '10',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'lote',
    descripcion: 'Número de lote o partida',
  ),
  '20': GS1AI(
    prefix: '20',
    min: 2,
    max: 2,
    variable: false,
    requiresFnc1: false,
    tipo: 'variante',
    descripcion: 'Variante del producto',
  ),
  '21': GS1AI(
    prefix: '21',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'serie',
    descripcion: 'Número de serie',
  ),
  '22': GS1AI(
    prefix: '22',
    min: 1,
    max: 29,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'HIBCC',
  ),
  '240': GS1AI(
    prefix: '240',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Identificación adicional del producto',
  ),
  '241': GS1AI(
    prefix: '241',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Número de producto del cliente',
  ),
  '250': GS1AI(
    prefix: '250',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'serie',
    descripcion: 'Número de serie secundario',
  ),
  '251': GS1AI(
    prefix: '251',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Referencia de origen de la entidad',
  ),
  // Cantidades
  '30': GS1AI(
    prefix: '30',
    min: 1,
    max: 8,
    variable: true,
    requiresFnc1: true,
    tipo: 'cantidad',
    descripcion: 'Cantidad variable',
  ),
  // Pedidos y consignación
  '400': GS1AI(
    prefix: '400',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'pedido',
    descripcion: 'Número de pedido del cliente',
  ),
  '401': GS1AI(
    prefix: '401',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Número de consignación',
  ),
  '402': GS1AI(
    prefix: '402',
    min: 17,
    max: 17,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Número de identificación del envío',
  ),
  '403': GS1AI(
    prefix: '403',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Código de ruta',
  ),
  // Puntos operacionales GLN (no precisan FNC1, pág. 10)
  '410': GS1AI(
    prefix: '410',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'Expedir a',
  ),
  '411': GS1AI(
    prefix: '411',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'Facturar a',
  ),
  '412': GS1AI(
    prefix: '412',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'Comprado a',
  ),
  '413': GS1AI(
    prefix: '413',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'Expedir para',
  ),
  '414': GS1AI(
    prefix: '414',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'Punto operacional',
  ),
  '415': GS1AI(
    prefix: '415',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
    descripcion: 'GLN de la línea de factura',
  ),
  // Códigos postales y países
  '420': GS1AI(
    prefix: '420',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'cp',
    descripcion: 'Código postal',
  ),
  '421': GS1AI(
    prefix: '421',
    min: 4,
    max: 12,
    variable: true,
    requiresFnc1: true,
    tipo: 'cp',
    descripcion: 'Código postal con país ISO',
  ),
  '422': GS1AI(
    prefix: '422',
    min: 3,
    max: 3,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'País de nacimiento del animal',
  ),
  '423': GS1AI(
    prefix: '423',
    min: 3,
    max: 15,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'País de cebo',
  ),
  '424': GS1AI(
    prefix: '424',
    min: 3,
    max: 3,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'País de producción',
  ),
  '425': GS1AI(
    prefix: '425',
    min: 3,
    max: 3,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'País de despiece',
  ),
  '426': GS1AI(
    prefix: '426',
    min: 3,
    max: 3,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'País del proceso completo',
  ),
  // Importes 390n-393n: el 4.º dígito indica decimales.
  // Se resuelven de forma dinámica en _resolverAI().
  // Carne / sacrificio
  '7001': GS1AI(
    prefix: '7001',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Número de stock',
  ),
  '7002': GS1AI(
    prefix: '7002',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Clasificación UN/ENE del corte',
  ),
  // Medidas 310n-369n: el 4.º dígito indica decimales (pág. 8).
  // Se resuelven de forma dinámica en _resolverAI().
  // Activos, precios y cupones
  '8001': GS1AI(
    prefix: '8001',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Productos bobinados',
  ),
  '8002': GS1AI(
    prefix: '8002',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'N.º serie electrónico móvil',
  ),
  '8003': GS1AI(
    prefix: '8003',
    min: 16,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'GTIN y serie de retornables',
  ),
  '8004': GS1AI(
    prefix: '8004',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'GTIN seriada del activo',
  ),
  '8006': GS1AI(
    prefix: '8006',
    min: 18,
    max: 18,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Componente de un artículo',
  ),
  '8007': GS1AI(
    prefix: '8007',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Número de cuenta del banco',
  ),
  '8008': GS1AI(
    prefix: '8008',
    min: 9,
    max: 12,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Fecha y hora de producción',
  ),
  '8018': GS1AI(
    prefix: '8018',
    min: 18,
    max: 18,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Identificación de servicio',
  ),
  '8020': GS1AI(
    prefix: '8020',
    min: 1,
    max: 25,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
    descripcion: 'Referencia del pago',
  ),
  '8100': GS1AI(
    prefix: '8100',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Cupón extendido',
  ),
  '8101': GS1AI(
    prefix: '8101',
    min: 10,
    max: 10,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Cupón extendido con fin',
  ),
  '8102': GS1AI(
    prefix: '8102',
    min: 2,
    max: 2,
    variable: false,
    requiresFnc1: false,
    tipo: 'texto',
    descripcion: 'Cupón extendido NSC',
  ),
  // Uso interno / mutuo acuerdo
  '90': GS1AI(
    prefix: '90',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación mutuamente acordada',
  ),
  '91': GS1AI(
    prefix: '91',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '92': GS1AI(
    prefix: '92',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '93': GS1AI(
    prefix: '93',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '94': GS1AI(
    prefix: '94',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '95': GS1AI(
    prefix: '95',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '96': GS1AI(
    prefix: '96',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '97': GS1AI(
    prefix: '97',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '98': GS1AI(
    prefix: '98',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
  '99': GS1AI(
    prefix: '99',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
    descripcion: 'Aplicación interna',
  ),
};

/* ─────────────────────────────────────────────────────────────
   Familias de IA de 4 dígitos con significado en el 4.º dígito
   (pág. 8 y Anexo II). No se enumeran una a una: se resuelven
   por rango para cubrir 310n-369n, 390n-393n y 703x.
   ───────────────────────────────────────────────────────────── */

/// Resuelve la especificación de un IA de 2 a 4 dígitos.
/// Devuelve un [GS1AI] dinámico para las familias con 4.º dígito
/// significativo (medidas con decimal, importes, 703x).
GS1AI? _resolverAI(String ai) {
  final directo = gs1Catalog[ai];
  if (directo != null) return directo;
  if (ai.length != 4) return null;

  final base3 = int.tryParse(ai.substring(0, 3));
  final cuarto = ai[3];
  if (base3 == null || int.tryParse(cuarto) == null) return null;
  final decimales = int.parse(cuarto);

  // Medidas comerciales y logísticas 310n-369n: n4+n6, sin FNC1.
  if (base3 >= 310 && base3 <= 369) {
    final esBruto = base3 >= 330 && base3 <= 349 ||
        base3 == 353 ||
        base3 == 354 ||
        base3 == 355 ||
        base3 == 362 ||
        base3 == 363 ||
        base3 == 367 ||
        base3 == 368 ||
        base3 == 369;
    return GS1AI(
      prefix: ai,
      min: 6,
      max: 6,
      variable: false,
      requiresFnc1: false,
      tipo: esBruto ? 'medidaBruta' : 'medidaNeta',
      descripcion: 'Medida $ai ($decimales decimales)',
    );
  }

  // Importes 390n-393n: longitud variable con decimales.
  if (base3 >= 390 && base3 <= 393) {
    return GS1AI(
      prefix: ai,
      min: 1,
      max: 15,
      variable: true,
      requiresFnc1: true,
      tipo: 'importe',
      descripcion: 'Importe $ai ($decimales decimales)',
    );
  }

  // 703x: país de despiece + registro sanitario (n4+n3+an..27).
  if (ai.startsWith('703')) {
    return GS1AI(
      prefix: ai,
      min: 4,
      max: 30,
      variable: true,
      requiresFnc1: true,
      tipo: 'texto',
      descripcion: 'Despiece y registro sanitario',
    );
  }

  // 8005: precio por unidad de medida (n4+n6 con decimal).
  if (ai == '8005') {
    return GS1AI(
      prefix: ai,
      min: 6,
      max: 6,
      variable: false,
      requiresFnc1: false,
      tipo: 'medidaNeta',
      descripcion: 'Precio por unidad ($decimales decimales)',
    );
  }

  return null;
}

/* ─────────────────────────────────────────────────────────────
   BARCODE PARSER
   ───────────────────────────────────────────────────────────── */

class BarcodeParser {
  static const String _fnc1 = ''; // GS (Group Separator, ASCII 29), separador FNC1
  static const String _symbologyId = ']C1';

  static BarcodeData parse(String raw) {
    if (kDebugMode) {
      print('📸 CÁMARA LEYÓ: "$raw"');
    }

    final codigo = raw.trim();

    if (kDebugMode) {
      print('╔════════════════════════════════════════════════════════════╗');
      print('║    🔍 BARCODE PARSER - ANÁLISIS DETALLADO                  ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('📥 RAW INPUT: "$codigo"');
      print('📏 LONGITUD: ${codigo.length}');
      print('🔢 CONTIENE FNC1: ${codigo.contains(_fnc1)}');
      print('─────────────────────────────────────────────────────────────');
    }

    // HEURÍSTICA: Patrón de segmentación Referencia/Lote (Ej: 10548/222100)
    // Se procesa antes que la limpieza de ruido para no perder la "/" separadora
    if (codigo.contains('/')) {
      final partes = codigo.split('/');
      // Si tenemos dos partes y la primera parece una referencia (mínimo 3 caracteres)
      if (partes.length == 2 && partes[0].length >= 3) {
        if (kDebugMode) {
          print('🎯 [HEURÍSTICA] Detectado patrón Segmentado por Barra (Ref/Lote)');
        }

        return BarcodeData(
          tipo: TipoCodigo.nava,
          codigoArticulo: partes[0].trim(),
          lote: partes[1].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim(),
          rawData: codigo,
        );
      }
    }

    // Heurística Viveros Nava - Detectar patrón "LOTE - FECHA"
    if (codigo.contains(' - ') ||
        (codigo.contains('/') && codigo.length > 10 && RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(codigo))) {
      if (kDebugMode) {
        print('📡 [HEURÍSTICA] Detectado patrón Viveros Nava (Lote-Fecha)');
      }

      final partes = codigo.split(RegExp(r'\s*-\s*'));
      final String loteExtraido = partes.isNotEmpty ? partes[0].trim() : codigo;
      DateTime? fechaProcesada;

      if (partes.length > 1) {
        fechaProcesada = _parseFechaNava(partes[1]);
      }

      // FIX: codigoArticulo = loteExtraido en lugar de '' para que la búsqueda tenga valor
      if (kDebugMode) {
        print('📡 [HEURÍSTICA] codigoArticulo asignado al lote: "$loteExtraido"');
      }

      return BarcodeData(
        tipo: TipoCodigo.nava,
        codigoArticulo: loteExtraido, // ← ANTES: ''
        lote: loteExtraido,
        fechaProduccion: fechaProcesada,
        rawData: codigo,
      );
    }

    // Identificar GS1-128
    if (_esGS1(codigo)) {
      if (kDebugMode) {
        print('✅ [DETECTOR] GS1-128 detectado');
      }
      return _parseGS1Total(codigo);
    }

    // EAN-13 estándar
    if (RegExp(r'^\d{13}$').hasMatch(codigo)) {
      if (!_validarEan13(codigo) && kDebugMode) {
        print('⚠️ [EAN-13] Dígito de control no válido: "$codigo"');
      }
      return BarcodeData(
        tipo: TipoCodigo.ean13,
        codigoArticulo: codigo,
        rawData: codigo,
      );
    }

    // EAN-8 estándar
    if (RegExp(r'^\d{8}$').hasMatch(codigo)) {
      return BarcodeData(
        tipo: TipoCodigo.ean8,
        codigoArticulo: codigo,
        rawData: codigo,
      );
    }

    // UPC-A (se normaliza a 13 dígitos añadiendo 0 a la izquierda)
    if (RegExp(r'^\d{12}$').hasMatch(codigo)) {
      return BarcodeData(
        tipo: TipoCodigo.upc,
        codigoArticulo: '0$codigo',
        rawData: codigo,
      );
    }

    // NUEVO: Limpieza de Ruido - Detectar caracteres erróneos de lectura (%, $, etc)
    if (codigo.contains(RegExp(r'[%$]'))) {
      if (kDebugMode) {
        print('⚠️ [LIMPIEZA] Caracteres de ruido detectados. Aplicando filtro.');
      }
      final String codigoLimpio = codigo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      return BarcodeData(
        tipo: TipoCodigo.code39,
        codigoArticulo: codigoLimpio,
        rawData: codigo,
      );
    }

    // Por defecto, tratar como Code 128 genérico
    return BarcodeData(
      tipo: TipoCodigo.code128,
      codigoArticulo: codigo,
      rawData: codigo,
    );
  }

  /// Detección GS1-128 (pág. 13): identificador de simbología ]C1,
  /// carácter FNC1, prefijos 00/01/02 o IAs entre paréntesis de la
  /// representación humanamente legible (pág. 3 y 10: los paréntesis
  /// no van en barras pero sí a pie de código, por lo que la entrada
  /// manual puede traerlos).
  static bool _esGS1(String c) =>
      c.startsWith(_symbologyId) ||
      c.toLowerCase().startsWith(']c1') ||
      c.contains(_fnc1) ||
      RegExp(r'\((00|01|02|10|11|13|15|17|20|21|30|37|310|330|400)\d*\)').hasMatch(c) ||
      (c.length > 14 && (c.startsWith('01') || c.startsWith('00'))) ||
      // Flujo que abre con (02): bulto no estándar 02+37+... Los EAN-13 de
      // peso variable que empiezan por 2 miden 13, por eso se exige > 20.
      (c.length > 20 && c.startsWith('02'));

  /// Extrae el IA en [pos] probando 4, 3 y 2 dígitos (pág. 4: cada IA
  /// está formado por grupos de 2, 3 o 4 caracteres).
  static String _extraerIA(String data, int pos) {
    if (pos + 4 <= data.length) {
      final candidato = data.substring(pos, pos + 4);
      if (_resolverAI(candidato) != null) return candidato;
    }
    if (pos + 3 <= data.length &&
        gs1Catalog.containsKey(data.substring(pos, pos + 3))) {
      return data.substring(pos, pos + 3);
    }
    if (pos + 2 <= data.length &&
        gs1Catalog.containsKey(data.substring(pos, pos + 2))) {
      return data.substring(pos, pos + 2);
    }
    return '';
  }

  /// Parsea la representación humanamente legible con paréntesis,
  /// p. ej. "(01)08456789567807(15)080423(10)89B23" (ejemplo pág. 4).
  /// Los paréntesis nunca van en barras (pág. 10) pero sí a pie de
  /// código, por lo que la entrada manual puede traer este formato.
  /// Devuelve null si no hay ningún segmento válido.
  static Map<String, String>? _parseParenthesized(String data) {
    if (!data.contains('(') || !data.contains(')')) return null;
    final exp = RegExp(r'\((\d{2,4})\)([^(]*)');
    final matches = exp.allMatches(data);
    if (matches.isEmpty) return null;

    final mapa = <String, String>{};
    for (final m in matches) {
      final ai = m.group(1)!;
      final spec = _resolverAI(ai);
      if (spec == null) {
        if (kDebugMode) print('    ⚠️ IA entre paréntesis no reconocido: ($ai)');
        continue;
      }
      var valor = m.group(2)!.replaceAll(_fnc1, '').trim();
      if (valor.length < spec.min) {
        if (kDebugMode) {
          print('    ⚠️ ($ai) dato demasiado corto: "$valor" (mínimo ${spec.min})');
        }
        continue;
      }
      if (valor.length > spec.max) {
        if (kDebugMode) {
          print('    ⚠️ ($ai) dato recortado a ${spec.max}: "$valor"');
        }
        valor = valor.substring(0, spec.max);
      }
      // Los fijos deben tener longitud exacta.
      if (!spec.variable && valor.length != spec.max) {
        if (kDebugMode) {
          print('    ⚠️ ($ai) longitud fija inválida: "$valor"');
        }
        continue;
      }
      mapa[ai] = valor;
    }
    return mapa.isEmpty ? null : mapa;
  }

  static BarcodeData _parseGS1Total(String raw) {
    var data = raw.trim();
    if (data.startsWith(_symbologyId)) {
      data = data.substring(_symbologyId.length);
    } else if (data.toLowerCase().startsWith(']c1')) {
      data = data.substring(3);
    }

    if (kDebugMode) {
      print('⚙️ [GS1_ENGINE] Inicio parsing GS1');
      print('DATA: "$data"');
      if (data.length > 48) {
        print('⚠️ [GS1_ENGINE] Supera 48 caracteres de datos (máx. pág. 10)');
      }
      print('─────────────────────────────────────────────────────────────');
    }

    // 1) Forma humanamente legible con paréntesis (entrada manual).
    final entreParentesis = _parseParenthesized(data);
    if (entreParentesis != null) {
      if (kDebugMode) print('📝 [GS1_ENGINE] Modo paréntesis (legible por humano)');
      return _construirDesdeMapa(entreParentesis, raw);
    }

    // 2) Flujo de barras con separador FNC1 (pág. 10-11).
    String? gtin01, gtin02, lote, scc, numPedido, numSerie, variante, gln, cp;
    DateTime? caducidad, produccion, envasado, consumo;
    double? cantidad37, cantidad30, pesoNetoKg, pesoBrutoKg;
    String? pesoNetoTxt, pesoBrutoTxt;

    final Map<String, String> mapa = {};

    int i = 0;
    int contador = 0;

    while (i < data.length) {
      final ia = _extraerIA(data, i);
      if (ia.isEmpty) {
        if (kDebugMode) {
          print(
            '🛑 IA no reconocido en posición $i. Resto: ${data.substring(i)}',
          );
        }
        break;
      }

      final spec = _resolverAI(ia)!;
      contador++;

      if (kDebugMode) {
        print('📍 [IA #$contador] $ia (${spec.tipo})');
      }

      i += ia.length;

      final end = spec.variable
          ? _buscarFinCampoVariable(data, i, spec.max)
          : i + spec.max;

      if (end > data.length) {
        // Dato fijo truncado al final de la línea: se acepta el resto
        // solo si cumple el mínimo (tolerancia de lectura).
        final valorRestante = data.substring(i);
        if (valorRestante.length < spec.min) {
          if (kDebugMode) {
            print('    ⚠️ Dato truncado bajo mínimo, se descarta: "$valorRestante"');
          }
          break;
        }
        mapa[ia] = valorRestante;
        _asignar(
          ia,
          spec,
          valorRestante,
          (v) => gtin01 = v,
          (v) => gtin02 = v,
          (v) => scc = v,
          (v) => lote = v,
          (v) => variante = v,
          (v) => numSerie = v,
          (v) => numPedido = v,
          (v) => gln = v,
          (v) => cp = v,
          (v) => cantidad37 = v,
          (v) => cantidad30 = v,
          (v, t) => pesoNetoKg = v,
          (v, t) => pesoBrutoKg = v,
          (v, t) => pesoNetoTxt = v,
          (v, t) => pesoBrutoTxt = v,
          (type, date) {
            if (type == '11') produccion = date;
            if (type == '13') envasado = date;
            if (type == '15') consumo = date;
            if (type == '17') caducidad = date;
          },
        );
        break;
      }

      final valor = data.substring(i, end);
      mapa[ia] = valor;

      if (kDebugMode) {
        print('    ✅ VALOR: "$valor"');
      }

      _asignar(
        ia,
        spec,
        valor,
        (v) => gtin01 = v,
        (v) => gtin02 = v,
        (v) => scc = v,
        (v) => lote = v,
        (v) => variante = v,
        (v) => numSerie = v,
        (v) => numPedido = v,
        (v) => gln = v,
        (v) => cp = v,
        (v) => cantidad37 = v,
        (v) => cantidad30 = v,
        (v, t) => pesoNetoKg = v,
        (v, t) => pesoBrutoKg = v,
        (v, t) => pesoNetoTxt = v,
        (v, t) => pesoBrutoTxt = v,
        (type, date) {
          if (type == '11') produccion = date;
          if (type == '13') envasado = date;
          if (type == '15') consumo = date;
          if (type == '17') caducidad = date;
        },
      );

      i = spec.variable ? _saltarFnc1(data, end) : end;
    }

    if (kDebugMode) {
      print('─────────────────────────────────────────────────────────────');
      print('📦 [RESUMEN GS1]');
      print('    ├─ GTIN-01: ${gtin01 ?? "NO"}');
      print('    ├─ GTIN-02: ${gtin02 ?? "NO"}');
      print('    ├─ SSCC: ${scc ?? "NO"}');
      print('    ├─ LOTE: ${lote ?? "NO"}');
      print('    ├─ CADUCIDAD: ${caducidad ?? "NO"}');
      print('    ├─ CANTIDAD: ${cantidad37 ?? cantidad30 ?? pesoNetoKg ?? pesoBrutoKg ?? "NO"}');
      print('    ├─ TOTAL IAs: ${mapa.length}');
      print('═════════════════════════════════════════════════════════════');
    }

    return _construirResultado(
      raw: raw,
      mapa: mapa,
      gtin01: gtin01,
      gtin02: gtin02,
      scc: scc,
      lote: lote,
      variante: variante,
      numSerie: numSerie,
      numPedido: numPedido,
      gln: gln,
      cp: cp,
      cantidad37: cantidad37,
      cantidad30: cantidad30,
      pesoNetoKg: pesoNetoKg,
      pesoBrutoKg: pesoBrutoKg,
      pesoNetoTxt: pesoNetoTxt,
      pesoBrutoTxt: pesoBrutoTxt,
      produccion: produccion,
      envasado: envasado,
      consumo: consumo,
      caducidad: caducidad,
    );
  }

  /// Construye el resultado desde un mapa IA → valor ya delimitado
  /// (modo paréntesis), aplicando las mismas reglas de asignación.
  static BarcodeData _construirDesdeMapa(
    Map<String, String> mapa,
    String raw,
  ) {
    String? gtin01, gtin02, lote, scc, numPedido, numSerie, variante, gln, cp;
    DateTime? caducidad, produccion, envasado, consumo;
    double? cantidad37, cantidad30, pesoNetoKg, pesoBrutoKg;
    String? pesoNetoTxt, pesoBrutoTxt;

    mapa.forEach((ia, valor) {
      final spec = _resolverAI(ia);
      if (spec == null) return;
      _asignar(
        ia,
        spec,
        valor,
        (v) => gtin01 = v,
        (v) => gtin02 = v,
        (v) => scc = v,
        (v) => lote = v,
        (v) => variante = v,
        (v) => numSerie = v,
        (v) => numPedido = v,
        (v) => gln = v,
        (v) => cp = v,
        (v) => cantidad37 = v,
        (v) => cantidad30 = v,
        (v, t) => pesoNetoKg = v,
        (v, t) => pesoBrutoKg = v,
        (v, t) => pesoNetoTxt = v,
        (v, t) => pesoBrutoTxt = v,
        (type, date) {
          if (type == '11') produccion = date;
          if (type == '13') envasado = date;
          if (type == '15') consumo = date;
          if (type == '17') caducidad = date;
        },
      );
    });

    return _construirResultado(
      raw: raw,
      mapa: mapa,
      gtin01: gtin01,
      gtin02: gtin02,
      scc: scc,
      lote: lote,
      variante: variante,
      numSerie: numSerie,
      numPedido: numPedido,
      gln: gln,
      cp: cp,
      cantidad37: cantidad37,
      cantidad30: cantidad30,
      pesoNetoKg: pesoNetoKg,
      pesoBrutoKg: pesoBrutoKg,
      pesoNetoTxt: pesoNetoTxt,
      pesoBrutoTxt: pesoBrutoTxt,
      produccion: produccion,
      envasado: envasado,
      consumo: consumo,
      caducidad: caducidad,
    );
  }

  /// Reglas de resolución (pág. 5-8):
  /// - Artículo: el (02) identifica el contenido y prevalece sobre el
  ///   (01) de la unidad logística; el (02) nunca va en bultos estándar.
  /// - El SSCC (00) es matrícula de la unidad de envío, nunca artículo:
  ///   un bulto de picking/multirreferencia solo trae (00) y su contenido
  ///   viaja en el DESADV (pág. 7), así que no se busca como artículo.
  /// - Cantidad: 37 (unidades del 02) > 30 > peso neto 310n > bruto 330n.
  /// - GTIN-14 con 0 inicial y resto EAN-13 válido se normaliza a 13
  ///   (error frecuente pág. 13: EAN-13 simbolizado con 0 a la izquierda).
  static BarcodeData _construirResultado({
    required String raw,
    required Map<String, String> mapa,
    required String? gtin01,
    required String? gtin02,
    required String? scc,
    required String? lote,
    required String? variante,
    required String? numSerie,
    required String? numPedido,
    required String? gln,
    required String? cp,
    required double? cantidad37,
    required double? cantidad30,
    required double? pesoNetoKg,
    required double? pesoBrutoKg,
    required String? pesoNetoTxt,
    required String? pesoBrutoTxt,
    required DateTime? produccion,
    required DateTime? envasado,
    required DateTime? consumo,
    required DateTime? caducidad,
  }) {
    final crudo = gtin02 ?? gtin01;
    final codigoArticulo = crudo == null ? '' : _normalizarGtin(crudo);
    final cantidad =
        cantidad37 ?? cantidad30 ?? pesoNetoKg ?? pesoBrutoKg;

    if (kDebugMode) {
      if (scc != null && crudo == null) {
        print('ℹ️ [GS1] Solo SSCC (picking/multirreferencia): sin artículo, ver DESADV');
      }
      if (gtin01 != null && gtin02 != null) {
        print('ℹ️ [GS1] Coexisten 01 y 02: se usa el contenido (02)');
      }
    }

    return BarcodeData(
      tipo: TipoCodigo.gs1,
      codigoArticulo: codigoArticulo,
      lote: lote,
      // FIFO: AI 17 (caducidad) y fallback a AI 15 (consumo preferente)
      // cuando no hay 17. Sin fecha => null (se ordena al final, sin aviso).
      fechaCaducidad: caducidad ?? consumo,
      fechaProduccion: produccion,
      fechaEnvasado: envasado,
      fechaConsumoPreferente: consumo,
      cantidad: cantidad,
      pesoNeto: pesoNetoTxt,
      pesoBruto: pesoBrutoTxt,
      scc: scc,
      numeroPedido: numPedido,
      variante: variante,
      numeroSerie: numSerie,
      glnDestino: gln,
      codigoPostal: cp,
      todosLosIAs: mapa,
      rawData: raw,
    );
  }

  static void _asignar(
    String ia,
    GS1AI spec,
    String valor,
    Function(String) setGtin01,
    Function(String) setGtin02,
    Function(String) setScc,
    Function(String) setLote,
    Function(String) setVariante,
    Function(String) setSerie,
    Function(String) setPedido,
    Function(String) setGln,
    Function(String) setCp,
    Function(double) setCantidad37,
    Function(double) setCantidad30,
    Function(double, String) setPesoNeto,
    Function(double, String) setPesoBruto,
    Function(String, String) setPesoNetoTxt,
    Function(String, String) setPesoBrutoTxt,
    Function(String, DateTime?) setFecha,
  ) {
    switch (spec.tipo) {
      case 'gtin01':
        if (_esNumerico(valor)) setGtin01(valor);
        break;
      case 'gtin02':
        if (_esNumerico(valor)) setGtin02(valor);
        break;
      case 'sscc':
        setScc(valor);
        break;
      case 'lote':
        setLote(valor);
        break;
      case 'variante':
        setVariante(valor);
        break;
      case 'serie':
        setSerie(valor);
        break;
      case 'pedido':
        setPedido(valor);
        break;
      case 'gln':
        setGln(valor);
        break;
      case 'cp':
        setCp(valor);
        break;
      case 'cantidad':
        final n = double.tryParse(valor);
        if (n != null) {
          if (ia == '37') {
            setCantidad37(n);
          } else {
            setCantidad30(n);
          }
        }
        break;
      case 'medidaNeta':
      case 'medidaBruta':
        // Pág. 8: el 4.º dígito del IA sitúa el decimal; valor/10^n.
        final decimales = int.tryParse(ia.substring(3)) ?? 0;
        final entero = int.tryParse(valor);
        if (entero != null) {
          final kg = entero / pow(10, decimales);
          final texto = _formatearDecimal(kg, decimales);
          if (spec.tipo == 'medidaNeta') {
            // Peso neto en kg (310n) o precio/unidad (8005).
            if (ia.startsWith('310')) {
              setPesoNeto(kg, texto);
              setPesoNetoTxt(texto, texto);
            }
          } else {
            // Peso bruto en kg (330n).
            if (ia.startsWith('330')) {
              setPesoBruto(kg, texto);
              setPesoBrutoTxt(texto, texto);
            }
          }
        }
        break;
      case 'fecha':
        setFecha(ia, _parseFechaGS1(valor));
        break;
      default:
        break;
    }
  }

  static int _buscarFinCampoVariable(String data, int start, int max) {
    final idx = data.indexOf(_fnc1, start);
    if (idx != -1 && idx < start + max) {
      if (kDebugMode) {
        print('      ℹ️ FNC1 detectado en posición $idx');
      }
      return idx;
    }
    return min(start + max, data.length);
  }

  static int _saltarFnc1(String data, int pos) {
    if (pos < data.length && data[pos] == _fnc1) return pos + 1;
    return pos;
  }

  /// Fechas AAMMDD de 6 dígitos (pág. 7). Día 00 = día no especificado:
  /// se resuelve al último día del mes. Mes fuera de 01-12 o día > 31
  /// invalidan el dato en lugar de crear fechas imposibles.
  static DateTime? _parseFechaGS1(String f) {
    if (f.length != 6 || !_esNumerico(f)) return null;
    try {
      final yy = int.parse(f.substring(0, 2)) + 2000;
      final mm = int.parse(f.substring(2, 4));
      final dd = int.parse(f.substring(4, 6));
      if (mm < 1 || mm > 12 || dd > 31) {
        if (kDebugMode) print('❌ Fecha GS1 inválida: $f');
        return null;
      }
      if (dd == 0) return DateTime(yy, mm + 1, 0);
      return DateTime(yy, mm, dd);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parseando fecha GS1: $f');
      }
      return null;
    }
  }

  static DateTime? _parseFechaNava(String fechaRaw) {
    try {
      final limpia = fechaRaw.trim();
      if (limpia.length < 10) return null;
      final d = int.parse(limpia.substring(0, 2));
      final m = int.parse(limpia.substring(3, 5));
      final y = int.parse(limpia.substring(6, 10));
      return DateTime(y, m, d);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al parsear fecha de Nava: $fechaRaw');
      }
      return null;
    }
  }

  /// Normaliza un GTIN de 14 a 13 solo cuando es un EAN-13 con 0 a la
  /// izquierda y el resto supera el dígito de control (pág. 13). Los
  /// indicadores logísticos 1-8 se conservan intactos.
  static String _normalizarGtin(String valor) {
    final v = valor.trim();
    if (v.length == 14 && v.startsWith('0') && _validarEan13(v.substring(1))) {
      return v.substring(1);
    }
    if (kDebugMode && v.length == 14 && !_validarGtin14(v)) {
      print('⚠️ [GS1] GTIN-14 con dígito de control no válido: "$v"');
    }
    return v;
  }

  static bool _esNumerico(String v) => RegExp(r'^\d+$').hasMatch(v);

  /// Dígito de control GS1 módulo 10 (válido para EAN-13, GTIN-14 y SSCC):
  /// peso 3 cuando (n-k) es par, 1 cuando es impar.
  static bool _checkGs1(String digitos) {
    int suma = 0;
    final n = digitos.length;
    for (int k = 0; k < n - 1; k++) {
      final d = int.tryParse(digitos[k]);
      if (d == null) return false;
      final peso = ((n - k) % 2 == 0) ? 3 : 1;
      suma += d * peso;
    }
    final control = (10 - (suma % 10)) % 10;
    return control == int.tryParse(digitos[n - 1]);
  }

  static bool _validarEan13(String v) =>
      v.length == 13 && _esNumerico(v) && _checkGs1(v);

  static bool _validarGtin14(String v) =>
      v.length == 14 && _esNumerico(v) && _checkGs1(v);

  /// Formatea un decimal con sus decimales exactos recortando ceros
  /// sobrantes: 350.0 → "350", 0.035 → "0.035", 200.0 → "200".
  static String _formatearDecimal(double valor, int decimales) {
    final dec = decimales < 0 ? 0 : (decimales > 6 ? 6 : decimales);
    var texto = valor.toStringAsFixed(dec);
    if (texto.contains('.')) {
      texto = texto.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return texto;
  }
}
