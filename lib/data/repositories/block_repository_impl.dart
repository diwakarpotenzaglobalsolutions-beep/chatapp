import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/entities/block_status_entity.dart';
import '../../domain/repositories/block_repository.dart';
import '../datasource/block_remote_data_source.dart';

class BlockRepositoryImpl implements BlockRepository {
  final BlockRemoteDataSource remoteDataSource;

  BlockRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    required String blockedUserName,
    String blockedUserImage = '',
  }) =>
      remoteDataSource.blockUser(
        blockerId: blockerId,
        blockedUserId: blockedUserId,
        blockedUserName: blockedUserName,
        blockedUserImage: blockedUserImage,
      );

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) =>
      remoteDataSource.unblockUser(
        blockerId: blockerId,
        blockedUserId: blockedUserId,
      );

  @override
  Stream<List<BlockedUserEntity>> getBlockedUsers(String userId) =>
      remoteDataSource.getBlockedUsers(userId);

  @override
  Stream<BlockStatusEntity> watchBlockStatus({
    required String currentUserId,
    required String peerUserId,
  }) =>
      remoteDataSource.watchBlockStatus(
        currentUserId: currentUserId,
        peerUserId: peerUserId,
      );

  @override
  Future<bool> isBlockedEitherWay(String uid1, String uid2) =>
      remoteDataSource.isBlockedEitherWay(uid1, uid2);
}
