// ignore_for_file: avoid_print
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<bool> login(String nombre, String password) async {
    try {
      final token = await remoteDataSource.loginWithToken(nombre, password);

      if (token != null) {
        await localDataSource.saveToken(token);
        final userCode = await remoteDataSource.getUserCodeFromToken(token);
        await localDataSource.saveUserCode(userCode);
        return true;
      }
      return false;
    } catch (e) {
      print('Error en AuthRepositoryImpl.login: $e');
      return false;
    }
  }

  @override
  Future<void> clearSession() async {
    await localDataSource.clearUserCode();
    await localDataSource.clearToken();
  }
}