import 'package:equatable/equatable.dart';

enum ChatRequestStatus { pending, accepted, rejected }

class ChatRequestEntity extends Equatable {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final ChatRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatRequestEntity({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        requestId,
        senderId,
        senderName,
        senderImage,
        receiverId,
        receiverName,
        receiverImage,
        status,
        createdAt,
        updatedAt,
      ];
}
