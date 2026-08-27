import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository repository;
  SignUpUseCase(this.repository);

  Future<UserEntity> call({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) {
    return repository.signUp(
      fullName: fullName,
      email: email,
      username: username,
      password: password,
    );
  }
}

class SignInUseCase {
  final AuthRepository repository;
  SignInUseCase(this.repository);

  Future<UserEntity> call({
    required String email,
    required String password,
  }) {
    return repository.signIn(email: email, password: password);
  }
}

class SignOutUseCase {
  final AuthRepository repository;
  SignOutUseCase(this.repository);

  Future<void> call() {
    return repository.signOut();
  }
}

class ForgotPasswordUseCase {
  final AuthRepository repository;
  ForgotPasswordUseCase(this.repository);

  Future<void> call(String email) {
    return repository.sendPasswordResetEmail(email);
  }
}

class ChangePasswordUseCase {
  final AuthRepository repository;
  ChangePasswordUseCase(this.repository);

  Future<void> call({
    required String currentPassword,
    required String newPassword,
  }) {
    return repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}

class GetCurrentUserUseCase {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  Future<UserEntity?> call() {
    return repository.currentUser;
  }
}

class GetCurrentUserStreamUseCase {
  final AuthRepository repository;
  GetCurrentUserStreamUseCase(this.repository);

  Stream<UserEntity?> call() {
    return repository.currentUserStream;
  }
}
