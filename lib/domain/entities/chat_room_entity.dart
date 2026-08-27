import 'package:equatable/equatable.dart';
import 'chat_room_type.dart';
import 'message_entity.dart';

class ChatRoomEntity extends Equatable {
  final String roomId;
  final ChatRoomType roomType;
  final List<String> participants;
  final MessageEntity? lastMessage;
  final Map<String, int> unreadCount;
  final Map<String, bool> typingStatus;
  final DateTime updatedAt;
  final String? groupName;
  final String? groupDescription;
  final String? groupImage;
  final List<String> adminIds;
  final String? createdBy;

  const ChatRoomEntity({
    required this.roomId,
    this.roomType = ChatRoomType.direct,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
    required this.typingStatus,
    required this.updatedAt,
    this.groupName,
    this.groupDescription,
    this.groupImage,
    this.adminIds = const [],
    this.createdBy,
  });

  bool get isGroup => roomType == ChatRoomType.group;

  @override
  List<Object?> get props => [
        roomId,
        roomType,
        participants,
        lastMessage,
        unreadCount,
        typingStatus,
        updatedAt,
        groupName,
        groupDescription,
        groupImage,
        adminIds,
        createdBy,
      ];
}
