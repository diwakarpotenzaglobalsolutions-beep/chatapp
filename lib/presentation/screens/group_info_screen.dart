import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/theme.dart';
import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/group/group_bloc.dart';
import '../blocs/profile/profile_bloc.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/upload/upload_bloc.dart';

class GroupInfoScreen extends StatefulWidget {
  final String roomId;

  const GroupInfoScreen({super.key, required this.roomId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  StreamSubscription<ChatRoomEntity?>? _roomSub;
  ChatRoomEntity? _room;

  @override
  void initState() {
    super.initState();
    _roomSub = sl<GetChatRoomUseCase>()(widget.roomId).listen((room) {
      if (mounted) setState(() => _room = room);
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  bool _isAdmin(ChatRoomEntity room, String uid) => room.adminIds.contains(uid);

  Future<void> _editGroupInfo(ChatRoomEntity room, String adminId) async {
    final nameController = TextEditingController(text: room.groupName ?? '');
    final descController = TextEditingController(text: room.groupDescription ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      context.read<GroupBloc>().add(
            UpdateGroupInfoRequested(
              roomId: widget.roomId,
              adminId: adminId,
              groupName: nameController.text.trim(),
              groupDescription: descController.text.trim(),
            ),
          );
    }
    nameController.dispose();
    descController.dispose();
  }

  Future<void> _changeGroupImage(ChatRoomEntity room, String adminId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    context.read<UploadBloc>().add(
          UploadFileRequested(filePath: picked.path, folder: 'group_images'),
        );

    late StreamSubscription sub;
    sub = context.read<UploadBloc>().stream.listen((state) {
      if (state is UploadSuccess) {
        context.read<GroupBloc>().add(
              UpdateGroupInfoRequested(
                roomId: widget.roomId,
                adminId: adminId,
                groupImage: state.downloadUrl,
              ),
            );
        sub.cancel();
      }
    });
  }

  Future<void> _addMembers(ChatRoomEntity room, String adminId) async {
    context.read<SearchBloc>().add(const SearchUsersRequested(''));

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        final selectedIds = <String>{};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              builder: (_, controller) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Add Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: BlocBuilder<SearchBloc, SearchState>(
                        builder: (context, state) {
                          if (state is! SearchUsersSuccess) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final users = state.users
                              .where((u) => !room.participants.contains(u.uid))
                              .toList();
                          return ListView.builder(
                            controller: controller,
                            itemCount: users.length,
                            itemBuilder: (_, i) {
                              final user = users[i];
                              return CheckboxListTile(
                                value: selectedIds.contains(user.uid),
                                onChanged: (v) {
                                  setModalState(() {
                                    if (v == true) {
                                      selectedIds.add(user.uid);
                                    } else {
                                      selectedIds.remove(user.uid);
                                    }
                                  });
                                },
                                title: Text(user.fullName),
                                subtitle: Text('@${user.username}'),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(ctx, selectedIds),
                        child: Text('Add ${selectedIds.length} member(s)'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      context.read<GroupBloc>().add(
            AddGroupMembersRequested(
              roomId: widget.roomId,
              adminId: adminId,
              memberIds: selected.toList(),
            ),
          );
    }
  }

  Future<void> _leaveGroup(ChatRoomEntity room, String userId) async {
    if (_isAdmin(room, userId) && room.participants.length > 1) {
      final otherMembers = room.participants.where((id) => id != userId).toList();
      final newAdmin = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transfer Admin'),
          content: const Text('You are the admin. Select a new admin before leaving.'),
          actions: otherMembers.map((id) {
            return BlocProvider(
              create: (_) => sl<ProfileBloc>()..add(LoadProfile(id)),
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  final name = state is ProfileLoaded ? state.user.fullName : 'Member';
                  return TextButton(
                    onPressed: () => Navigator.pop(ctx, id),
                    child: Text(name),
                  );
                },
              ),
            );
          }).toList(),
        ),
      );
      if (newAdmin == null) return;
      context.read<GroupBloc>().add(
            TransferGroupAdminRequested(
              roomId: widget.roomId,
              currentAdminId: userId,
              newAdminId: newAdmin,
            ),
          );
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );

    if (confirm == true) {
      context.read<GroupBloc>().add(
            LeaveGroupRequested(roomId: widget.roomId, userId: userId),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';
    final room = _room;

    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupActionSuccess && state.message.contains('left')) {
          context.go(AppRoutes.home);
        } else if (state is GroupFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
          );
        } else if (state is GroupActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Group Info')),
        body: room == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.surfaceLight,
                            backgroundImage: room.groupImage != null && room.groupImage!.isNotEmpty
                                ? CachedNetworkImageProvider(room.groupImage!)
                                : null,
                            child: room.groupImage == null || room.groupImage!.isEmpty
                                ? const Icon(Icons.groups, size: 48)
                                : null,
                          ),
                          if (_isAdmin(room, currentUserId))
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton.filled(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _changeGroupImage(room, currentUserId),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        room.groupName ?? 'Group',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (room.groupDescription != null && room.groupDescription!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            room.groupDescription!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${room.participants.length} members',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isAdmin(room, currentUserId))
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editGroupInfo(room, currentUserId),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Info'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addMembers(room, currentUserId),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Members'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Members',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...room.participants.map(
                      (uid) => _MemberTile(
                        uid: uid,
                        isAdmin: room.adminIds.contains(uid),
                        canRemove: _isAdmin(room, currentUserId) && uid != currentUserId,
                        onRemove: () {
                          context.read<GroupBloc>().add(
                                RemoveGroupMemberRequested(
                                  roomId: widget.roomId,
                                  adminId: currentUserId,
                                  memberId: uid,
                                ),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () => _leaveGroup(room, currentUserId),
                      icon: const Icon(Icons.exit_to_app, color: AppColors.error),
                      label: const Text('Leave Group', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String uid;
  final bool isAdmin;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.uid,
    required this.isAdmin,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(LoadProfile(uid)),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final UserEntity? user = state is ProfileLoaded ? state.user : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: user?.profilePicture.isNotEmpty == true
                    ? CachedNetworkImageProvider(user!.profilePicture)
                    : null,
                child: user?.profilePicture.isEmpty != false ? const Icon(Icons.person) : null,
              ),
              title: Text(user?.fullName ?? 'Loading...'),
              subtitle: user != null ? Text('@${user.username}') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                    ),
                  if (canRemove)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                      onPressed: onRemove,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
