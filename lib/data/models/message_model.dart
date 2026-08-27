import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.messageId,
    required super.senderId,
    super.senderName = '',
    required super.receiverId,
    required super.content,
    required super.type,
    required super.timestamp,
    required super.status,
    super.mediaUrl,
    super.duration,
    super.latitude,
    super.longitude,
    super.fileName,
    super.fileSize,
    super.readBy = const {},
    super.isDeletedForEveryone = false,
    super.deletedFor = const {},
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String id) {
    final readByRaw = json['readBy'] as Map? ?? {};
    final readBy = Map<String, String>.from(
      readByRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );

    final deletedForRaw = json['deletedFor'] as Map? ?? {};
    final deletedFor = Map<String, String>.from(
      deletedForRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );

    return MessageModel(
      messageId: id.isNotEmpty ? id : (json['messageId'] as String? ?? ''),
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      mediaUrl: json['mediaUrl'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as String?,
      readBy: readBy,
      isDeletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      deletedFor: deletedFor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'mediaUrl': mediaUrl,
      'durationMs': duration?.inMilliseconds,
      'latitude': latitude,
      'longitude': longitude,
      'fileName': fileName,
      'fileSize': fileSize,
      'readBy': readBy,
      'deletedForEveryone': isDeletedForEveryone,
      'deletedFor': deletedFor,
    };
  }

  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      messageId: entity.messageId,
      senderId: entity.senderId,
      senderName: entity.senderName,
      receiverId: entity.receiverId,
      content: entity.content,
      type: entity.type,
      timestamp: entity.timestamp,
      status: entity.status,
      mediaUrl: entity.mediaUrl,
      duration: entity.duration,
      latitude: entity.latitude,
      longitude: entity.longitude,
      fileName: entity.fileName,
      fileSize: entity.fileSize,
      readBy: entity.readBy,
      isDeletedForEveryone: entity.isDeletedForEveryone,
      deletedFor: entity.deletedFor,
    );
  }
}
