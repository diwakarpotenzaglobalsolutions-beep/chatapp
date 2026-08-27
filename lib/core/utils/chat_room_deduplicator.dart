import '../../data/models/chat_room_model.dart';
import '../../domain/entities/chat_room_type.dart';

/// Removes duplicate chat rooms — keeps one entry per roomId and one direct chat per peer pair.
class ChatRoomDeduplicator {
  ChatRoomDeduplicator._();

  static String directRoomKey(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static List<ChatRoomModel> deduplicate(List<ChatRoomModel> rooms, String currentUserId) {
    final uniqueById = <String, ChatRoomModel>{};
    for (final room in rooms) {
      uniqueById[room.roomId] = room;
    }

    final directByPeer = <String, ChatRoomModel>{};
    final groups = <ChatRoomModel>[];

    for (final room in uniqueById.values) {
      if (room.roomType == ChatRoomType.group) {
        groups.add(room);
        continue;
      }

      final peerId = room.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (peerId.isEmpty) continue;

      final key = directRoomKey(currentUserId, peerId);
      final existing = directByPeer[key];
      if (existing == null || room.updatedAt.isAfter(existing.updatedAt)) {
        directByPeer[key] = room;
      }
    }

    final result = [...groups, ...directByPeer.values];
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }
}
