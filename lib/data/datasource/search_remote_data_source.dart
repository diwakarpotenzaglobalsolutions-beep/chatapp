import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

abstract class SearchRemoteDataSource {
  Future<List<UserModel>> searchUsers(String query);
  Future<List<MessageModel>> searchMessages(String roomId, String query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    // Empty query → return all users
    if (query.trim().isEmpty) {
      final snapshot = await _firestore.collection('users').get();
      final users = snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data(), doc.id))
          .toList();
      users.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return users;
    }

    final lowercaseQuery = query.toLowerCase();

    // Query matching by username prefix
    final usernameQuery = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: lowercaseQuery)
        .where('username', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
        .get();

    // Query matching by fullName prefix
    final nameQuery = await _firestore
        .collection('users')
        .where('fullName', isGreaterThanOrEqualTo: query)
        .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    final Set<String> uids = {};
    final List<UserModel> results = [];

    for (final doc in usernameQuery.docs) {
      final user = UserModel.fromJson(doc.data(), doc.id);
      if (uids.add(user.uid)) {
        results.add(user);
      }
    }

    for (final doc in nameQuery.docs) {
      final user = UserModel.fromJson(doc.data(), doc.id);
      if (uids.add(user.uid)) {
        results.add(user);
      }
    }

    results.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return results;
  }

  @override
  Future<List<MessageModel>> searchMessages(String roomId, String query) async {
    if (query.trim().isEmpty) return [];

    final snapshot = await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .get();

    final lowercaseQuery = query.toLowerCase();

    return snapshot.docs
        .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
        .where((msg) {
          final searchable = [
            msg.content,
            msg.fileName ?? '',
            msg.senderName,
          ].join(' ').toLowerCase();
          return searchable.contains(lowercaseQuery);
        })
        .toList();
  }
}