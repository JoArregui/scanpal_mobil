import '../../domain/entities/lectura.dart';
import 'package:flutter/material.dart';

/// Nivel de aviso FIFO por cercanía de caducidad.
enum NivelAvisoCaducidad {
  /// Sin fecha o a más de 7 días: sin aviso.
  ok,
  /// Caduca en 4-7 días.
  semana,
  /// Caduca en 1-3 días.
  proxima,
  /// Caduca hoy.
  hoy,
  /// Ya caducada (ayer o antes).
  caducada,
}

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

  // ================== FIFO por fecha de caducidad ==================
  // Política rama FIFO: sin fecha => al final y sin aviso; con fecha =>
  // primero la más próxima. Solo informativo, sin bloqueos.

  /// Fecha de caducidad (AI 17 o fallback AI 15 desde el parser). Null si no hay.
  DateTime? get fechaCaducidad => lectura.fechaCaducidad;

  bool get tieneCaducidad => lectura.fechaCaducidad != null;

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Caducada si la fecha (solo día) es anterior a hoy.
  bool get estaCaducada {
    final f = lectura.fechaCaducidad;
    if (f == null) return false;
    return _soloFecha(f).isBefore(_soloFecha(DateTime.now()));
  }

  /// Nivel de aviso según días restantes: pasado/hoy/1-3/4-7/>7 o sin fecha.
  NivelAvisoCaducidad get nivelAvisoCaducidad {
    final d = diasParaCaducar;
    if (d == null) return NivelAvisoCaducidad.ok;
    if (d < 0) return NivelAvisoCaducidad.caducada;
    if (d == 0) return NivelAvisoCaducidad.hoy;
    if (d <= 3) return NivelAvisoCaducidad.proxima;
    if (d <= 7) return NivelAvisoCaducidad.semana;
    return NivelAvisoCaducidad.ok;
  }

  /// true si hay algún aviso (caducada, hoy o dentro de 7 días).
  bool get avisaCaducidad =>
      nivelAvisoCaducidad != NivelAvisoCaducidad.ok;

  /// Color del aviso según nivel (rojo → naranja → ámbar).
  Color get colorAvisoCaducidad {
    switch (nivelAvisoCaducidad) {
      case NivelAvisoCaducidad.caducada:
        return Colors.red;
      case NivelAvisoCaducidad.hoy:
        return Colors.deepOrange;
      case NivelAvisoCaducidad.proxima:
        return Colors.orange;
      case NivelAvisoCaducidad.semana:
        return Colors.amber.shade700;
      case NivelAvisoCaducidad.ok:
        return Colors.grey;
    }
  }

  /// Opacidad del fondo de fila según nivel.
  double get fondoAvisoCaducidad {
    switch (nivelAvisoCaducidad) {
      case NivelAvisoCaducidad.caducada:
      case NivelAvisoCaducidad.hoy:
        return 0.12;
      case NivelAvisoCaducidad.proxima:
        return 0.10;
      case NivelAvisoCaducidad.semana:
        return 0.07;
      case NivelAvisoCaducidad.ok:
        return 0.0;
    }
  }

  /// Días restantes (negativo si caducada). Null si no hay fecha.
  int? get diasParaCaducar {
    final f = lectura.fechaCaducidad;
    if (f == null) return null;
    return _soloFecha(f).difference(_soloFecha(DateTime.now())).inDays;
  }

  /// Texto corto dd/MM/yy o '-' si no hay fecha.
  String get caducidadCorta {
    final f = lectura.fechaCaducidad;
    if (f == null) return '-';
    final dd = f.day.toString().padLeft(2, '0');
    final mm = f.month.toString().padLeft(2, '0');
    final yy = (f.year % 100).toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  /// Comparador FIFO: con fecha primero (la más próxima antes),
  /// sin fecha al final; desempate por fecha de registro más antigua.
  static int compararFifo(LecturaViewModel a, LecturaViewModel b) {
    final fa = a.lectura.fechaCaducidad;
    final fb = b.lectura.fechaCaducidad;
    if (fa == null && fb == null) {
      return a.lectura.fechaRegistro.compareTo(b.lectura.fechaRegistro);
    }
    if (fa == null) return 1;
    if (fb == null) return -1;
    final c = fa.compareTo(fb);
    if (c != 0) return c;
    return a.lectura.fechaRegistro.compareTo(b.lectura.fechaRegistro);
  }

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
