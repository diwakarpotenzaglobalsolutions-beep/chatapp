import '../../domain/entities/user_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasource/search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;

  SearchRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<UserEntity>> searchUsers(String query) async {
    return await remoteDataSource.searchUsers(query);
  }

  @override
  Future<List<MessageEntity>> searchMessages(String roomId, String query) async {
    return await remoteDataSource.searchMessages(roomId, query);
  }
}
