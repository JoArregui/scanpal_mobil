import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../domain/usecases/clear_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import 'lector_provider.dart'; 

enum LoginState { initial, loading, success, error }

class LoginProvider with ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final ClearSessionUseCase _clearSessionUseCase;

  LoginProvider(this._loginUseCase, this._clearSessionUseCase);

  LoginState _state = LoginState.initial;
  String _errorMessage = '';
  bool _isSuperAdmin = false;

  LoginState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isSuperAdmin => _isSuperAdmin;

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

    _state = LoginState.initial;
    _errorMessage = '';
    _isSuperAdmin = false;
    notifyListeners();
  }

  // AHORA RECIBE EL LectorProvider PARA SINCRONIZARLOS
  Future<void> logear(String nombre, String password, LectorProvider lectorProvider) async {
    _state = LoginState.loading;
    _errorMessage = '';
    _isSuperAdmin = false;
    notifyListeners();

    try {
      final isSuccessful = await _loginUseCase.execute(nombre, password);
      
      if (isSuccessful) {
        if (nombre.toLowerCase() == AppConstants.adminUser.toLowerCase()) {
          _isSuperAdmin = true;
        }

        // === PASO CLAVE ===
        // Antes de marcar success, forzamos al LectorProvider a leer el nuevo ID
        await lectorProvider.refrescarUsuarioDinamico();

        _state = LoginState.success;
      } else {
        _errorMessage = 'Usuario o contraseña incorrectos.';
        _state = LoginState.error;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión. Intente de nuevo.';
      _state = LoginState.error;
    }

    notifyListeners();
  }
}