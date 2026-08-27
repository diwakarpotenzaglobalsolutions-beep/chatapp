import '../entities/user_entity.dart';
import '../entities/message_entity.dart';

abstract class SearchRepository {
  Future<List<UserEntity>> searchUsers(String query);
  Future<List<MessageEntity>> searchMessages(String roomId, String query);
}
