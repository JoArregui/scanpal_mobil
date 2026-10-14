abstract class AuthRepository {
  Future<bool> login(String nombre, String password);

  Future<void> clearSession();
}
