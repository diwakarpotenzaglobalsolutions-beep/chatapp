import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signUp({
    required String fullName,
    required String email,
    required String username,
    required String password,
  });

  Future<UserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Stream<UserEntity?> get currentUserStream;
  Future<UserEntity?> get currentUser;
}
