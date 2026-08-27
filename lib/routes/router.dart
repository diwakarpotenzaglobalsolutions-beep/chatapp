import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/usecases/chat_request_usecases.dart';
import '../core/services/notification_service.dart';
import '../injection/injection_container.dart';
import 'app_navigator.dart';

import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/chat_request/chat_request_bloc.dart';
import '../presentation/blocs/login/login_bloc.dart';
import '../presentation/blocs/register/register_bloc.dart';
import '../presentation/blocs/forgot_password/forgot_password_bloc.dart';
import '../presentation/blocs/change_password/change_password_bloc.dart';
import '../presentation/blocs/edit_profile/edit_profile_bloc.dart';
import '../presentation/blocs/upload_profile_image/upload_profile_image_bloc.dart';
import '../presentation/blocs/message/message_bloc.dart';
import '../presentation/blocs/typing/typing_bloc.dart';
import '../presentation/blocs/presence/presence_bloc.dart';
import '../presentation/blocs/upload/upload_bloc.dart';
import '../presentation/blocs/audio/audio_bloc.dart';
import '../presentation/blocs/location/location_bloc.dart';
import '../presentation/blocs/group/group_bloc.dart';
import '../presentation/blocs/block/block_bloc.dart';
import '../presentation/blocs/call/call_bloc.dart';

