import '../../domain/entities/chat_request_entity.dart';
import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasource/chat_remote_data_source.dart';
import '../models/chat_request_model.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ChatRoomEntity>> getChatRooms(String uid) =>
      remoteDataSource.getChatRooms(uid);

  @override
  Stream<ChatRoomEntity?> getChatRoom(String roomId) =>
      remoteDataSource.getChatRoom(roomId);

  @override
  Stream<List<MessageEntity>> getMessages(String roomId, String currentUserId) =>
      remoteDataSource.getMessages(roomId, currentUserId);

  @override
  Future<void> deleteMessageForMe({
    required String roomId,
    required String messageId,
    required String userId,
  }) =>
      remoteDataSource.deleteMessageForMe(
        roomId: roomId,
        messageId: messageId,
        userId: userId,
      );

  @override
  Future<void> deleteMessageForEveryone({
    required String roomId,
    required String messageId,
    required String senderId,
  }) =>
      remoteDataSource.deleteMessageForEveryone(
        roomId: roomId,
        messageId: messageId,
        senderId: senderId,
      );

  @override
  Future<void> sendMessage(String roomId, MessageEntity message) =>
      remoteDataSource.sendMessage(roomId, MessageModel.fromEntity(message));

  @override
  Future<void> updateMessageStatus(
      String roomId,
      String messageId,
      MessageStatus status,
      ) =>
      remoteDataSource.updateMessageStatus(roomId, messageId, status);

  @override
  Future<void> updateTypingStatus(String roomId, String uid, bool isTyping) =>
      remoteDataSource.updateTypingStatus(roomId, uid, isTyping);

  @override
  Future<void> updateUserPresence(String uid, bool isOnline) =>
      remoteDataSource.updateUserPresence(uid, isOnline);

  @override
  Future<String> getOrCreateChatRoom(String uid1, String uid2) =>
      remoteDataSource.getOrCreateChatRoom(uid1, uid2);

  @override
  Stream<UserEntity?> getUserPresence(String uid) =>
      remoteDataSource.getUserPresence(uid);

  @override
  Stream<Map<String, bool>> getTypingStatus(String roomId) =>
      remoteDataSource.getTypingStatus(roomId);

  @override
  Future<void> markMessagesAsSeen(String roomId, String currentUserId) =>
      remoteDataSource.markMessagesAsSeen(roomId, currentUserId);

  @override
  Future<void> sendChatRequest(ChatRequestEntity request) =>
      remoteDataSource.sendChatRequest(ChatRequestModel.fromEntity(request));

  @override
  Future<void> updateChatRequestStatus(
      String requestId,
      ChatRequestStatus status,
      ) =>
      remoteDataSource.updateChatRequestStatus(requestId, status);

  @override
  Stream<List<ChatRequestEntity>> getChatRequests(String userId) =>
      remoteDataSource.getChatRequests(userId);

  @override
  Stream<ChatRequestEntity?> getChatRequestBetweenUsers(
      String user1,
      String user2,
      ) =>
      remoteDataSource.getChatRequestBetweenUsers(user1, user2);

  @override
  Future<void> setActiveChatRoom(String userId, String? roomId) =>
      remoteDataSource.setActiveChatRoom(userId, roomId);
}