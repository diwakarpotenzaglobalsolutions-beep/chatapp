import '../entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class GetUserProfileUseCase {
  final ProfileRepository repository;
  GetUserProfileUseCase(this.repository);

  Future<UserEntity> call(String uid) {
    return repository.getUserProfile(uid);
  }
}

class UpdateUserProfileUseCase {
  final ProfileRepository repository;
  UpdateUserProfileUseCase(this.repository);

  Future<void> call(UserEntity user) {
    return repository.updateUserProfile(user);
  }
}

class UploadProfilePictureUseCase {
  final ProfileRepository repository;
  UploadProfilePictureUseCase(this.repository);

  Future<String> call(String uid, String filePath) {
    return repository.uploadProfilePicture(uid, filePath);
  }
}

class RemoveProfilePictureUseCase {
  final ProfileRepository repository;
  RemoveProfilePictureUseCase(this.repository);

  Future<void> call(String uid) {
    return repository.removeProfilePicture(uid);
  }
}
