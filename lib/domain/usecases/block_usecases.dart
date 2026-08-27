import '../entities/blocked_user_entity.dart';
import '../entities/block_status_entity.dart';
import '../repositories/block_repository.dart';

class BlockUserUseCase {
  final BlockRepository repository;
  BlockUserUseCase(this.repository);

  Future<void> call({
    required String blockerId,
    required String blockedUserId,
    required String blockedUserName,
    String blockedUserImage = '',
  }) =>
      repository.blockUser(
        blockerId: blockerId,
        blockedUserId: blockedUserId,
        blockedUserName: blockedUserName,
        blockedUserImage: blockedUserImage,
      );
}

class UnblockUserUseCase {
  final BlockRepository repository;
  UnblockUserUseCase(this.repository);

  Future<void> call({
    required String blockerId,
    required String blockedUserId,
  }) =>
      repository.unblockUser(
        blockerId: blockerId,
        blockedUserId: blockedUserId,
      );
}

class GetBlockedUsersUseCase {
  final BlockRepository repository;
  GetBlockedUsersUseCase(this.repository);

  Stream<List<BlockedUserEntity>> call(String userId) =>
      repository.getBlockedUsers(userId);
}

class WatchBlockStatusUseCase {
  final BlockRepository repository;
  WatchBlockStatusUseCase(this.repository);

  Stream<BlockStatusEntity> call({
    required String currentUserId,
    required String peerUserId,
  }) =>
      repository.watchBlockStatus(
        currentUserId: currentUserId,
        peerUserId: peerUserId,
      );
}

class IsBlockedEitherWayUseCase {
  final BlockRepository repository;
  IsBlockedEitherWayUseCase(this.repository);

  Future<bool> call(String uid1, String uid2) =>
      repository.isBlockedEitherWay(uid1, uid2);
}
