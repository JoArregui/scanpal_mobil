import '../repositories/auth_repository.dart';

class ClearSessionUseCase {
  final AuthRepository repository;

  ClearSessionUseCase(this.repository);

  Future<void> execute() async {
    return repository.clearSession();
  }
}
