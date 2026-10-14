import '../repositories/articulo_repository.dart';
import '../../core/sync_progress.dart';

class SincronizarCatalogoUseCase {
  final ArticuloRepository repository;

  SincronizarCatalogoUseCase(this.repository);

  /// Expone el flujo de progreso para que la UI pueda escuchar
  /// el avance del Isolate (0% a 100%) en tiempo real.
  Stream<SyncProgress> get progressStream => repository.syncProgressStream;

  /// Ejecuta la sincronización masiva desde el servidor remoto.
  ///
  /// Este método coordina:
  /// 1. La descarga de datos desde el Servidor.
  /// 2. La clasificación de métricas (Activos/Descatalogados/Totales).
  /// 3. La inserción atómica mediante Isolates.
  /// 4. El guardado de metadatos para el Dashboard.
  Future<void> execute() async {
    // Llamamos al método del repositorio que orquesta todo el flujo

    await repository.sincronizarArticulos();
  }
}
