import 'package:equatable/equatable.dart';

enum MessageType { text, image, video, voice, file, location }

enum MessageStatus { sent, delivered, seen }

class MessageEntity extends Equatable {
  static const deletedPlaceholder = 'This message was deleted.';

  final String messageId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final String? mediaUrl;
  final Duration? duration;
  final double? latitude;
  final double? longitude;
  final String? fileName;
  final String? fileSize;
  final Map<String, String> readBy;
  final bool isDeletedForEveryone;
  final Map<String, String> deletedFor;

  const MessageEntity({
    required this.messageId,
    required this.senderId,
    this.senderName = '',
    required this.receiverId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.status,
    this.mediaUrl,
    this.duration,
    this.latitude,
    this.longitude,
    this.fileName,
    this.fileSize,
    this.readBy = const {},
    this.isDeletedForEveryone = false,
    this.deletedFor = const {},
  });

  bool isVisibleTo(String userId) => !deletedFor.containsKey(userId);

  bool get showsDeletedPlaceholder => isDeletedForEveryone;

  @override
  List<Object?> get props => [
        messageId,
        senderId,
        senderName,
        receiverId,
        content,
        type,
        timestamp,
        status,
        mediaUrl,
        duration,
        latitude,
        longitude,
        fileName,
        fileSize,
        readBy,
        isDeletedForEveryone,
        deletedFor,
      ];
}
