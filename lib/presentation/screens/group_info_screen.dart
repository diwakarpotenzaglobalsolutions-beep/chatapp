import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/theme.dart';
import '../../core/constants/whatsapp_theme.dart';
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
import '../widgets/shimmer_loading.dart';

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
    context.read<SearchBloc>().add(
          SearchFriendsRequested(userId: adminId, query: ''),
        );

    final searchController = TextEditingController();
    Timer? debounce;

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WhatsAppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final selectedIds = <String>{};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              builder: (_, controller) {
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: WhatsAppColors.textSecondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Add friends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: WhatsAppColors.primaryText(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        onChanged: (query) {
                          debounce?.cancel();
                          debounce = Timer(const Duration(milliseconds: 300), () {
                            context.read<SearchBloc>().add(
                                  SearchFriendsRequested(
                                    userId: adminId,
                                    query: query,
                                  ),
                                );
                          });
                        },
                        style: TextStyle(color: WhatsAppColors.primaryText(context)),
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          hintStyle: const TextStyle(color: WhatsAppColors.textSecondary),
                          prefixIcon: const Icon(Icons.search, color: WhatsAppColors.textSecondary),
                          filled: true,
                          fillColor: WhatsAppColors.isDark(context)
                              ? WhatsAppColors.searchField
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: BlocBuilder<SearchBloc, SearchState>(
                        builder: (context, state) {
                          if (state is SearchLoading) {
                            return const ShimmerContactList(itemCount: 6);
                          }
                          if (state is! SearchUsersSuccess) {
                            return const SizedBox.shrink();
                          }
                          final friends = state.users
                              .where((u) => !room.participants.contains(u.uid))
                              .toList();
                          if (friends.isEmpty) {
                            return Center(
                              child: Text(
                                'No friends available to add',
                                style: TextStyle(
                                  color: WhatsAppColors.primaryText(context),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            controller: controller,
                            itemCount: friends.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 72,
                              color: WhatsAppColors.isDark(context)
                                  ? WhatsAppColors.divider
                                  : Colors.black12,
                            ),
                            itemBuilder: (_, i) {
                              final user = friends[i];
                              final isSelected = selectedIds.contains(user.uid);
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedIds.remove(user.uid);
                                    } else {
                                      selectedIds.add(user.uid);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundImage: user.profilePicture.isNotEmpty
                                            ? CachedNetworkImageProvider(user.profilePicture)
                                            : null,
                                        child: user.profilePicture.isEmpty
                                            ? Text(
                                                user.fullName.isNotEmpty
                                                    ? user.fullName[0].toUpperCase()
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.fullName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: WhatsAppColors.primaryText(context),
                                              ),
                                            ),
                                            Text(
                                              '@${user.username}',
                                              style: const TextStyle(
                                                color: WhatsAppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? WhatsAppColors.accent
                                            : WhatsAppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WhatsAppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: selectedIds.isEmpty
                                ? null
                                : () => Navigator.pop(ctx, selectedIds),
                            child: Text(
                              selectedIds.isEmpty
                                  ? 'Select friends'
                                  : 'Add ${selectedIds.length} friend(s)',
                            ),
                          ),
                        ),
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

    debounce?.cancel();
    searchController.dispose();

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
        backgroundColor: WhatsAppColors.background(context),
        appBar: AppBar(
          backgroundColor: WhatsAppColors.bar(context),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Group info'),
        ),
        body: room == null
            ? const ShimmerContactList(itemCount: 5)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: const Color(0xFF2A3942),
                          backgroundImage: room.groupImage != null && room.groupImage!.isNotEmpty
                              ? CachedNetworkImageProvider(room.groupImage!)
                              : null,
                          child: room.groupImage == null || room.groupImage!.isEmpty
                              ? const Icon(Icons.groups, size: 52, color: Colors.white70)
                              : null,
                        ),
                        if (_isAdmin(room, currentUserId))
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: WhatsAppColors.accent,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                onPressed: () => _changeGroupImage(room, currentUserId),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      room.groupName ?? 'Group',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: WhatsAppColors.primaryText(context),
                      ),
                    ),
                  ),
                  if (room.groupDescription != null && room.groupDescription!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          room.groupDescription!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: WhatsAppColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Group · ${room.participants.length} members',
                      style: const TextStyle(color: WhatsAppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isAdmin(room, currentUserId))
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: WhatsAppColors.accent,
                              side: const BorderSide(color: WhatsAppColors.accent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _editGroupInfo(room, currentUserId),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: WhatsAppColors.accent,
                              side: const BorderSide(color: WhatsAppColors.accent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _addMembers(room, currentUserId),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '${room.participants.length} members',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: WhatsAppColors.textSecondary,
                    ),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _leaveGroup(room, currentUserId),
                    icon: const Icon(Icons.exit_to_app, color: AppColors.error),
                    label: const Text('Exit group', style: TextStyle(color: AppColors.error)),
                  ),
                ],
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
          if (user == null) {
            return const ShimmerListTile();
          }
          return InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: WhatsAppColors.accent.withValues(alpha: 0.15),
                    backgroundImage: user.profilePicture.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePicture)
                        : null,
                    child: user.profilePicture.isEmpty
                        ? Text(
                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(color: WhatsAppColors.accent),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WhatsAppColors.primaryText(context),
                          ),
                        ),
                        if (isAdmin)
                          const Text(
                            'Group admin',
                            style: TextStyle(
                              color: WhatsAppColors.accent,
                              fontSize: 13,
                            ),
                          )
                        else
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              color: WhatsAppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
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
