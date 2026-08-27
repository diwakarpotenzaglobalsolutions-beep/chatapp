import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_request_model.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/services/fcm_push_service.dart';
import '../../core/utils/chat_room_deduplicator.dart';
import '../../domain/entities/chat_request_entity.dart';
import '../../domain/entities/chat_room_type.dart';
import '../../domain/entities/message_entity.dart';
import 'block_remote_data_source.dart';

abstract class ChatRemoteDataSource {
  Stream<List<ChatRoomModel>> getChatRooms(String uid);
  Stream<List<MessageModel>> getMessages(String roomId, String currentUserId);
  Future<void> sendMessage(String roomId, MessageModel message);
  Future<void> deleteMessageForMe({
    required String roomId,
    required String messageId,
    required String userId,
  });
  Future<void> deleteMessageForEveryone({
    required String roomId,
    required String messageId,
    required String senderId,
  });
  Future<void> updateMessageStatus(String roomId, String messageId, MessageStatus status);
  Future<void> updateTypingStatus(String roomId, String uid, bool isTyping);
  Future<void> updateUserPresence(String uid, bool isOnline);
  Future<String> getOrCreateChatRoom(String uid1, String uid2);
  Stream<UserModel?> getUserPresence(String uid);
  Stream<Map<String, bool>> getTypingStatus(String roomId);
  Future<void> markMessagesAsSeen(String roomId, String currentUserId);
  Stream<ChatRoomModel?> getChatRoom(String roomId);

