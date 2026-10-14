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
      final userCode = await remoteDataSource.login(nombre, password);

      if (userCode > 0) {
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
    return await localDataSource.clearUserCode();
  }
}
