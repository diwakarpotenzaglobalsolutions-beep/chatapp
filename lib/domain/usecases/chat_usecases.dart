import '../entities/chat_room_entity.dart';
import '../entities/message_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/chat_repository.dart';

class GetChatRoomsUseCase {
  final ChatRepository repository;
  GetChatRoomsUseCase(this.repository);

  Stream<List<ChatRoomEntity>> call(String uid) {
    return repository.getChatRooms(uid);
  }
}

class GetChatRoomUseCase {
  final ChatRepository repository;
  GetChatRoomUseCase(this.repository);

  Stream<ChatRoomEntity?> call(String roomId) {
    return repository.getChatRoom(roomId);
  }
}

class GetMessagesUseCase {
  final ChatRepository repository;
  GetMessagesUseCase(this.repository);

  Stream<List<MessageEntity>> call(String roomId, String currentUserId) {
    return repository.getMessages(roomId, currentUserId);
  }
}

class DeleteMessageForMeUseCase {
  final ChatRepository repository;
  DeleteMessageForMeUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String messageId,
    required String userId,
  }) =>
      repository.deleteMessageForMe(
        roomId: roomId,
        messageId: messageId,
        userId: userId,
      );
}

class DeleteMessageForEveryoneUseCase {
  final ChatRepository repository;
  DeleteMessageForEveryoneUseCase(this.repository);

  Future<void> call({
    required String roomId,
    required String messageId,
    required String senderId,
  }) =>
      repository.deleteMessageForEveryone(
        roomId: roomId,
        messageId: messageId,
        senderId: senderId,
      );
}

class SendMessageUseCase {
  final ChatRepository repository;
  SendMessageUseCase(this.repository);

  Future<void> call(String roomId, MessageEntity message) {
    return repository.sendMessage(roomId, message);
  }
}

class UpdateMessageStatusUseCase {
  final ChatRepository repository;
  UpdateMessageStatusUseCase(this.repository);

  Future<void> call(String roomId, String messageId, MessageStatus status) {
    return repository.updateMessageStatus(roomId, messageId, status);
  }
}

class UpdateTypingStatusUseCase {
  final ChatRepository repository;
  UpdateTypingStatusUseCase(this.repository);

  Future<void> call(String roomId, String uid, bool isTyping) {
    return repository.updateTypingStatus(roomId, uid, isTyping);
  }
}

class UpdateUserPresenceUseCase {
  final ChatRepository repository;
  UpdateUserPresenceUseCase(this.repository);

  Future<void> call(String uid, bool isOnline) {
    return repository.updateUserPresence(uid, isOnline);
  }
}

class GetOrCreateChatRoomUseCase {
  final ChatRepository repository;
  GetOrCreateChatRoomUseCase(this.repository);

  Future<String> call(String uid1, String uid2) {
    return repository.getOrCreateChatRoom(uid1, uid2);
  }
}

class GetUserPresenceUseCase {
  final ChatRepository repository;
  GetUserPresenceUseCase(this.repository);

  Stream<UserEntity?> call(String uid) {
    return repository.getUserPresence(uid);
  }
}

class GetTypingStatusUseCase {
  final ChatRepository repository;
  GetTypingStatusUseCase(this.repository);

  Stream<Map<String, bool>> call(String roomId) {
    return repository.getTypingStatus(roomId);
  }
}

class MarkMessagesAsSeenUseCase {
  final ChatRepository repository;
  MarkMessagesAsSeenUseCase(this.repository);

  Future<void> call(String roomId, String currentUserId) {
    return repository.markMessagesAsSeen(roomId, currentUserId);
  }
}
