class ServerException implements Exception {
  final String message;
  
  const ServerException([this.message = 'Error desconocido del servidor']);
  
  @override
  String toString() => 'ServerException: $message';
}

/// Excepción lanzada cuando el recurso solicitado no se encuentra (HTTP 404).
class NotFoundException implements Exception {
  final String message;
  
  const NotFoundException([this.message = 'Recurso no encontrado (404)']);
  
  @override
  String toString() => 'NotFoundException: $message';
}

/// Excepción lanzada cuando hay un problema de autenticación o acceso.
class UnauthorizedException implements Exception {
  final String message;
  
  const UnauthorizedException([this.message = 'No autorizado (401)']);
  
  @override
  String toString() => 'UnauthorizedException: $message';
}

/// --- Excepciones de Caché (Datos Locales) ---

class CacheException implements Exception {
  final String message;
  
  const CacheException([this.message = 'Error de caché o datos locales']);
  
  @override
  String toString() => 'CacheException: $message';
}

/// Excepción lanzada cuando la caché está vacía o el dato no existe localmente.
class NoLocalDataException implements CacheException {
  @override
  final String message;
  
  const NoLocalDataException([this.message = 'No se encontraron datos locales']);
  
  @override
  String toString() => 'NoLocalDataException: $message';
}