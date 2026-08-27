import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_navigation_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await plugin.initialize(
    settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  final title = message.notification?.title ?? message.data['title'] ?? 'New notification';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  final dedupeId = message.data['dedupeId'] ?? message.messageId ?? message.hashCode.toString();

  await plugin.show(
    id: dedupeId.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_notifications_channel',
        'Chat Notifications',
        importance: Importance.max,
        priority: Priority.high,
        tag: dedupeId,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: jsonEncode(message.data),
  );
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _activeChatRoomId;
  final Set<String> _recentNotificationIds = {};

  void setActiveChatRoom(String? roomId) {
    _activeChatRoomId = roomId;
  }

  Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      onDidReceiveNotificationResponse: _onNotificationTapped,
      settings: initSettings,
    );

    const androidChannel = AndroidNotificationChannel(
      'chat_notifications_channel',
      'Chat Notifications',
      description: 'Messages, chat requests, and calls',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      NotificationNavigationService.instance.navigate(data);
    } catch (e) {
      developer.log('Notification tap parse error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final roomId = message.data['roomId'];
    if (roomId != null && roomId == _activeChatRoomId) return;

    final dedupeId = message.data['dedupeId'] as String? ??
        message.messageId ??
        message.hashCode.toString();
    if (_recentNotificationIds.contains(dedupeId)) return;
    _recentNotificationIds.add(dedupeId);
    if (_recentNotificationIds.length > 100) {
      _recentNotificationIds.remove(_recentNotificationIds.first);
    }

    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    _localNotifications.show(
      id: dedupeId.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_notifications_channel',
          'Chat Notifications',
          importance: Importance.max,
          priority: Priority.high,
          tag: dedupeId,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    NotificationNavigationService.instance.navigate(message.data);
  }

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
