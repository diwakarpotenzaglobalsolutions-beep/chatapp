import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/entities/block_status_entity.dart';
import '../models/blocked_user_model.dart';
import 'block_remote_data_source.dart';

class BlockRemoteDataSourceImpl implements BlockRemoteDataSource {
  final FirebaseFirestore _firestore;

  BlockRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _blockedRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('blocked_users');
  }

  @override
  Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    required String blockedUserName,
    String blockedUserImage = '',
  }) async {
    if (blockerId == blockedUserId) return;

    final model = BlockedUserModel(
      blockedUserId: blockedUserId,
      blockedUserName: blockedUserName,
      blockedUserImage: blockedUserImage,
      blockedAt: DateTime.now(),
    );

    await _blockedRef(blockerId).doc(blockedUserId).set(model.toJson());
  }

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    await _blockedRef(blockerId).doc(blockedUserId).delete();
  }

  @override
  Stream<List<BlockedUserEntity>> getBlockedUsers(String userId) {
    return _blockedRef(userId)
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BlockedUserModel.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<BlockStatusEntity> watchBlockStatus({
    required String currentUserId,
    required String peerUserId,
  }) {
    if (currentUserId.isEmpty || peerUserId.isEmpty || currentUserId == peerUserId) {
      return Stream.value(const BlockStatusEntity());
    }

    return _combineBlockSnapshots(currentUserId, peerUserId);
  }

  Stream<BlockStatusEntity> _combineBlockSnapshots(
    String currentUserId,
    String peerUserId,
  ) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? mySub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? peerSub;
    final controller = StreamController<BlockStatusEntity>();
    var blockedByMe = false;
    var blockedByPeer = false;

    void emitStatus() {
      if (!controller.isClosed) {
        controller.add(BlockStatusEntity(
          blockedByMe: blockedByMe,
          blockedByPeer: blockedByPeer,
        ));
      }
    }

    controller.onListen = () {
      mySub = _blockedRef(currentUserId).doc(peerUserId).snapshots().listen((snap) {
        blockedByMe = snap.exists;
        emitStatus();
      });
      peerSub = _blockedRef(peerUserId).doc(currentUserId).snapshots().listen((snap) {
        blockedByPeer = snap.exists;
        emitStatus();
      });
    };

    controller.onCancel = () async {
      await mySub?.cancel();
      await peerSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<bool> isBlockedEitherWay(String uid1, String uid2) async {
    if (uid1.isEmpty || uid2.isEmpty || uid1 == uid2) return false;

    final results = await Future.wait([
      _blockedRef(uid1).doc(uid2).get(),
      _blockedRef(uid2).doc(uid1).get(),
    ]);

    return results.any((doc) => doc.exists);
  }
}
