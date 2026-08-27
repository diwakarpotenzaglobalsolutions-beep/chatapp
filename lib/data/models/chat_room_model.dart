import '../../domain/entities/chat_room_entity.dart';
import '../../domain/entities/chat_room_type.dart';
import 'message_model.dart';

class ChatRoomModel extends ChatRoomEntity {
  const ChatRoomModel({
    required super.roomId,
    super.roomType = ChatRoomType.direct,
    required super.participants,
    super.lastMessage,
    required super.unreadCount,
    required super.typingStatus,
    required super.updatedAt,
    super.groupName,
    super.groupDescription,
    super.groupImage,
    super.adminIds = const [],
    super.createdBy,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatRoomModel(
      roomId: id,
      roomType: json['roomType'] == 'group' ? ChatRoomType.group : ChatRoomType.direct,
      participants: List<String>.from(json['participants'] as List? ?? []),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>, '')
          : null,
      unreadCount: Map<String, int>.from(json['unreadCount'] as Map? ?? {}),
      typingStatus: Map<String, bool>.from(json['typingStatus'] as Map? ?? {}),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      groupName: json['groupName'] as String?,
      groupDescription: json['groupDescription'] as String?,
      groupImage: json['groupImage'] as String?,
      adminIds: List<String>.from(json['adminIds'] as List? ?? []),
      createdBy: json['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomType': roomType.name,
      'participants': participants,
      'lastMessage': lastMessage != null ? MessageModel.fromEntity(lastMessage!).toJson() : null,
      'unreadCount': unreadCount,
      'typingStatus': typingStatus,
      'updatedAt': updatedAt.toIso8601String(),
      'groupName': groupName,
      'groupDescription': groupDescription,
      'groupImage': groupImage,
      'adminIds': adminIds,
      'createdBy': createdBy,
    };
  }

  factory ChatRoomModel.fromEntity(ChatRoomEntity entity) {
    return ChatRoomModel(
      roomId: entity.roomId,
      roomType: entity.roomType,
      participants: entity.participants,
      lastMessage: entity.lastMessage,
      unreadCount: entity.unreadCount,
      typingStatus: entity.typingStatus,
      updatedAt: entity.updatedAt,
      groupName: entity.groupName,
      groupDescription: entity.groupDescription,
      groupImage: entity.groupImage,
      adminIds: entity.adminIds,
      createdBy: entity.createdBy,
    );
  }
}
