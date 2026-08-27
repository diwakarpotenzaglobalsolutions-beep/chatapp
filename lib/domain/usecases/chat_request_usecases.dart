import '../entities/chat_request_entity.dart';
import '../repositories/chat_repository.dart';

class SendChatRequestUseCase {
  final ChatRepository repository;

  SendChatRequestUseCase(this.repository);

  Future<void> call(ChatRequestEntity request) async {
    return repository.sendChatRequest(request);
  }
}

class UpdateChatRequestStatusUseCase {
  final ChatRepository repository;

  UpdateChatRequestStatusUseCase(this.repository);

  Future<void> call(String requestId, ChatRequestStatus status) async {
    return repository.updateChatRequestStatus(requestId, status);
  }
}

class GetChatRequestsUseCase {
  final ChatRepository repository;

  GetChatRequestsUseCase(this.repository);

  Stream<List<ChatRequestEntity>> call(String userId) {
    return repository.getChatRequests(userId);
  }
}

class GetChatRequestBetweenUsersUseCase {
  final ChatRepository repository;

  GetChatRequestBetweenUsersUseCase(this.repository);

  Stream<ChatRequestEntity?> call(String user1, String user2) {
    return repository.getChatRequestBetweenUsers(user1, user2);
  }
}

class SetActiveChatRoomUseCase {
  final ChatRepository repository;

  SetActiveChatRoomUseCase(this.repository);

  Future<void> call(String userId, String? roomId) async {
    return repository.setActiveChatRoom(userId, roomId);
  }
}
