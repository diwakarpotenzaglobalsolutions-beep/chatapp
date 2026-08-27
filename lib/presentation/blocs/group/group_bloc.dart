import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/chat_room_entity.dart';
import '../../../domain/usecases/group_usecases.dart';

abstract class GroupEvent extends Equatable {
  const GroupEvent();
  @override
  List<Object?> get props => [];
}

class CreateGroupRequested extends GroupEvent {
  final String creatorId;
  final String groupName;
  final String? groupDescription;
  final String? groupImage;
  final List<String> memberIds;

  const CreateGroupRequested({
    required this.creatorId,
    required this.groupName,
    this.groupDescription,
    this.groupImage,
    required this.memberIds,
  });

  @override
  List<Object?> get props => [creatorId, groupName, groupDescription, groupImage, memberIds];
}

class UpdateGroupInfoRequested extends GroupEvent {
  final String roomId;
  final String adminId;
  final String? groupName;
  final String? groupDescription;
  final String? groupImage;

  const UpdateGroupInfoRequested({
    required this.roomId,
    required this.adminId,
    this.groupName,
    this.groupDescription,
    this.groupImage,
  });

  @override
  List<Object?> get props => [roomId, adminId, groupName, groupDescription, groupImage];
}

class AddGroupMembersRequested extends GroupEvent {
  final String roomId;
  final String adminId;
  final List<String> memberIds;

  const AddGroupMembersRequested({
    required this.roomId,
    required this.adminId,
    required this.memberIds,
  });

  @override
  List<Object?> get props => [roomId, adminId, memberIds];
}

class RemoveGroupMemberRequested extends GroupEvent {
  final String roomId;
  final String adminId;
  final String memberId;

  const RemoveGroupMemberRequested({
    required this.roomId,
    required this.adminId,
    required this.memberId,
  });

  @override
  List<Object?> get props => [roomId, adminId, memberId];
}

class LeaveGroupRequested extends GroupEvent {
  final String roomId;
  final String userId;

  const LeaveGroupRequested({required this.roomId, required this.userId});

  @override
  List<Object?> get props => [roomId, userId];
}

class TransferGroupAdminRequested extends GroupEvent {
  final String roomId;
  final String currentAdminId;
  final String newAdminId;

  const TransferGroupAdminRequested({
    required this.roomId,
    required this.currentAdminId,
    required this.newAdminId,
  });

  @override
  List<Object?> get props => [roomId, currentAdminId, newAdminId];
}

class SubscribeToGroupSearch extends GroupEvent {
  final String uid;
  final String query;

  const SubscribeToGroupSearch({required this.uid, required this.query});

  @override
  List<Object?> get props => [uid, query];
}

class GroupSearchUpdated extends GroupEvent {
  final List<ChatRoomEntity> groups;

  const GroupSearchUpdated(this.groups);

  @override
  List<Object?> get props => [groups];
}

abstract class GroupState extends Equatable {
  const GroupState();
  @override
  List<Object?> get props => [];
}

class GroupInitial extends GroupState {}

class GroupLoading extends GroupState {}

class GroupCreated extends GroupState {
  final String roomId;

