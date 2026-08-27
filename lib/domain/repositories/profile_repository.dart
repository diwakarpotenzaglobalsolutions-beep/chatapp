import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity> getUserProfile(String uid);
  Future<void> updateUserProfile(UserEntity user);
  Future<String> uploadProfilePicture(String uid, String filePath);
  Future<void> removeProfilePicture(String uid);
}
