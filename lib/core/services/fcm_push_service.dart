import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../constants/notification_types.dart';
import '../utils/fcm_oauth_token_helper.dart';
import 'fcm_oauth_token_cache.dart';

class FcmPushService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmOAuthTokenCache _tokenCache;

  FcmPushService({required this._tokenCache});

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      await _sendToToken(token: fcmToken, title: title, body: body, data: data);
    } catch (e) {
      developer.log('FCM sendToUser error: $e');
    }
  }

  Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    await _send(
      target: {'topic': topic},
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String messagePreview,
    required String roomId,
    required String peerId,
    required String peerName,
    required String peerImage,
    required String messageId,
    bool isGroup = false,
    String groupName = '',
  }) async {
    await sendToUser(
      userId: receiverId,
      title: isGroup ? groupName : senderName,
      body: isGroup ? '$senderName: $messagePreview' : messagePreview,
      data: {
        'type': isGroup ? NotificationTypes.groupMessage : NotificationTypes.message,
        'roomId': roomId,
        'peerId': peerId,
        'peerName': peerName,
        'peerImage': peerImage,
        'groupName': groupName,
        'dedupeId': messageId,
      },
    );
  }

  Future<void> sendChatRequestNotification({
    required String receiverId,
    required String senderName,
    required String requestId,
  }) async {
    await sendToUser(
      userId: receiverId,
      title: 'New chat request',
      body: '$senderName wants to chat with you',
      data: {
        'type': NotificationTypes.chatRequest,
        'requestId': requestId,
        'senderName': senderName,
        'dedupeId': 'request_$requestId',
      },
    );
  }

  Future<void> sendChatRequestAcceptedNotification({
    required String receiverId,
    required String accepterName,
    required String roomId,
    required String peerId,
    required String peerName,
    required String peerImage,
  }) async {
    await sendToUser(
      userId: receiverId,
      title: 'Chat request accepted',
      body: '$accepterName accepted your chat request',
      data: {
        'type': NotificationTypes.chatRequestAccepted,
        'roomId': roomId,
        'peerId': peerId,
        'peerName': peerName,
        'peerImage': peerImage,
        'dedupeId': 'accepted_$roomId',
      },
    );
  }

  Future<void> sendCallNotification({
    required String receiverId,
    required String callerName,
    required String callId,
    required bool isVideo,
    String callerImage = '',
    String? chatRoomId,
  }) async {
    await sendToUser(
      userId: receiverId,
      title: isVideo ? 'Incoming video call' : 'Incoming audio call',
      body: '$callerName is calling you',
      data: {
        'type': isVideo ? NotificationTypes.videoCall : NotificationTypes.audioCall,
        'callId': callId,
        'callerName': callerName,
        'callerImage': callerImage,
        if (chatRoomId != null) 'roomId': chatRoomId,
        'dedupeId': 'call_$callId',
      },
    );
  }

  Future<void> _sendToToken({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    await _send(
      target: {'token': token},
      title: title,
      body: body,
      data: data,
    );
  }

  Future<void> _send({
    required Map<String, String> target,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    final accessToken = await _tokenCache.getValidToken();
    final projectId = await FcmOAuthTokenHelper.getProjectId();
    if (accessToken == null || projectId == null) return;

    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
    );

    final payload = {
      'message': {
        ...target,
        'notification': {'title': title, 'body': body},
        'data': data,
        'android': {
          'priority': 'HIGH',
          'notification': {
            'channel_id': 'chat_notifications_channel',
            'tag': data['dedupeId'] ?? title,
          },
        },
        'apns': {
          'headers': {'apns-priority': '10'},
          'payload': {
            'aps': {'sound': 'default', 'badge': 1},
          },
        },
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 401) {
      await _tokenCache.clear();
      developer.log('FCM token expired, will refresh on next send');
    } else if (response.statusCode >= 400) {
      developer.log('FCM send failed: ${response.statusCode} ${response.body}');
    }
  }
}
