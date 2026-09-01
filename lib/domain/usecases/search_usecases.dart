import '../entities/user_entity.dart';
import '../entities/message_entity.dart';
import '../repositories/search_repository.dart';

class SearchUsersUseCase {
  final SearchRepository repository;
  SearchUsersUseCase(this.repository);

  Future<List<UserEntity>> call(String query) {
    return repository.searchUsers(query);
  }
}

class GetFriendsUseCase {
  final SearchRepository repository;
  GetFriendsUseCase(this.repository);

  Future<List<UserEntity>> call({required String userId, required String query}) {
    return repository.getFriends(userId, query);
  }
}

class SearchMessagesUseCase {
  final SearchRepository repository;
  SearchMessagesUseCase(this.repository);

  Future<List<MessageEntity>> call(String roomId, String query) {
    return repository.searchMessages(roomId, query);
  }
}
