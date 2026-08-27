import '../entities/chat_room_entity.dart';

abstract class GroupRepository {
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

  Stream<List<ChatRoomEntity>> searchGroups(String uid, String query);
}
