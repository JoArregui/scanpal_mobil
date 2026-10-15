class AppConstants {
  // Configuración de API
  static const String baseUrl = 'https://scanpal.ecomputer.es';
  
  // Sincronización y Batching
  static const int batchSize = 500;       // Registros por paquete
  static const int maxRetries = 3;        // Intentos por cada paquete
  static const int retryDelaySeconds = 2; // Espera entre reintentos
  static const int apiTimeoutSeconds = 10; // Tiempo máximo de espera de respuesta

  // Configuración de Usuarios
  static const String adminUser = 'admin0';

  // Rutas de Sonidos (Assets)
  static const String soundWarningDescatalogado = 'sounds/Articulo_descatalogado.mp3';
  static const String soundErrorNoEncontrado = 'sounds/Articulo_no_local.mp3';
  // FIFO: aviso de caducidad (una sola reproducción por escaneo caducado).
  static const String soundAvisoCaducidad = 'sounds/Caducidad.mp3';
}