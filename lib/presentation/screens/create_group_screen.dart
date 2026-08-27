import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/group/group_bloc.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/upload/upload_bloc.dart';

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
  String? _groupImageUrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    context.read<SearchBloc>().add(const SearchUsersRequested(''));
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
      context.read<SearchBloc>().add(SearchUsersRequested(query));
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

  void _createGroup(String creatorId) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    context.read<GroupBloc>().add(
          CreateGroupRequested(
            creatorId: creatorId,
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
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';

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
        appBar: AppBar(
          title: const Text('Create Group'),
          actions: [
            BlocBuilder<GroupBloc, GroupState>(
              builder: (context, state) {
                final loading = state is GroupLoading;
                return TextButton(
                  onPressed: loading || currentUserId.isEmpty
                      ? null
                      : () => _createGroup(currentUserId),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                );
              },
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickGroupImage,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surfaceLight,
                    backgroundImage: _groupImageUrl != null
                        ? CachedNetworkImageProvider(_groupImageUrl!)
                        : null,
                    child: _groupImageUrl == null
                        ? const Icon(Icons.camera_alt, size: 32, color: AppColors.textMuted)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this group about?',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Members (${_selectedMemberIds.length} selected)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            context.read<SearchBloc>().add(const SearchUsersRequested(''));
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }
                  if (state is SearchUsersSuccess) {
                    final users = state.users
                        .where((u) => u.uid != currentUserId)
                        .toList();
                    if (users.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No users found', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _MemberSelectTile(
                          user: user,
                          selected: _selectedMemberIds.contains(user.uid),
                          onChanged: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedMemberIds.add(user.uid);
                              } else {
                                _selectedMemberIds.remove(user.uid);
                              }
                            });
                          },
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSelectTile extends StatelessWidget {
  final UserEntity user;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _MemberSelectTile({
    required this.user,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => onChanged(v ?? false),
        secondary: CircleAvatar(
          backgroundImage: user.profilePicture.isNotEmpty
              ? CachedNetworkImageProvider(user.profilePicture)
              : null,
          child: user.profilePicture.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('@${user.username}', style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }
}
