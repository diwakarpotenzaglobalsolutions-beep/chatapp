import '../entities/chat_room_entity.dart';
import '../repositories/group_repository.dart';

class CreateGroupUseCase {
  final GroupRepository repository;
  CreateGroupUseCase(this.repository);

  Future<String> call({
    required String creatorId,
    required String groupName,
    String? groupDescription,
    String? groupImage,
    required List<String> memberIds,
  }) =>
      repository.createGroup(
        creatorId: creatorId,
        groupName: groupName,
        groupDescription: groupDescription,
        groupImage: groupImage,
        memberIds: memberIds,
      );
}

class UpdateGroupInfoUseCase {
  final GroupRepository repository;
  UpdateGroupInfoUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String adminId,
    String? groupName,
    String? groupDescription,
    String? groupImage,
  }) =>
      repository.updateGroupInfo(
        roomId: roomId,
        adminId: adminId,
        groupName: groupName,
        groupDescription: groupDescription,
        groupImage: groupImage,
      );
}

class AddGroupMembersUseCase {
  final GroupRepository repository;
  AddGroupMembersUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String adminId,
    required List<String> memberIds,
  }) =>
      repository.addMembers(
        roomId: roomId,
        adminId: adminId,
        memberIds: memberIds,
      );
}

class RemoveGroupMemberUseCase {
  final GroupRepository repository;
  RemoveGroupMemberUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String adminId,
    required String memberId,
  }) =>
      repository.removeMember(
        roomId: roomId,
        adminId: adminId,
        memberId: memberId,
      );
}

class LeaveGroupUseCase {
  final GroupRepository repository;
  LeaveGroupUseCase(this.repository);

  Future<void> call({required String roomId, required String userId}) =>
      repository.leaveGroup(roomId: roomId, userId: userId);
}

class TransferGroupAdminUseCase {
  final GroupRepository repository;
  TransferGroupAdminUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String currentAdminId,
    required String newAdminId,
  }) =>
      repository.transferAdmin(
        roomId: roomId,
        currentAdminId: currentAdminId,
        newAdminId: newAdminId,
      );
}

class SearchGroupsUseCase {
  final GroupRepository repository;
  SearchGroupsUseCase(this.repository);

  Stream<List<ChatRoomEntity>> call(String uid, String query) =>
      repository.searchGroups(uid, query);
}
