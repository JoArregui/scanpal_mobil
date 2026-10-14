import 'dart:math';
import 'package:flutter/foundation.dart';

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
   CATÁLOGO GS1 (INTEGRADO)
   ───────────────────────────────────────────────────────────── */

class GS1AI {
  final String prefix;
  final int min;
  final int max;
  final bool variable;
  final bool requiresFnc1;
  final String tipo;

  const GS1AI({
    required this.prefix,
    required this.min,
    required this.max,
    required this.variable,
    required this.requiresFnc1,
    required this.tipo,
  });
}

final Map<String, GS1AI> gs1Catalog = {
  '00': GS1AI(
    prefix: '00',
    min: 18,
    max: 18,
    variable: false,
    requiresFnc1: false,
    tipo: 'sscc',
  ),
  '01': GS1AI(
    prefix: '01',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'gtin',
  ),
  '02': GS1AI(
    prefix: '02',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'gtin',
  ),

  '11': GS1AI(
    prefix: '11',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
  ),
  '12': GS1AI(
    prefix: '12',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
  ),
  '13': GS1AI(
    prefix: '13',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
  ),
  '15': GS1AI(
    prefix: '15',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
  ),
  '17': GS1AI(
    prefix: '17',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'fecha',
  ),

  '10': GS1AI(
    prefix: '10',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'lote',
  ),
  '21': GS1AI(
    prefix: '21',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'serie',
  ),
  '22': GS1AI(
    prefix: '22',
    min: 1,
    max: 29,
    variable: true,
    requiresFnc1: true,
    tipo: 'texto',
  ),

  '30': GS1AI(
    prefix: '30',
    min: 1,
    max: 8,
    variable: true,
    requiresFnc1: true,
    tipo: 'cantidad',
  ),
  '310': GS1AI(
    prefix: '310',
    min: 6,
    max: 6,
    variable: false,
    requiresFnc1: false,
    tipo: 'peso',
  ),
  '37': GS1AI(
    prefix: '37',
    min: 1,
    max: 8,
    variable: true,
    requiresFnc1: true,
    tipo: 'cantidad',
  ),

  '400': GS1AI(
    prefix: '400',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'pedido',
  ),
  '401': GS1AI(
    prefix: '401',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'consignacion',
  ),
  '402': GS1AI(
    prefix: '402',
    min: 17,
    max: 17,
    variable: false,
    requiresFnc1: false,
    tipo: 'envio',
  ),
  '403': GS1AI(
    prefix: '403',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'ruta',
  ),

  '410': GS1AI(
    prefix: '410',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),
  '411': GS1AI(
    prefix: '411',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),
  '412': GS1AI(
    prefix: '412',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),
  '413': GS1AI(
    prefix: '413',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),
  '414': GS1AI(
    prefix: '414',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),
  '415': GS1AI(
    prefix: '415',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'gln',
  ),

  '420': GS1AI(
    prefix: '420',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'cp',
  ),
  '421': GS1AI(
    prefix: '421',
    min: 4,
    max: 12,
    variable: true,
    requiresFnc1: true,
    tipo: 'cp',
  ),

  '390': GS1AI(
    prefix: '390',
    min: 1,
    max: 15,
    variable: true,
    requiresFnc1: true,
    tipo: 'importe',
  ),
  '391': GS1AI(
    prefix: '391',
    min: 4,
    max: 18,
    variable: true,
    requiresFnc1: true,
    tipo: 'importe',
  ),
  '392': GS1AI(
    prefix: '392',
    min: 1,
    max: 15,
    variable: true,
    requiresFnc1: true,
    tipo: 'importe',
  ),
  '393': GS1AI(
    prefix: '393',
    min: 4,
    max: 18,
    variable: true,
    requiresFnc1: true,
    tipo: 'importe',
  ),

  '7001': GS1AI(
    prefix: '7001',
    min: 13,
    max: 13,
    variable: false,
    requiresFnc1: false,
    tipo: 'stock',
  ),
  '7002': GS1AI(
    prefix: '7002',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'clasificacion',
  ),

  '8001': GS1AI(
    prefix: '8001',
    min: 14,
    max: 14,
    variable: false,
    requiresFnc1: false,
    tipo: 'activo',
  ),
  '8002': GS1AI(
    prefix: '8002',
    min: 1,
    max: 20,
    variable: true,
    requiresFnc1: true,
    tipo: 'activo',
  ),
  '8003': GS1AI(
    prefix: '8003',
    min: 16,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'activo',
  ),
  '8004': GS1AI(
    prefix: '8004',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'activo',
  ),

  '90': GS1AI(
    prefix: '90',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '91': GS1AI(
    prefix: '91',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '92': GS1AI(
    prefix: '92',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '93': GS1AI(
    prefix: '93',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '94': GS1AI(
    prefix: '94',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '95': GS1AI(
    prefix: '95',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '96': GS1AI(
    prefix: '96',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '97': GS1AI(
    prefix: '97',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '98': GS1AI(
    prefix: '98',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
  '99': GS1AI(
    prefix: '99',
    min: 1,
    max: 30,
    variable: true,
    requiresFnc1: true,
    tipo: 'interno',
  ),
};

/* ─────────────────────────────────────────────────────────────
   BARCODE PARSER
   ───────────────────────────────────────────────────────────── */

class BarcodeParser {
  static const String _fnc1 = '\u001D';

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

  static bool _esGS1(String c) =>
      c.startsWith(']C1') ||
      c.contains(_fnc1) ||
      (c.length > 14 && (c.startsWith('01') || c.startsWith('00')));

  static String _extraerIA(String data, int pos) {
    if (pos + 4 <= data.length &&
        gs1Catalog.containsKey(data.substring(pos, pos + 4))) {
      return data.substring(pos, pos + 4);
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

  static BarcodeData _parseGS1Total(String raw) {
    final data = raw.startsWith(']C1') ? raw.substring(3) : raw;

    if (kDebugMode) {
      print('⚙️ [GS1_ENGINE] Inicio parsing GS1');
      print('DATA: "$data"');
      print('─────────────────────────────────────────────────────────────');
    }

    String? gtin, lote, scc, numPedido, numSerie, gln, cp;
    DateTime? caducidad, produccion, envasado, consumo;
    double? cantidad;

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

      final spec = gs1Catalog[ia]!;
      contador++;

      if (kDebugMode) {
        print('📍 [IA #$contador] $ia (${spec.tipo})');
      }

      i += ia.length;

      final end = spec.variable
          ? _buscarFinCampoVariable(data, i, spec.max)
          : i + spec.max;

      if (end > data.length) {
        final valorRestante = data.substring(i);
        mapa[ia] = valorRestante;
        _asignarValorSegunTipo(
          ia,
          spec.tipo,
          valorRestante,
          (val) => gtin = val,
          (val) => scc = val,
          (val) => lote = val,
          (val) => numSerie = val,
          (val) => numPedido = val,
          (val) => gln = val,
          (val) => cp = val,
          (val) => cantidad = val,
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

      _asignarValorSegunTipo(
        ia,
        spec.tipo,
        valor,
        (val) => gtin = val,
        (val) => scc = val,
        (val) => lote = val,
        (val) => numSerie = val,
        (val) => numPedido = val,
        (val) => gln = val,
        (val) => cp = val,
        (val) => cantidad = val,
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
      print('    ├─ GTIN: ${gtin ?? "NO"}');
      print('    ├─ LOTE: ${lote ?? "NO"}');
      print('    ├─ CADUCIDAD: ${caducidad ?? "NO"}');
      print('    ├─ TOTAL IAs: ${mapa.length}');
      print('═════════════════════════════════════════════════════════════');
    }

    return BarcodeData(
      tipo: TipoCodigo.gs1,
      codigoArticulo: gtin ?? (scc ?? ''),
      lote: lote,
      fechaCaducidad: caducidad,
      fechaProduccion: produccion,
      fechaEnvasado: envasado,
      fechaConsumoPreferente: consumo,
      cantidad: cantidad,
      scc: scc,
      numeroPedido: numPedido,
      numeroSerie: numSerie,
      glnDestino: gln,
      codigoPostal: cp,
      todosLosIAs: mapa,
      rawData: raw,
    );
  }

  static void _asignarValorSegunTipo(
    String ia,
    String tipo,
    String valor,
    Function(String) setGtin,
    Function(String) setScc,
    Function(String) setLote,
    Function(String) setSerie,
    Function(String) setPedido,
    Function(String) setGln,
    Function(String) setCp,
    Function(double) setCantidad,
    Function(String, DateTime?) setFecha,
  ) {
    if (tipo == 'gtin') {
      setGtin(valor.length > 13 ? valor.substring(1) : valor);
    }
    if (tipo == 'sscc') setScc(valor);
    if (tipo == 'lote') setLote(valor);
    if (tipo == 'serie') setSerie(valor);
    if (tipo == 'pedido') setPedido(valor);
    if (tipo == 'gln') setGln(valor);
    if (tipo == 'cp') setCp(valor);
    if (tipo == 'cantidad' || tipo == 'peso') {
      setCantidad(double.tryParse(valor) ?? 0.0);
    }
    if (tipo == 'fecha') {
      setFecha(ia, _parseFechaGS1(valor));
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

  static DateTime? _parseFechaGS1(String f) {
    if (f.length != 6) return null;
    try {
      final yy = int.parse(f.substring(0, 2)) + 2000;
      final mm = int.parse(f.substring(2, 4));
      final dd = int.parse(f.substring(4, 6));
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
}