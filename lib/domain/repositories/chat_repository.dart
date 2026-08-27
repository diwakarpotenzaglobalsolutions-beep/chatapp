import '../entities/chat_request_entity.dart';
import '../entities/chat_room_entity.dart';
import '../entities/message_entity.dart';
import '../entities/user_entity.dart';

abstract class ChatRepository {
  Stream<List<ChatRoomEntity>> getChatRooms(String uid);
  Stream<ChatRoomEntity?> getChatRoom(String roomId);
  Stream<List<MessageEntity>> getMessages(String roomId, String currentUserId);
  Future<void> sendMessage(String roomId, MessageEntity message);
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
  Stream<UserEntity?> getUserPresence(String uid);
  Stream<Map<String, bool>> getTypingStatus(String roomId);
  Future<void> markMessagesAsSeen(String roomId, String currentUserId);

  // Chat Request operations
  Future<void> sendChatRequest(ChatRequestEntity request);
  Future<void> updateChatRequestStatus(String requestId, ChatRequestStatus status);
  Stream<List<ChatRequestEntity>> getChatRequests(String userId);
  Stream<ChatRequestEntity?> getChatRequestBetweenUsers(String user1, String user2);

  // Active Chat tracking
  Future<void> setActiveChatRoom(String userId, String? roomId);
}