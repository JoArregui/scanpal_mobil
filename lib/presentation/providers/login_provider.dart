// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/usecases/clear_session_usecase.dart';
import '../../core/services/catalog_version_service.dart';
import 'actualizar_articulo_provider.dart';
import 'lector_provider.dart';

enum LoginState { initial, loading, success, error }

class LoginProvider with ChangeNotifier {
  final ClearSessionUseCase _clearSessionUseCase;
  final AuthRemoteDataSource _authRemoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;
  final CatalogVersionService _catalogVersionService;

  LoginProvider(
    this._clearSessionUseCase,
    this._authRemoteDataSource,
    this._authLocalDataSource,
    this._catalogVersionService,
  );

  LoginState _state = LoginState.initial;
  String _errorMessage = '';
  bool _isSuperAdmin = false;
  String? _token;
  DateTime? _tokenExpiration;

  LoginState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isSuperAdmin => _isSuperAdmin;
  String? get token => _token;
  DateTime? get tokenExpiration => _tokenExpiration;

  void setSuperAdminManually() {
    _isSuperAdmin = true;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _clearSessionUseCase.execute();
      print('✅ [LoginProvider] Sesión persistente limpiada.');
    } catch (e) {
      print('⚠️ [LoginProvider] Error al limpiar la sesión persistente: $e');
    }

    _token = null;
    _tokenExpiration = null;
    _state = LoginState.initial;
    _errorMessage = '';
    _isSuperAdmin = false;
    notifyListeners();
  }

  Future<void> logear(
    String nombre,
    String password,
    LectorProvider lectorProvider,
    ActualizarArticuloProvider actualizarArticuloProvider,
  ) async {
    _state = LoginState.loading;
    _errorMessage = '';
    _isSuperAdmin = false;
    _token = null;
    _tokenExpiration = null;
    notifyListeners();

    try {
      // Usar el nuevo método de login con token
      final String? token = await _authRemoteDataSource.loginWithToken(
        nombre,
        password,
      );

      if (token != null) {
        _token = token;
        _tokenExpiration = _calcularExpiracion(token);
        await _authLocalDataSource.saveToken(token);

        // Obtener el userCode desde el token
        final int userCode = await _authRemoteDataSource.getUserCodeFromToken(
          token,
        );
        await _authLocalDataSource.saveUserCode(userCode);

        await _catalogVersionService.refreshIfVersionChanged(
          actualizarArticuloProvider.actualizarCatalogoPorCambioDeVersion,
        );

        if (nombre.toLowerCase() == AppConstants.adminUser.toLowerCase()) {
          _isSuperAdmin = true;
        }

        // === PASO CLAVE ===
        // Forzamos al LectorProvider a leer el nuevo ID dinámicamente
        await lectorProvider.refrescarUsuarioDinamico(userCode: userCode);

        _state = LoginState.success;
      } else {
        _errorMessage = 'Usuario o contraseña incorrectos. Token no obtenido.';
        _state = LoginState.error;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = LoginState.error;
    }

    notifyListeners();
  }

  DateTime? _calcularExpiracion(String token) {
    // Si el token es JWT, podemos decodificar el payload para obtener la expiración
    // Formato JWT: header.payload.signature, el payload tiene el claim "exp"
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        // Obtener el claim "exp" del payload JWT para determinar expiración.
        // Parseo completo quedado pendiente; usamos validez por defecto de 1 hora.
        return null; // Implementación compleja, por ahora null
      }
    } catch (e) {
      // No es un JWT válido o error al decodificar
    }
    // Por defecto, token válido 1 hora según el requisito
    return DateTime.now().add(const Duration(hours: 1));
  }
}