import '../presentation/screens/chat_requests_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/register_screen.dart';
import '../presentation/screens/forgot_password_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/edit_profile_screen.dart';
import '../presentation/screens/change_password_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/search_screen.dart';
import '../presentation/screens/image_viewer_screen.dart';
import '../presentation/screens/video_player_screen.dart';
import '../presentation/screens/document_viewer_screen.dart';
import '../presentation/screens/create_group_screen.dart';
import '../presentation/screens/group_chat_screen.dart';
import '../presentation/screens/group_info_screen.dart';
import '../presentation/screens/blocked_users_screen.dart';
import '../presentation/screens/call_history_screen.dart';
import '../domain/entities/subscription_entity.dart';
import '../presentation/blocs/subscription/subscription_bloc.dart';
import '../presentation/screens/subscription_screen.dart';
import 'app_router_refresh.dart';
import 'router_access.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String groupChat = '/group-chat';
  static const String groupInfo = '/group-info';
  static const String createGroup = '/create-group';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String settings = '/settings';
  static const String search = '/search';
  static const String imageViewer = '/image-viewer';
  static const String videoPlayer = '/video-player';
  static const String documentViewer = '/document-viewer';
  static const String chatRequests = '/chat-requests';
  static const String callHistory = '/call-history';
  static const String blockedUsers = '/blocked-users';
  static const String subscription = '/subscription';

  static GoRouter createRouter({
    required AuthBloc authBloc,
    required SubscriptionBloc subscriptionBloc,
  }) {
    RouterAccess.authBloc = authBloc;
    RouterAccess.subscriptionBloc = subscriptionBloc;

    final refresh = AppRouterRefresh.fromBlocs([authBloc, subscriptionBloc]);

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: splash,
      refreshListenable: refresh,
      redirect: (context, state) {
        final authState = authBloc.state;
        final subState = subscriptionBloc.state;
        final location = state.matchedLocation;

        const authFreeRoutes = {splash, login, register, forgotPassword};

        if (authState is! Authenticated) {
          if (authFreeRoutes.contains(location)) return null;
          return login;
        }

        // Authenticated: always leave auth/splash routes even while subscription loads.
        if (location == login || location == register || location == splash) {
          if (subState is SubscriptionLoaded) {
            final subscriptionEntity = subState.subscription;
            final awaitingTrialInit = subscriptionEntity.status == SubscriptionStatus.unknown &&
                !subscriptionEntity.trialUsed;

            if (!subState.hasAccess && !awaitingTrialInit) {
              return subscription;
            }
          }
          return home;
        }

        if (subState is SubscriptionInitial || subState is SubscriptionLoading) {
          return null;
        }

        if (subState is SubscriptionFailure) {
          if (location == subscription) return null;
          return null;
        }

        if (subState is SubscriptionLoaded) {
          final subscriptionEntity = subState.subscription;
          final awaitingTrialInit = subscriptionEntity.status == SubscriptionStatus.unknown &&
              !subscriptionEntity.trialUsed;

          if (!subState.hasAccess) {
            if (awaitingTrialInit) return null;
            if (location == subscription) return null;
            return subscription;
          }

          if (location == subscription) {
            return home;
          }
        }

        return null;
      },
      routes: _routes,
    );
  }

  static final List<RouteBase> _routes = [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) {
          return BlocProvider<LoginBloc>(
            create: (context) => sl<LoginBloc>(),
            child: const LoginScreen(),
          );
        },
      ),
      GoRoute(
        path: register,
        builder: (context, state) {
          return BlocProvider<RegisterBloc>(
            create: (context) => sl<RegisterBloc>(),
            child: const RegisterScreen(),
          );
        },
      ),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) {
          return BlocProvider<ForgotPasswordBloc>(
            create: (context) => sl<ForgotPasswordBloc>(),
            child: const ForgotPasswordScreen(),
          );
        },
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: createGroup,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<GroupBloc>(),
            child: const CreateGroupScreen(),
          );
        },
      ),
      GoRoute(
        path: '$chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final peerId = extra['peerId'] as String? ?? '';
          final peerName = extra['peerName'] as String? ?? '';
          final peerImage = extra['peerImage'] as String? ?? '';
          final authState = context.read<AuthBloc>().state;
          final currentUserId = authState is Authenticated ? authState.user.uid : '';

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<ChatRequestBloc>()
                  ..add(SubscribeToRequestBetweenUsers(user1: currentUserId, user2: peerId)),
              ),
              BlocProvider(
                create: (_) => sl<MessageBloc>()
                  ..add(SubscribeToMessages(roomId: roomId, currentUserId: currentUserId)),
              ),
              BlocProvider(create: (_) => sl<TypingBloc>()..add(SubscribeToTypingStatus(roomId))),
              BlocProvider(create: (_) => sl<PresenceBloc>()..add(SubscribeToUserPresence(peerId))),
              BlocProvider(create: (_) => sl<UploadBloc>()),
              BlocProvider(create: (_) => sl<AudioBloc>()),
              BlocProvider(create: (_) => sl<LocationBloc>()),
              BlocProvider(create: (_) => sl<CallBloc>()),
              BlocProvider(
                create: (_) => sl<BlockBloc>()
                  ..add(WatchBlockStatusRequested(
                    currentUserId: currentUserId,
                    peerUserId: peerId,
                  )),
              ),
            ],
            child: _ActiveChatWrapper(
              currentUserId: currentUserId,
              roomId: roomId,
              child: ChatScreen(
                roomId: roomId,
                peerId: peerId,
                peerName: peerName,
                peerImage: peerImage,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '$groupChat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final groupName = extra['groupName'] as String? ?? 'Group';
          final groupImage = extra['groupImage'] as String? ?? '';
          final authState = context.read<AuthBloc>().state;
          final currentUserId = authState is Authenticated ? authState.user.uid : '';

          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<MessageBloc>()
                  ..add(SubscribeToMessages(roomId: roomId, currentUserId: currentUserId)),
              ),
              BlocProvider(create: (_) => sl<TypingBloc>()..add(SubscribeToTypingStatus(roomId))),
              BlocProvider(create: (_) => sl<UploadBloc>()),
              BlocProvider(create: (_) => sl<AudioBloc>()),
              BlocProvider(create: (_) => sl<LocationBloc>()),
            ],
            child: _ActiveChatWrapper(
              currentUserId: currentUserId,
              roomId: roomId,
              child: GroupChatScreen(
                roomId: roomId,
                groupName: groupName,
                groupImage: groupImage,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '$groupInfo/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => sl<GroupBloc>()),
              BlocProvider(create: (_) => sl<UploadBloc>()),
            ],
            child: GroupInfoScreen(roomId: roomId),
          );
        },
      ),
      GoRoute(
        path: '$profile/:uid',
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return ProfileScreen(uid: uid);
        },
      ),
      GoRoute(
        path: editProfile,
        builder: (context, state) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => sl<EditProfileBloc>()),
              BlocProvider(create: (context) => sl<UploadProfileImageBloc>()),
            ],
            child: const EditProfileScreen(),
          );
        },
      ),
      GoRoute(
        path: changePassword,
        builder: (context, state) {
          return BlocProvider<ChangePasswordBloc>(
            create: (context) => sl<ChangePasswordBloc>(),
            child: const ChangePasswordScreen(),
          );
        },
      ),
      GoRoute(
        path: settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: chatRequests,
        builder: (context, state) => const ChatRequestsScreen(),
      ),
      GoRoute(
        path: callHistory,
        builder: (context, state) {
          return BlocProvider(
            create: (_) => sl<CallBloc>(),
            child: const CallHistoryScreen(),
          );
        },
      ),
      GoRoute(
        path: subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: blockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: imageViewer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final url = extra['url'] as String? ?? '';
          final tag = extra['tag'] as String? ?? '';
          return ImageViewerScreen(imageUrl: url, heroTag: tag);
        },
      ),
      GoRoute(
        path: videoPlayer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final url = extra['url'] as String? ?? '';
          return VideoPlayerScreen(videoUrl: url);
        },
      ),
      GoRoute(
        path: documentViewer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final url = extra['url'] as String? ?? '';
          final name = extra['name'] as String? ?? '';
          return DocumentViewerScreen(docUrl: url, docName: name);
        },
      ),
    ];
}

class _ActiveChatWrapper extends StatefulWidget {
  final String currentUserId;
  final String roomId;
  final Widget child;

  const _ActiveChatWrapper({
    required this.currentUserId,
    required this.roomId,
    required this.child,
  });

  @override
  State<_ActiveChatWrapper> createState() => _ActiveChatWrapperState();
}

class _ActiveChatWrapperState extends State<_ActiveChatWrapper> {
  @override
  void initState() {
    super.initState();
    sl<NotificationService>().setActiveChatRoom(widget.roomId);
    if (widget.currentUserId.isNotEmpty) {
      sl<SetActiveChatRoomUseCase>()(widget.currentUserId, widget.roomId);
    }
  }

  @override
  void dispose() {
    sl<NotificationService>().setActiveChatRoom(null);
    if (widget.currentUserId.isNotEmpty) {
      sl<SetActiveChatRoomUseCase>()(widget.currentUserId, null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
