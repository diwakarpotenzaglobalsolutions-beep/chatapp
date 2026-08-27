import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme.dart';
import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/group/group_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/search/search_bloc.dart';
import 'user_preview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late TabController _tabController;
  late GroupBloc _groupBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _groupBloc = sl<GroupBloc>();
    context.read<SearchBloc>().add(const SearchUsersRequested(''));
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final homeState = context.read<HomeBloc>().state;
    final uid = homeState is HomeLoaded ? homeState.currentUser.uid : '';
    if (_tabController.index == 1 && uid.isNotEmpty) {
      _groupBloc.add(SubscribeToGroupSearch(uid: uid, query: _searchController.text));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    _groupBloc.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_tabController.index == 0) {
        context.read<SearchBloc>().add(SearchUsersRequested(query));
      } else {
        final homeState = context.read<HomeBloc>().state;
        final uid = homeState is HomeLoaded ? homeState.currentUser.uid : '';
        if (uid.isNotEmpty) {
          _groupBloc.add(SubscribeToGroupSearch(uid: uid, query: query));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.read<HomeBloc>().state;
    final currentUserId = homeState is HomeLoaded ? homeState.currentUser.uid : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.scaffoldGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (query) {
                  setState(() {});
                  _onSearchChanged(query);
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _tabController.index == 0
                      ? 'Search by name or @username...'
                      : 'Search your groups...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            if (_tabController.index == 0) {
                              context.read<SearchBloc>().add(ClearSearchRequested());
                            } else if (currentUserId.isNotEmpty) {
                              _groupBloc.add(SubscribeToGroupSearch(uid: currentUserId, query: ''));
                            }
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _UsersTab(currentUserId: currentUserId),
                  BlocProvider.value(
                    value: _groupBloc,
                    child: _GroupsTab(currentUserId: currentUserId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final String currentUserId;

  const _UsersTab({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (state is SearchUsersSuccess) {
          final filteredUsers = state.users.where((user) => user.uid != currentUserId).toList();
          final hasQuery = state.query.isNotEmpty;

          if (filteredUsers.isEmpty) {
            return Center(
              child: Text(
                hasQuery ? 'No users found matching your search.' : 'No users available.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return _UserTile(
                user: user,
                onTap: () {
                  if (currentUserId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => UserPreviewScreen(peer: user)),
                    );
                  }
                },
              );
            },
          );
        }

        if (state is SearchFailure) {
          return Center(child: Text('Search failed: ${state.error}', style: const TextStyle(color: AppColors.error)));
        }

        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      },
    );
  }
}

class _GroupsTab extends StatefulWidget {
  final String currentUserId;

  const _GroupsTab({required this.currentUserId});

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  @override
  void initState() {
    super.initState();
    if (widget.currentUserId.isNotEmpty) {
      context.read<GroupBloc>().add(SubscribeToGroupSearch(uid: widget.currentUserId, query: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupBloc, GroupState>(
      builder: (context, state) {
        if (state is GroupLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state is GroupSearchLoaded) {
          if (state.groups.isEmpty) {
            return Center(
              child: Text(
                state.query.isNotEmpty ? 'No groups match your search.' : 'You are not in any groups yet.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.groups.length,
            itemBuilder: (context, index) {
              final group = state.groups[index];
              return _GroupTile(group: group);
            },
          );
        }
        if (state is GroupFailure) {
          return Center(child: Text(state.error, style: const TextStyle(color: AppColors.error)));
        }
        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ChatRoomEntity group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: group.groupImage != null && group.groupImage!.isNotEmpty
              ? CachedNetworkImageProvider(group.groupImage!)
              : null,
          child: group.groupImage == null || group.groupImage!.isEmpty
              ? const Icon(Icons.groups)
              : null,
        ),
        title: Text(group.groupName ?? 'Group', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${group.participants.length} members'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.push(
            '${AppRoutes.groupChat}/${group.roomId}',
            extra: {
              'groupName': group.groupName ?? 'Group',
              'groupImage': group.groupImage ?? '',
            },
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserEntity user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundImage: user.profilePicture.isNotEmpty
              ? CachedNetworkImageProvider(user.profilePicture)
              : null,
          child: user.profilePicture.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@${user.username}', style: const TextStyle(color: AppColors.textMuted)),
        trailing: const Icon(Icons.person_add_alt_1, color: AppColors.primaryLight),
        onTap: onTap,
      ),
    );
  }
}
