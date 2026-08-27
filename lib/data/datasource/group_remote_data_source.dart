import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_room_model.dart';
import '../../domain/entities/chat_room_type.dart';
import '../../core/services/notification_service.dart';

abstract class GroupRemoteDataSource {
  Future<String> createGroup({
    required String creatorId,
    required String groupName,
    String? groupDescription,
    String? groupImage,
    required List<String> memberIds,
  });

  Future<void> updateGroupInfo({
    required String roomId,
    required String adminId,
    String? groupName,
    String? groupDescription,
    String? groupImage,
  });

  Future<void> addMembers({
    required String roomId,
    required String adminId,
    required List<String> memberIds,
  });

  Future<void> removeMember({
    required String roomId,
    required String adminId,
    required String memberId,
  });

  Future<void> leaveGroup({
    required String roomId,
    required String userId,
  });

  Future<void> transferAdmin({
    required String roomId,
    required String currentAdminId,
    required String newAdminId,
  });

  Stream<List<ChatRoomModel>> searchGroups(String uid, String query);
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService;

  GroupRemoteDataSourceImpl({required NotificationService notificationService})
      : _notificationService = notificationService;

  @override
  Future<String> createGroup({
    required String creatorId,
    required String groupName,
    String? groupDescription,
    String? groupImage,
    required List<String> memberIds,
  }) async {
    final allMembers = {creatorId, ...memberIds}.toList();
    final roomId = _firestore.collection('chat_rooms').doc().id;

    final unreadCount = {for (final id in allMembers) id: 0};
    final typingStatus = {for (final id in allMembers) id: false};

    final group = ChatRoomModel(
      roomId: roomId,
      roomType: ChatRoomType.group,
      participants: allMembers,
      unreadCount: unreadCount,
      typingStatus: typingStatus,
      updatedAt: DateTime.now(),
      groupName: groupName,
      groupDescription: groupDescription,
      groupImage: groupImage,
      adminIds: [creatorId],
      createdBy: creatorId,
    );

    await _firestore.collection('chat_rooms').doc(roomId).set(group.toJson());
    await _notificationService.subscribeToTopic('group_$roomId');

    return roomId;
  }

  @override
  Future<void> updateGroupInfo({
    required String roomId,
    required String adminId,
    String? groupName,
    String? groupDescription,
    String? groupImage,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final adminIds = List<String>.from(roomDoc.data()!['adminIds'] as List? ?? []);
    if (!adminIds.contains(adminId)) throw Exception('Only admins can edit group info');

    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (groupName != null) updates['groupName'] = groupName;
    if (groupDescription != null) updates['groupDescription'] = groupDescription;
    if (groupImage != null) updates['groupImage'] = groupImage;

    await roomRef.update(updates);
  }

  @override
  Future<void> addMembers({
    required String roomId,
    required String adminId,
    required List<String> memberIds,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final data = roomDoc.data()!;
    final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
    if (!adminIds.contains(adminId)) throw Exception('Only admins can add members');

    final participants = List<String>.from(data['participants'] as List? ?? []);
    final unreadCount = Map<String, int>.from(data['unreadCount'] as Map? ?? {});
    final typingStatus = Map<String, bool>.from(data['typingStatus'] as Map? ?? {});

    for (final memberId in memberIds) {
      if (!participants.contains(memberId)) {
        participants.add(memberId);
        unreadCount[memberId] = 0;
        typingStatus[memberId] = false;
        await _notificationService.subscribeToTopic('group_$roomId');
      }
    }

    await roomRef.update({
      'participants': participants,
      'unreadCount': unreadCount,
      'typingStatus': typingStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removeMember({
    required String roomId,
    required String adminId,
    required String memberId,
  }) async {
    await _removeMemberInternal(roomId, adminId, memberId, requireAdmin: true);
  }

  @override
  Future<void> leaveGroup({
    required String roomId,
    required String userId,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final data = roomDoc.data()!;
    final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
    final participants = List<String>.from(data['participants'] as List? ?? []);

    if (adminIds.contains(userId) && adminIds.length == 1 && participants.length > 1) {
      final newAdmin = participants.firstWhere((id) => id != userId);
      adminIds.remove(userId);
      adminIds.add(newAdmin);
    } else {
      adminIds.remove(userId);
    }

    await _removeMemberInternal(roomId, userId, userId, requireAdmin: false, adminIds: adminIds);
    await _notificationService.unsubscribeFromTopic('group_$roomId');
  }

  Future<void> _removeMemberInternal(
    String roomId,
    String actorId,
    String memberId, {
    required bool requireAdmin,
    List<String>? adminIds,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final data = roomDoc.data()!;
    final currentAdminIds = adminIds ?? List<String>.from(data['adminIds'] as List? ?? []);
    if (requireAdmin && !currentAdminIds.contains(actorId)) {
      throw Exception('Only admins can remove members');
    }

    final participants = List<String>.from(data['participants'] as List? ?? []);
    participants.remove(memberId);

    final unreadCount = Map<String, int>.from(data['unreadCount'] as Map? ?? {});
    final typingStatus = Map<String, bool>.from(data['typingStatus'] as Map? ?? {});
    unreadCount.remove(memberId);
    typingStatus.remove(memberId);
    currentAdminIds.remove(memberId);

    await roomRef.update({
      'participants': participants,
      'adminIds': currentAdminIds,
      'unreadCount': unreadCount,
      'typingStatus': typingStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> transferAdmin({
    required String roomId,
    required String currentAdminId,
    required String newAdminId,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final data = roomDoc.data()!;
    final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
    final participants = List<String>.from(data['participants'] as List? ?? []);

    if (!adminIds.contains(currentAdminId)) throw Exception('Only admins can transfer admin');
    if (!participants.contains(newAdminId)) throw Exception('User is not a group member');

    if (!adminIds.contains(newAdminId)) adminIds.add(newAdminId);

    await roomRef.update({
      'adminIds': adminIds,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Stream<List<ChatRoomModel>> searchGroups(String uid, String query) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .where('roomType', isEqualTo: ChatRoomType.group.name)
        .snapshots()
        .map((snapshot) {
          var groups = snapshot.docs
              .map((doc) => ChatRoomModel.fromJson(doc.data(), doc.id))
              .toList();

          if (query.trim().isNotEmpty) {
            final q = query.toLowerCase();
            groups = groups
                .where((g) => (g.groupName ?? '').toLowerCase().contains(q))
                .toList();
          }

          groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return groups;
        });
  }
}
