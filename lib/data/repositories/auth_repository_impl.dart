import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signUp({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    return await remoteDataSource.signUp(
      fullName: fullName,
      email: email,
      username: username,
      password: password,
    );
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.signIn(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Stream<UserEntity?> get currentUserStream => remoteDataSource.currentUserStream;

  @override
  Future<UserEntity?> get currentUser => remoteDataSource.currentUser;
}
