import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/conversation_search_helper.dart';
import '../../core/utils/date_time_formatter.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/zego_call_service.dart';
import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/chat_list/chat_list_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/profile/profile_bloc.dart';
import '../widgets/trial_countdown_banner.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _chatRoomsSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<HomeBloc>().add(const LoadHome());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sl<ZegoCallService>().enterAcceptedOfflineCall();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HomeBloc>().add(const UpdatePresence(true));
    } else {
      context.read<HomeBloc>().add(const UpdatePresence(false));
    }
  }

  void _ensureChatSubscription(String uid) {
    if (_chatRoomsSubscribed) return;
    context.read<ChatListBloc>().add(SubscribeToChatRooms(uid));
    _chatRoomsSubscribed = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        if (homeState is HomeLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (homeState is HomeLoaded) {
          final currentUser = homeState.currentUser;
          _ensureChatSubscription(currentUser.uid);

          final List<Widget> pages = [
            _ChatListTab(currentUser: currentUser),
            const SearchScreen(),
            const SettingsScreen(),
          ];

          return Scaffold(
            body: pages[_currentIndex],
            floatingActionButton: _currentIndex == 0
                ? FloatingActionButton.extended(
                    onPressed: () => context.push(AppRoutes.createGroup),
                    icon: const Icon(Icons.group_add),
                    label: const Text('New Group'),
                    backgroundColor: AppColors.primary,
                  )
                : null,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.borderColor, width: 0.5),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                backgroundColor: context.surfaceColor,
                selectedItemColor: AppColors.primaryLight,
                unselectedItemColor: context.textMutedColor,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    activeIcon: Icon(Icons.chat_bubble_rounded),
                    label: 'Chats',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search_rounded),
                    label: 'Friends',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load profile. Please log in again.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<AuthBloc>().add(LogOutRequested()),
                  child: const Text('LOGOUT'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatListTab extends StatefulWidget {
  final UserEntity currentUser;
  const _ChatListTab({required this.currentUser});

  @override
  State<_ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<_ChatListTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _subscribedGroupTopics = {};
  final Map<String, UserEntity> _peerProfiles = {};
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeerProfiles(List<ChatRoomEntity> rooms) async {
    final getProfile = sl<GetUserProfileUseCase>();
    for (final room in rooms) {
      if (room.isGroup) continue;
      final peerId = room.participants.firstWhere(
        (id) => id != widget.currentUser.uid,
        orElse: () => '',
      );
      if (peerId.isEmpty || _peerProfiles.containsKey(peerId)) continue;
      try {
        final user = await getProfile(peerId);
        if (mounted) {
          setState(() => _peerProfiles[peerId] = user);
        }
      } catch (_) {}
    }
  }

  Future<void> _onRefresh() async {
    context.read<ChatListBloc>().add(const RefreshChatRooms());
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _syncGroupTopics(List<ChatRoomEntity> rooms) {
    final notificationService = sl<NotificationService>();
    for (final room in rooms) {
      if (room.isGroup) {
        final topic = 'group_${room.roomId}';
        if (_subscribedGroupTopics.add(topic)) {
          notificationService.subscribeToTopic(topic);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Chat Requests',
            onPressed: () => context.push(AppRoutes.chatRequests),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: context.scaffoldGradient),
        child: Column(
          children: [
            const TrialCountdownBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats by name or message...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: BlocConsumer<ChatListBloc, ChatListState>(
          listenWhen: (prev, curr) => prev.rooms != curr.rooms,
          listener: (context, state) {
            _syncGroupTopics(state.rooms);
            _loadPeerProfiles(state.rooms);
          },
          builder: (context, state) {
            if (state.isInitialLoading && !state.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state.error != null && !state.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error loading chats: ${state.error}',
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ChatListBloc>().add(
                              SubscribeToChatRooms(
                                widget.currentUser.uid,
                                force: true,
                              ),
                            );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!state.hasData) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_outlined,
                              size: 64,
                              color: context.textMutedColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active conversations yet.',
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Search users or create a group to start chatting.',
                              style: TextStyle(
                                color: context.textMutedColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final filteredRooms = ConversationSearchHelper.filterRooms(
              rooms: state.rooms,
              query: _searchQuery,
              currentUserId: widget.currentUser.uid,
              peerProfiles: _peerProfiles,
            );

            if (filteredRooms.isEmpty && _searchQuery.trim().isNotEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Text(
                        'No chats match "${_searchQuery.trim()}".',
                        style: TextStyle(color: context.textSecondaryColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = filteredRooms[index];
                  if (room.isGroup) {
                    return _GroupRoomTile(
                      room: room,
                      currentUserId: widget.currentUser.uid,
                    );
                  }
                  final peerId = room.participants.firstWhere(
                    (id) => id != widget.currentUser.uid,
                    orElse: () => '',
                  );
                  if (peerId.isEmpty) return const SizedBox.shrink();
                  return _ChatRoomTile(
                    room: room,
                    peerId: peerId,
                    currentUserId: widget.currentUser.uid,
                  );
                },
              ),
            );
          },
        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupRoomTile extends StatelessWidget {
  final ChatRoomEntity room;
  final String currentUserId;

  const _GroupRoomTile({
    required this.room,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = room.unreadCount[currentUserId] ?? 0;
    final typingCount = room.typingStatus.entries
        .where((e) => e.value && e.key != currentUserId)
        .length;

    String timeStr = '';
    if (room.lastMessage != null) {
      final lastMsgTime = room.lastMessage!.timestamp;
      final diff = DateTime.now().difference(lastMsgTime);
      if (diff.inDays >= 1) {
        timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(lastMsgTime);
      } else {
        timeStr = DateFormat('hh:mm a').format(lastMsgTime);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: context.cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: context.surfaceColor,
          backgroundImage: room.groupImage != null && room.groupImage!.isNotEmpty
              ? CachedNetworkImageProvider(room.groupImage!)
              : null,
          child: room.groupImage == null || room.groupImage!.isEmpty
              ? Icon(Icons.groups, color: context.textPrimaryColor, size: 24)
              : null,
        ),
        title: Text(
          room.groupName ?? 'Group',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.textPrimaryColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: typingCount > 0
              ? const Text(
                  'Someone is typing...',
                  style: TextStyle(color: AppColors.success, fontStyle: FontStyle.italic),
                )
              : Text(
                  _getLastMessageText(room.lastMessage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unreadCount > 0
                        ? context.textPrimaryColor
                        : context.textMutedColor,
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeStr, style: TextStyle(color: context.textMutedColor, fontSize: 11)),
            const SizedBox(height: 6),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          context.push(
            '${AppRoutes.groupChat}/${room.roomId}',
            extra: {
              'groupName': room.groupName ?? 'Group',
              'groupImage': room.groupImage ?? '',
            },
          );
        },
      ),
    );
  }

  String _getLastMessageText(MessageEntity? message) {
    if (message == null) return '';
    final prefix = message.senderName.isNotEmpty ? '${message.senderName}: ' : '';
    switch (message.type) {
      case MessageType.text:
        return '$prefix${message.content}';
      case MessageType.image:
        return '${prefix}📷 Image';
      case MessageType.video:
        return '${prefix}🎥 Video';
      case MessageType.voice:
        return '${prefix}🎵 Voice message';
      case MessageType.file:
        return '${prefix}📄 Document';
      case MessageType.location:
        return '${prefix}📍 Location';
    }
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoomEntity room;
  final String peerId;
  final String currentUserId;

  const _ChatRoomTile({
    required this.room,
    required this.peerId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ProfileBloc>()..add(LoadProfile(peerId)),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoaded) {
            final peer = state.user;
            final unreadCount = room.unreadCount[currentUserId] ?? 0;
            final isTyping = room.typingStatus[peerId] ?? false;

            String timeStr = '';
            if (room.lastMessage != null) {
              final lastMsgTime = room.lastMessage!.timestamp;
              final diff = DateTime.now().difference(lastMsgTime);
              if (diff.inDays >= 1) {
                timeStr = DateTimeFormatter.formatCallHistoryDateTime(lastMsgTime);
              } else {
                timeStr = DateTimeFormatter.formatMessageTime(lastMsgTime);
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: context.cardColor,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: context.surfaceColor,
                      backgroundImage: peer.profilePicture.isNotEmpty
                          ? CachedNetworkImageProvider(peer.profilePicture)
                          : null,
                      child: peer.profilePicture.isEmpty
                          ? Text(
                              peer.fullName[0],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: context.textPrimaryColor,
                              ),
                            )
                          : null,
                    ),
                    // if (peer.onlineStatus)
                    //   Positioned(
                    //     right: 0,
                    //     bottom: 0,
                    //     child: Container(
                    //       width: 14,
                    //       height: 14,
                    //       decoration: BoxDecoration(
                    //         color: AppColors.success,
                    //         shape: BoxShape.circle,
                    //         border: Border.all(color: context.surfaceColor, width: 2),
                    //       ),
                    //     ),
                    //   ),
                  ],
                ),
                title: Text(
                  peer.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimaryColor,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: isTyping
                      ? const Text(
                          'Typing...',
                          style: TextStyle(
                            color: AppColors.success,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _getLastMessageText(room.lastMessage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? context.textPrimaryColor
                                : context.textMutedColor,
                            fontWeight:
                                unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(color: context.textMutedColor, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (room.lastMessage != null &&
                        room.lastMessage!.senderId == currentUserId)
                      _buildReceiptTick(room.lastMessage!.status),
                  ],
                ),
                onTap: () {
                  context.push(
                    '${AppRoutes.chat}/${room.roomId}',
                    extra: {
                      'peerId': peer.uid,
                      'peerName': peer.fullName,
                      'peerImage': peer.profilePicture,
                    },
                  );
                },
              ),
            );
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: context.cardColor,
            child: Container(),
          );
        },
      ),
    );
  }

  String _getLastMessageText(MessageEntity? message) {
    if (message == null) return '';
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎵 Voice message';
      case MessageType.file:
        return '📄 Document';
      case MessageType.location:
        return '📍 Location';
    }
  }

  Widget _buildReceiptTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 16, color: AppColors.textMuted);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: AppColors.textMuted);
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 16, color: AppColors.secondary);
    }
  }
}
