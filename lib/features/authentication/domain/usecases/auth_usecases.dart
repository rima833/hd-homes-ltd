import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserProfile> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({bool everywhere = false}) {
    return _repository.signOut(everywhere: everywhere);
  }
}

class ResolveIdentityUseCase {
  const ResolveIdentityUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserProfile?> call() => _repository.fetchCurrentProfile();
}