  const GroupCreated(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class GroupActionSuccess extends GroupState {
  final String message;

  const GroupActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupSearchLoaded extends GroupState {
  final List<ChatRoomEntity> groups;
  final String query;

  const GroupSearchLoaded(this.groups, {this.query = ''});

  @override
  List<Object?> get props => [groups, query];
}

class GroupFailure extends GroupState {
  final String error;

  const GroupFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final CreateGroupUseCase _createGroupUseCase;
  final UpdateGroupInfoUseCase _updateGroupInfoUseCase;
  final AddGroupMembersUseCase _addGroupMembersUseCase;
  final RemoveGroupMemberUseCase _removeGroupMemberUseCase;
  final LeaveGroupUseCase _leaveGroupUseCase;
  final TransferGroupAdminUseCase _transferGroupAdminUseCase;
  final SearchGroupsUseCase _searchGroupsUseCase;

  StreamSubscription<List<ChatRoomEntity>>? _searchSubscription;

  GroupBloc({
    required CreateGroupUseCase createGroupUseCase,
    required UpdateGroupInfoUseCase updateGroupInfoUseCase,
    required AddGroupMembersUseCase addGroupMembersUseCase,
    required RemoveGroupMemberUseCase removeGroupMemberUseCase,
    required LeaveGroupUseCase leaveGroupUseCase,
    required TransferGroupAdminUseCase transferGroupAdminUseCase,
    required SearchGroupsUseCase searchGroupsUseCase,
  })  : _createGroupUseCase = createGroupUseCase,
        _updateGroupInfoUseCase = updateGroupInfoUseCase,
        _addGroupMembersUseCase = addGroupMembersUseCase,
        _removeGroupMemberUseCase = removeGroupMemberUseCase,
        _leaveGroupUseCase = leaveGroupUseCase,
        _transferGroupAdminUseCase = transferGroupAdminUseCase,
        _searchGroupsUseCase = searchGroupsUseCase,
        super(GroupInitial()) {
    on<CreateGroupRequested>(_onCreateGroup);
    on<UpdateGroupInfoRequested>(_onUpdateGroupInfo);
    on<AddGroupMembersRequested>(_onAddMembers);
    on<RemoveGroupMemberRequested>(_onRemoveMember);
    on<LeaveGroupRequested>(_onLeaveGroup);
    on<TransferGroupAdminRequested>(_onTransferAdmin);
    on<SubscribeToGroupSearch>(_onSubscribeToGroupSearch);
    on<GroupSearchUpdated>(_onGroupSearchUpdated);
  }

  Future<void> _onCreateGroup(CreateGroupRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      final roomId = await _createGroupUseCase(
        creatorId: event.creatorId,
        groupName: event.groupName,
        groupDescription: event.groupDescription,
        groupImage: event.groupImage,
        memberIds: event.memberIds,
      );
      emit(GroupCreated(roomId));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onUpdateGroupInfo(UpdateGroupInfoRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      await _updateGroupInfoUseCase(
        roomId: event.roomId,
        adminId: event.adminId,
        groupName: event.groupName,
        groupDescription: event.groupDescription,
        groupImage: event.groupImage,
      );
      emit(const GroupActionSuccess('Group updated successfully'));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAddMembers(AddGroupMembersRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      await _addGroupMembersUseCase(
        roomId: event.roomId,
        adminId: event.adminId,
        memberIds: event.memberIds,
      );
      emit(const GroupActionSuccess('Members added successfully'));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRemoveMember(RemoveGroupMemberRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      await _removeGroupMemberUseCase(
        roomId: event.roomId,
        adminId: event.adminId,
        memberId: event.memberId,
      );
      emit(const GroupActionSuccess('Member removed'));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLeaveGroup(LeaveGroupRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      await _leaveGroupUseCase(roomId: event.roomId, userId: event.userId);
      emit(const GroupActionSuccess('You left the group'));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onTransferAdmin(TransferGroupAdminRequested event, Emitter<GroupState> emit) async {
    emit(GroupLoading());
    try {
      await _transferGroupAdminUseCase(
        roomId: event.roomId,
        currentAdminId: event.currentAdminId,
        newAdminId: event.newAdminId,
      );
      emit(const GroupActionSuccess('Admin transferred'));
    } catch (e) {
      emit(GroupFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSubscribeToGroupSearch(
    SubscribeToGroupSearch event,
    Emitter<GroupState> emit,
  ) async {
    emit(GroupLoading());
    await _searchSubscription?.cancel();
    _searchSubscription = _searchGroupsUseCase(event.uid, event.query).listen(
      (groups) => add(GroupSearchUpdated(groups)),
      onError: (e) => emit(GroupFailure(e.toString())),
    );
  }

  void _onGroupSearchUpdated(GroupSearchUpdated event, Emitter<GroupState> emit) {
    emit(GroupSearchLoaded(event.groups));
  }

  @override
  Future<void> close() {
    _searchSubscription?.cancel();
    return super.close();
  }
}
