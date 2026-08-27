import '../entities/blocked_user_entity.dart';
import '../entities/block_status_entity.dart';

abstract class BlockRepository {
  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    required String blockedUserName,
    String blockedUserImage = '',
  });

  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  });

  Stream<List<BlockedUserEntity>> getBlockedUsers(String userId);

  Stream<BlockStatusEntity> watchBlockStatus({
    required String currentUserId,
    required String peerUserId,
  });

  Future<bool> isBlockedEitherWay(String uid1, String uid2);
}
