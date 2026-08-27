import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasource/profile_remote_data_source.dart';
import '../models/user_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> getUserProfile(String uid) async {
    return await remoteDataSource.getUserProfile(uid);
  }

  @override
  Future<void> updateUserProfile(UserEntity user) async {
    await remoteDataSource.updateUserProfile(UserModel.fromEntity(user));
  }

  @override
  Future<String> uploadProfilePicture(String uid, String filePath) async {
    return await remoteDataSource.uploadProfilePicture(uid, filePath);
  }

  @override
  Future<void> removeProfilePicture(String uid) async {
    await remoteDataSource.removeProfilePicture(uid);
  }
}
