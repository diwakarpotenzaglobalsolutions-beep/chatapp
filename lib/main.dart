import 'dart:async';
import 'package:chatapp/presentation/blocs/chat_request/chat_request_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'firebase_options.dart';
import 'injection/injection_container.dart' as sl;
import 'core/constants/notification_types.dart';
import 'core/constants/stripe_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_navigation_service.dart';
import 'core/services/zego_call_service.dart';
import 'routes/router.dart';
import 'routes/app_navigator.dart';
import 'core/constants/theme.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/home/home_bloc.dart';
import 'presentation/blocs/notification/notification_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';
import 'presentation/blocs/chat_list/chat_list_bloc.dart';
import 'presentation/blocs/search/search_bloc.dart';
import 'presentation/blocs/connectivity/connectivity_bloc.dart';
import 'presentation/blocs/chat/chat_bloc.dart';
import 'presentation/blocs/subscription/subscription_bloc.dart';
import 'presentation/widgets/connectivity_banner.dart';

late final AuthBloc _authBloc;
late final SubscriptionBloc _subscriptionBloc;
late final GoRouter _appRouter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(rootNavigatorKey);
  await ZegoCallService.setupSystemCallingUI();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  Stripe.publishableKey = StripeConfig.publishableKey;

  await Stripe.instance.applySettings();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await sl.init();

  _authBloc = sl.sl<AuthBloc>()..add(AppStarted());
  _subscriptionBloc = sl.sl<SubscriptionBloc>();
  _appRouter = AppRoutes.createRouter(
    authBloc: _authBloc,
    subscriptionBloc: _subscriptionBloc,
  );

  await _bootstrapAuthenticatedSession();

  await sl.sl<NotificationService>().initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

Future<void> _bootstrapAuthenticatedSession() async {
  // AppStarted may finish before the widget tree mounts.
  for (var i = 0; i < 50; i++) {
    final state = _authBloc.state;
    if (state is Authenticated) {
      _subscriptionBloc.add(SubscriptionWatchRequested(state.user.uid));
      _subscriptionBloc.add(SubscriptionInitializeTrialRequested(state.user.uid));
      await sl.sl<ZegoCallService>().initialize(
        userId: state.user.uid,
        userName: state.user.fullName,
      );
      return;
    }
    if (state is Unauthenticated) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Map<String, dynamic>>? _notificationNavSub;

  @override
  void initState() {
    super.initState();

    _notificationNavSub =
        NotificationNavigationService.instance.onNavigate.listen(_handleNotificationNavigation);
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] as String? ?? '';

    switch (type) {
      case NotificationTypes.message:
      case NotificationTypes.chatRequestAccepted:
        final roomId = data['roomId'] as String?;
        if (roomId == null) return;
        context.push(
          '${AppRoutes.chat}/$roomId',
          extra: {
            'peerId': data['peerId'] ?? '',
            'peerName': data['peerName'] ?? '',
            'peerImage': data['peerImage'] ?? '',
          },
        );
        break;
      case NotificationTypes.groupMessage:
        final roomId = data['roomId'] as String?;
        if (roomId == null) return;
        context.push(
          '${AppRoutes.groupChat}/$roomId',
          extra: {
            'groupName': data['groupName'] ?? 'Group',
            'groupImage': data['groupImage'] ?? '',
          },
        );
        break;
      case NotificationTypes.chatRequest:
        context.push(AppRoutes.chatRequests);
        break;
      case NotificationTypes.audioCall:
      case NotificationTypes.videoCall:
        context.push(AppRoutes.callHistory);
        break;
    }
  }

  @override
  void dispose() {
    _notificationNavSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _subscriptionBloc),
        BlocProvider(create: (context) => sl.sl<HomeBloc>()),
        BlocProvider(create: (context) => sl.sl<SettingsBloc>()..add(LoadSettings())),
        BlocProvider(create: (context) => sl.sl<NotificationBloc>()..add(InitializeNotifications())),
        BlocProvider(create: (context) => sl.sl<ChatListBloc>()),
        BlocProvider(create: (context) => sl.sl<SearchBloc>()),
        BlocProvider(create: (context) => sl.sl<ChatBloc>()),
        BlocProvider(create: (context) => sl.sl<ChatRequestBloc>()),
        BlocProvider(
          create: (context) => sl.sl<ConnectivityBloc>()..add(StartConnectivityMonitoring()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          final zegoService = sl.sl<ZegoCallService>();
          final subscriptionBloc = context.read<SubscriptionBloc>();

          if (state is Authenticated) {
            context.read<NotificationBloc>().add(SaveFcmToken(state.user.uid));
            subscriptionBloc.add(SubscriptionWatchRequested(state.user.uid));
            subscriptionBloc.add(SubscriptionInitializeTrialRequested(state.user.uid));
            await zegoService.initialize(
              userId: state.user.uid,
              userName: state.user.fullName,
            );
          } else if (state is Unauthenticated) {
            subscriptionBloc.add(SubscriptionStopped());
            zegoService.uninitialize();
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            bool isDarkMode = true;
            if (state is SettingsLoaded) {
              isDarkMode = state.isDarkMode;
            }

            return MaterialApp.router(
              title: 'Aether Chat',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
              routerConfig: _appRouter,
              builder: (context, child) {
                return Column(
                  children: [
                    const ConnectivityBanner(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
