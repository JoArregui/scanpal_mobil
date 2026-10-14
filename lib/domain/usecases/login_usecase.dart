import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<bool> execute(String nombre, String password) async {
    if (nombre.isEmpty || password.isEmpty) {
      return false;
    }

    return await repository.login(nombre, password);
  }
}
