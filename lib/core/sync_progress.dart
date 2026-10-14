class SyncProgress {
  final int procesados;
  final int total;
  final double porcentaje;
  final double articulosPorSegundo;
  final Duration elapsed;

  SyncProgress({
    required this.procesados,
    required this.total,
    required this.porcentaje,
    required this.articulosPorSegundo,
    required this.elapsed,
  });
}
