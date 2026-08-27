import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/user_entity.dart';

class ConversationSearchHelper {
  static List<ChatRoomEntity> filterRooms({
    required List<ChatRoomEntity> rooms,
    required String query,
    required String currentUserId,
    Map<String, UserEntity> peerProfiles = const {},
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return rooms;

    final terms = trimmed.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    return rooms.where((room) {
      final haystack = _buildSearchHaystack(
        room: room,
        currentUserId: currentUserId,
        peerProfiles: peerProfiles,
      );
      return terms.every(haystack.contains);
    }).toList();
  }

  static String _buildSearchHaystack({
    required ChatRoomEntity room,
    required String currentUserId,
    required Map<String, UserEntity> peerProfiles,
  }) {
    final parts = <String>[];

    if (room.isGroup) {
      parts.add(room.groupName ?? 'group');
    } else {
      final peerId = room.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      final peer = peerProfiles[peerId];
      if (peer != null) {
        parts.addAll([peer.fullName, peer.username, '@${peer.username}']);
      }
    }

    final last = room.lastMessage;
    if (last != null) {
      parts.addAll([
        last.content,
        last.senderName,
        last.fileName ?? '',
        _messageTypeLabel(last),
      ]);
    }

    return parts.join(' ').toLowerCase();
  }

  static String _messageTypeLabel(MessageEntity message) {
    switch (message.type) {
      case MessageType.image:
        return 'image photo picture';
      case MessageType.video:
        return 'video';
      case MessageType.voice:
        return 'voice audio message';
      case MessageType.file:
        return 'document file pdf doc zip';
      case MessageType.location:
        return 'location map';
      case MessageType.text:
        return message.content;
    }
  }
}