  Future<void> sendChatRequest(ChatRequestModel request);
  Future<void> updateChatRequestStatus(String requestId, ChatRequestStatus status);
  Stream<List<ChatRequestModel>> getChatRequests(String userId);
  Stream<ChatRequestModel?> getChatRequestBetweenUsers(String user1, String user2);
  Future<void> setActiveChatRoom(String userId, String? roomId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmPushService _fcmPushService;
  final BlockRemoteDataSource _blockRemoteDataSource;

  ChatRemoteDataSourceImpl({
    required FcmPushService fcmPushService,
    required BlockRemoteDataSource blockRemoteDataSource,
  })  : _fcmPushService = fcmPushService,
        _blockRemoteDataSource = blockRemoteDataSource;

  @override
  Stream<List<ChatRoomModel>> getChatRooms(String uid) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map((doc) => ChatRoomModel.fromJson(doc.data(), doc.id))
              .toList();
          return ChatRoomDeduplicator.deduplicate(rooms, uid);
        });
  }

  @override
  Stream<ChatRoomModel?> getChatRoom(String roomId) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ChatRoomModel.fromJson(snap.data()!, snap.id);
    });
  }

  @override
  Stream<List<MessageModel>> getMessages(String roomId, String currentUserId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
              .where((message) => message.isVisibleTo(currentUserId))
              .toList();
        });
  }

  @override
  Future<void> sendMessage(String roomId, MessageModel message) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final roomData = roomDoc.data()!;
    final isGroup = roomData['roomType'] == ChatRoomType.group.name;
    final participants = List<String>.from(roomData['participants'] as List? ?? []);
    final unreadCountMap = Map<String, int>.from(roomData['unreadCount'] as Map? ?? {});

    if (!isGroup) {
      final blocked = await _blockRemoteDataSource.isBlockedEitherWay(
        message.senderId,
        message.receiverId,
      );
      if (blocked) {
        throw const CommunicationBlockedException();
      }
    }

    MessageModel finalMessage;

    if (isGroup) {
      final readBy = <String, String>{
        message.senderId: DateTime.now().toIso8601String(),
      };
      finalMessage = MessageModel(
        messageId: message.messageId,
        senderId: message.senderId,
        senderName: message.senderName,
        receiverId: '',
        content: message.content,
        type: message.type,
        timestamp: message.timestamp,
        status: MessageStatus.delivered,
        mediaUrl: message.mediaUrl,
        duration: message.duration,
        latitude: message.latitude,
        longitude: message.longitude,
        fileName: message.fileName,
        fileSize: message.fileSize,
        readBy: readBy,
      );

      for (final uid in participants) {
        if (uid == message.senderId) continue;
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final activeRoom = userDoc.data()?['activeChatRoomId'] as String?;
        if (activeRoom == roomId) {
          readBy[uid] = DateTime.now().toIso8601String();
        } else {
          unreadCountMap[uid] = (unreadCountMap[uid] ?? 0) + 1;
        }
      }

      final others = participants.where((id) => id != message.senderId).toList();
      final allOthersRead = others.every(readBy.containsKey);
      if (allOthersRead && others.isNotEmpty) {
        finalMessage = MessageModel(
          messageId: finalMessage.messageId,
          senderId: finalMessage.senderId,
          senderName: finalMessage.senderName,
          receiverId: finalMessage.receiverId,
          content: finalMessage.content,
          type: finalMessage.type,
          timestamp: finalMessage.timestamp,
          status: MessageStatus.seen,
          mediaUrl: finalMessage.mediaUrl,
          duration: finalMessage.duration,
          latitude: finalMessage.latitude,
          longitude: finalMessage.longitude,
          fileName: finalMessage.fileName,
          fileSize: finalMessage.fileSize,
          readBy: readBy,
        );
      } else {
        finalMessage = MessageModel(
          messageId: finalMessage.messageId,
          senderId: finalMessage.senderId,
          senderName: finalMessage.senderName,
          receiverId: finalMessage.receiverId,
          content: finalMessage.content,
          type: finalMessage.type,
          timestamp: finalMessage.timestamp,
          status: MessageStatus.delivered,
          mediaUrl: finalMessage.mediaUrl,
          duration: finalMessage.duration,
          latitude: finalMessage.latitude,
          longitude: finalMessage.longitude,
          fileName: finalMessage.fileName,
          fileSize: finalMessage.fileSize,
          readBy: readBy,
        );
      }
    } else {
      final receiverId = message.receiverId;
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverActiveRoom = receiverDoc.data()?['activeChatRoomId'] as String?;
      final isReceiverActiveInRoom = receiverActiveRoom == roomId;
      final initialStatus = isReceiverActiveInRoom ? MessageStatus.seen : message.status;

      finalMessage = MessageModel(
        messageId: message.messageId,
        senderId: message.senderId,
        senderName: message.senderName,
        receiverId: message.receiverId,
        content: message.content,
        type: message.type,
        timestamp: message.timestamp,
        status: initialStatus,
        mediaUrl: message.mediaUrl,
        duration: message.duration,
        latitude: message.latitude,
        longitude: message.longitude,
        fileName: message.fileName,
        fileSize: message.fileSize,
      );

      if (!isReceiverActiveInRoom) {
        unreadCountMap[receiverId] = (unreadCountMap[receiverId] ?? 0) + 1;
      }
    }

    final batch = _firestore.batch();
    final messageRef = roomRef.collection('messages').doc(message.messageId);
    batch.set(messageRef, finalMessage.toJson());
    batch.update(roomRef, {
      'lastMessage': finalMessage.toJson(),
      'updatedAt': finalMessage.timestamp.toIso8601String(),
      'unreadCount': unreadCountMap,
    });
    await batch.commit();

    await _dispatchMessageNotifications(
      roomId: roomId,
      roomData: roomData,
      isGroup: isGroup,
      message: finalMessage,
      participants: participants,
    );
  }

  Future<void> _dispatchMessageNotifications({
    required String roomId,
    required Map<String, dynamic> roomData,
    required bool isGroup,
    required MessageModel message,
    required List<String> participants,
  }) async {
    final preview = _messagePreview(message);
    final senderDoc = await _firestore.collection('users').doc(message.senderId).get();
    final senderData = senderDoc.data() ?? {};
    final senderName = message.senderName.isNotEmpty
        ? message.senderName
        : (senderData['fullName'] as String? ?? 'Someone');
    final senderImage = senderData['profilePicture'] as String? ?? '';

    if (isGroup) {
      final groupName = roomData['groupName'] as String? ?? 'Group';
      for (final uid in participants) {
        if (uid == message.senderId) continue;
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final activeRoom = userDoc.data()?['activeChatRoomId'] as String?;
        if (activeRoom == roomId) continue;

        await _fcmPushService.sendMessageNotification(
          receiverId: uid,
          senderName: senderName,
          messagePreview: preview,
          roomId: roomId,
          peerId: message.senderId,
          peerName: senderName,
          peerImage: senderImage,
          messageId: message.messageId,
          isGroup: true,
          groupName: groupName,
        );
      }
    } else {
      final receiverId = message.receiverId;
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final activeRoom = receiverDoc.data()?['activeChatRoomId'] as String?;
      if (activeRoom == roomId) return;

      await _fcmPushService.sendMessageNotification(
        receiverId: receiverId,
        senderName: senderName,
        messagePreview: preview,
        roomId: roomId,
        peerId: message.senderId,
        peerName: senderName,
        peerImage: senderImage,
        messageId: message.messageId,
      );
    }
  }

  String _messagePreview(MessageModel message) {
    switch (message.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.location:
        return '📍 Location';
      case MessageType.file:
        return '📄 ${message.fileName?.isNotEmpty == true ? message.fileName : 'Document'}';
      case MessageType.text:
        return message.content;
    }
  }

  @override
  Future<void> deleteMessageForMe({
    required String roomId,
    required String messageId,
    required String userId,
  }) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor.$userId': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String roomId,
    required String messageId,
    required String senderId,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc(messageId);
    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) return;

    final data = messageDoc.data()!;
    if (data['senderId'] != senderId) {
      throw Exception('Only the sender can delete this message for everyone');
    }

    await messageRef.update({
      'deletedForEveryone': true,
      'content': MessageEntity.deletedPlaceholder,
      'type': MessageType.text.name,
      'mediaUrl': FieldValue.delete(),
      'durationMs': FieldValue.delete(),
      'latitude': FieldValue.delete(),
      'longitude': FieldValue.delete(),
      'fileName': FieldValue.delete(),
      'fileSize': FieldValue.delete(),
    });

    final roomDoc = await roomRef.get();
    final lastMessage = roomDoc.data()?['lastMessage'] as Map?;
    if (lastMessage != null && lastMessage['messageId'] == messageId) {
      await roomRef.update({
        'lastMessage.deletedForEveryone': true,
        'lastMessage.content': MessageEntity.deletedPlaceholder,
        'lastMessage.type': MessageType.text.name,
        'lastMessage.mediaUrl': FieldValue.delete(),
      });
    }
  }

  @override
  Future<void> updateMessageStatus(String roomId, String messageId, MessageStatus status) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'status': status.name});
  }

  @override
  Future<void> updateTypingStatus(String roomId, String uid, bool isTyping) async {
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'typingStatus.$uid': isTyping,
    });
  }

  @override
  Future<void> updateUserPresence(String uid, bool isOnline) async {
    if (isOnline) {
      await _firestore.collection('users').doc(uid).update({
        'onlineStatus': true,
      });
    } else {
      await _firestore.collection('users').doc(uid).update({
        'onlineStatus': false,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<String> getOrCreateChatRoom(String uid1, String uid2) async {
    final existingId = await _findExistingDirectRoomId(uid1, uid2);
    if (existingId != null) return existingId;

    final directKey = ChatRoomDeduplicator.directRoomKey(uid1, uid2);
    final roomId = _firestore.collection('chat_rooms').doc().id;
    final newRoom = ChatRoomModel(
      roomId: roomId,
      roomType: ChatRoomType.direct,
      participants: [uid1, uid2],
      unreadCount: {uid1: 0, uid2: 0},
      typingStatus: {uid1: false, uid2: false},
      updatedAt: DateTime.now(),
    );

    final roomJson = newRoom.toJson()..['directKey'] = directKey;
    await _firestore.collection('chat_rooms').doc(roomId).set(roomJson);
    return roomId;
  }

  Future<String?> _findExistingDirectRoomId(String uid1, String uid2) async {
    final directKey = ChatRoomDeduplicator.directRoomKey(uid1, uid2);

    final keyQuery = await _firestore
        .collection('chat_rooms')
        .where('directKey', isEqualTo: directKey)
        .limit(1)
        .get();
    if (keyQuery.docs.isNotEmpty) return keyQuery.docs.first.id;

    ChatRoomModel? bestMatch;
    for (final uid in [uid1, uid2]) {
      final query = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: uid)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['roomType'] == ChatRoomType.group.name) continue;
        final participants = List<String>.from(data['participants'] as List? ?? []);
        if (!participants.contains(uid1) || !participants.contains(uid2)) continue;

        final room = ChatRoomModel.fromJson(data, doc.id);
        if (bestMatch == null || room.updatedAt.isAfter(bestMatch.updatedAt)) {
          bestMatch = room;
        }
      }
    }

    if (bestMatch != null) {
      if (bestMatch.roomId.isNotEmpty) {
        await _firestore.collection('chat_rooms').doc(bestMatch.roomId).update({
          'directKey': directKey,
        });
      }
      return bestMatch.roomId;
    }

    return null;
  }

  @override
  Stream<UserModel?> getUserPresence(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromJson(snapshot.data()!, uid);
    });
  }

  @override
  Stream<Map<String, bool>> getTypingStatus(String roomId) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return {};
      final typingMap = snapshot.data()!['typingStatus'] as Map? ?? {};
      return Map<String, bool>.from(typingMap);
    });
  }

  @override
  Future<void> markMessagesAsSeen(String roomId, String currentUserId) async {
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) return;

    final roomData = roomDoc.data()!;
    final isGroup = roomData['roomType'] == ChatRoomType.group.name;
    final participants = List<String>.from(roomData['participants'] as List? ?? []);

    final messagesSnap = await roomRef
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();

    for (final doc in messagesSnap.docs) {
      final msg = MessageModel.fromJson(doc.data(), doc.id);
      if (isGroup) {
        if (!msg.readBy.containsKey(currentUserId)) {
          final updatedReadBy = Map<String, String>.from(msg.readBy);
          updatedReadBy[currentUserId] = now;
          final others = participants.where((id) => id != msg.senderId).toList();
          final allRead = others.every(updatedReadBy.containsKey);
          batch.update(doc.reference, {
            'readBy.$currentUserId': now,
            if (allRead) 'status': MessageStatus.seen.name,
          });
        }
      } else if (msg.status != MessageStatus.seen) {
        batch.update(doc.reference, {'status': MessageStatus.seen.name});
      }
    }

    batch.update(roomRef, {'unreadCount.$currentUserId': 0});
    await batch.commit();
  }

  @override
  Future<void> sendChatRequest(ChatRequestModel request) async {
    final blocked = await _blockRemoteDataSource.isBlockedEitherWay(
      request.senderId,
      request.receiverId,
    );
    if (blocked) {
      throw const CommunicationBlockedException(
        'Cannot send chat request to this user',
      );
    }

    final forwardQuery = await _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: request.senderId)
        .where('receiverId', isEqualTo: request.receiverId)
        .get();
    if (forwardQuery.docs.isNotEmpty) return;

    final reverseQuery = await _firestore
        .collection('chat_requests')
        .where('senderId', isEqualTo: request.receiverId)
        .where('receiverId', isEqualTo: request.senderId)
        .get();
    for (final doc in reverseQuery.docs) {
      final status = doc.data()['status'] as String?;
      if (status == 'pending' || status == 'accepted') return;
    }

    await _firestore.collection('chat_requests').doc(request.requestId).set(request.toJson());

    await _fcmPushService.sendChatRequestNotification(
      receiverId: request.receiverId,
      senderName: request.senderName,
      requestId: request.requestId,
    );
  }

  @override
  Future<void> updateChatRequestStatus(String requestId, ChatRequestStatus status) async {
    final docRef = _firestore.collection('chat_requests').doc(requestId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    await docRef.update({
      'status': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (status == ChatRequestStatus.accepted) {
      final data = docSnap.data()!;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;
      final roomId = await getOrCreateChatRoom(senderId, receiverId);

      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data() ?? {};
      final accepterName = receiverData['fullName'] as String? ?? 'User';
      final accepterImage = receiverData['profilePicture'] as String? ?? '';

      await _fcmPushService.sendChatRequestAcceptedNotification(
        receiverId: senderId,
        accepterName: accepterName,
        roomId: roomId,
        peerId: receiverId,
        peerName: accepterName,
        peerImage: accepterImage,
      );
    }
  }

  @override
  Stream<List<ChatRequestModel>> getChatRequests(String userId) {
    return _firestore
        .collection('chat_requests')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => ChatRequestModel.fromJson(doc.data(), doc.id))
              .toList();
          requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return requests;
        });
  }

  @override
  Stream<ChatRequestModel?> getChatRequestBetweenUsers(String user1, String user2) {
    final sortedParticipants = [user1, user2]..sort();
    return _firestore
        .collection('chat_requests')
        .where('participants', isEqualTo: sortedParticipants)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ChatRequestModel.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
        });
  }

  @override
  Future<void> setActiveChatRoom(String userId, String? roomId) async {
    await _firestore.collection('users').doc(userId).update({
      'activeChatRoomId': roomId,
    });
  }
}
