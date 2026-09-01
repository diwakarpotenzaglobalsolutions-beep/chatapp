import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/theme.dart';
import '../../core/constants/whatsapp_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/group/group_bloc.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/upload/upload_bloc.dart';
import '../widgets/shimmer_loading.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _selectedMemberIds = {};
  final Map<String, UserEntity> _selectedUsers = {};
  String? _groupImageUrl;
  Timer? _debounce;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserId = authState.user.uid;
      context.read<SearchBloc>().add(
            SearchFriendsRequested(userId: _currentUserId, query: ''),
          );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_currentUserId.isEmpty) return;
      context.read<SearchBloc>().add(
            SearchFriendsRequested(userId: _currentUserId, query: query),
          );
    });
  }

  Future<void> _pickGroupImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    context.read<UploadBloc>().add(
          UploadFileRequested(filePath: picked.path, folder: 'group_images'),
        );

    late StreamSubscription sub;
    sub = context.read<UploadBloc>().stream.listen((state) {
      if (state is UploadSuccess) {
        setState(() => _groupImageUrl = state.downloadUrl);
        sub.cancel();
      } else if (state is UploadFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
        );
        sub.cancel();
      }
    });
  }

  void _toggleMember(UserEntity user, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemberIds.add(user.uid);
        _selectedUsers[user.uid] = user;
      } else {
        _selectedMemberIds.remove(user.uid);
        _selectedUsers.remove(user.uid);
      }
    });
  }

  void _createGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_currentUserId.isEmpty) return;

    context.read<GroupBloc>().add(
          CreateGroupRequested(
            creatorId: _currentUserId,
            groupName: name,
            groupDescription: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            groupImage: _groupImageUrl,
            memberIds: _selectedMemberIds.toList(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = WhatsAppColors.isDark(context);

    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupCreated) {
          context.go('${AppRoutes.groupChat}/${state.roomId}');
        } else if (state is GroupFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: WhatsAppColors.background(context),
        appBar: AppBar(
          backgroundColor: WhatsAppColors.bar(context),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'New group',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          actions: [
            BlocBuilder<GroupBloc, GroupState>(
              builder: (context, state) {
                final loading = state is GroupLoading;
                return IconButton(
                  onPressed: loading || _currentUserId.isEmpty ? null : _createGroup,
                  icon: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white),
                );
              },
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: WhatsAppColors.bar(context),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickGroupImage,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: isDark ? const Color(0xFF2A3942) : Colors.white24,
                      backgroundImage: _groupImageUrl != null
                          ? CachedNetworkImageProvider(_groupImageUrl!)
                          : null,
                      child: _groupImageUrl == null
                          ? const Icon(Icons.camera_alt, color: Colors.white70, size: 26)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Group subject',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedMemberIds.isNotEmpty)
              Container(
                height: 88,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isDark ? const Color(0xFF111B21) : Colors.white,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _selectedUsers.values.map((user) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: WhatsAppColors.accent.withValues(alpha: 0.2),
                                backgroundImage: user.profilePicture.isNotEmpty
                                    ? CachedNetworkImageProvider(user.profilePicture)
                                    : null,
                                child: user.profilePicture.isEmpty
                                    ? Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: WhatsAppColors.accent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: () => _toggleMember(user, false),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 56,
                            child: Text(
                              user.fullName.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: WhatsAppColors.primaryText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Add friends',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WhatsAppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
                style: TextStyle(color: WhatsAppColors.primaryText(context)),
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  hintStyle: const TextStyle(color: WhatsAppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: WhatsAppColors.textSecondary),
                  filled: true,
                  fillColor: isDark ? WhatsAppColors.searchField : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: WhatsAppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            if (_currentUserId.isNotEmpty) {
                              context.read<SearchBloc>().add(
                                    SearchFriendsRequested(
                                      userId: _currentUserId,
                                      query: '',
                                    ),
                                  );
                            }
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const ShimmerContactList();
                  }
                  if (state is SearchFailure) {
                    return Center(
                      child: Text(
                        state.error,
                        style: TextStyle(color: WhatsAppColors.primaryText(context)),
                      ),
                    );
                  }
                  if (state is SearchUsersSuccess) {
                    final friends = state.users
                        .where((u) => u.uid != _currentUserId)
                        .toList();
                    if (friends.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 56,
                                color: WhatsAppColors.textSecondary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                state.query.isEmpty
                                    ? 'No friends yet'
                                    : 'No friends match your search',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: WhatsAppColors.primaryText(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Accept chat requests to add friends to groups',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: WhatsAppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: isDark ? WhatsAppColors.divider : Colors.black12,
                      ),
                      itemBuilder: (context, index) {
                        final user = friends[index];
                        final selected = _selectedMemberIds.contains(user.uid);
                        return _FriendSelectTile(
                          user: user,
                          selected: selected,
                          onTap: () => _toggleMember(user, !selected),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendSelectTile extends StatelessWidget {
  final UserEntity user;
  final bool selected;
  final VoidCallback onTap;

  const _FriendSelectTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: WhatsAppColors.accent.withValues(alpha: 0.15),
              backgroundImage: user.profilePicture.isNotEmpty
                  ? CachedNetworkImageProvider(user.profilePicture)
                  : null,
              child: user.profilePicture.isEmpty
                  ? Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: WhatsAppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
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
                      fontSize: 16,
                      color: WhatsAppColors.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? WhatsAppColors.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? WhatsAppColors.accent : WhatsAppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
