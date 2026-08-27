import '../../domain/entities/chat_room_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasource/group_remote_data_source.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;

  GroupRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String> createGroup({
    required String creatorId,
    required String groupName,
    String? groupDescription,
    String? groupImage,
    required List<String> memberIds,
  }) =>
      remoteDataSource.createGroup(
        creatorId: creatorId,
        groupName: groupName,
        groupDescription: groupDescription,
        groupImage: groupImage,
        memberIds: memberIds,
      );

  @override
  Future<void> updateGroupInfo({
    required String roomId,
    required String adminId,
    String? groupName,
    String? groupDescription,
    String? groupImage,
  }) =>
      remoteDataSource.updateGroupInfo(
        roomId: roomId,
        adminId: adminId,
        groupName: groupName,
        groupDescription: groupDescription,
        groupImage: groupImage,
      );

  @override
  Future<void> addMembers({
    required String roomId,
    required String adminId,
    required List<String> memberIds,
  }) =>
      remoteDataSource.addMembers(
        roomId: roomId,
        adminId: adminId,
        memberIds: memberIds,
      );

  @override
  Future<void> removeMember({
    required String roomId,
    required String adminId,
    required String memberId,
  }) =>
      remoteDataSource.removeMember(
        roomId: roomId,
        adminId: adminId,
        memberId: memberId,
      );

  @override
  Future<void> leaveGroup({
    required String roomId,
    required String userId,
  }) =>
      remoteDataSource.leaveGroup(roomId: roomId, userId: userId);

  @override
  Future<void> transferAdmin({
    required String roomId,
    required String currentAdminId,
    required String newAdminId,
  }) =>
      remoteDataSource.transferAdmin(
        roomId: roomId,
        currentAdminId: currentAdminId,
        newAdminId: newAdminId,
      );

  @override
  Stream<List<ChatRoomEntity>> searchGroups(String uid, String query) =>
      remoteDataSource.searchGroups(uid, query);
}
