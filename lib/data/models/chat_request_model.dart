import '../../domain/entities/chat_request_entity.dart';

class ChatRequestModel extends ChatRequestEntity {
  const ChatRequestModel({
    required super.requestId,
    required super.senderId,
    required super.senderName,
    required super.senderImage,
    required super.receiverId,
    required super.receiverName,
    required super.receiverImage,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ChatRequestModel.fromJson(Map<String, dynamic> json, String docId) {
    return ChatRequestModel(
      requestId: docId,
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderImage: json['senderImage'] ?? '',
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverImage: json['receiverImage'] ?? '',
      status: _parseStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final participants = [senderId, receiverId]..sort();
    return {
      'requestId': requestId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImage': receiverImage,
      'status': status.name,
      'participants': participants,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ChatRequestStatus _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'accepted':
        return ChatRequestStatus.accepted;
      case 'rejected':
        return ChatRequestStatus.rejected;
      case 'pending':
      default:
        return ChatRequestStatus.pending;
    }
  }

  factory ChatRequestModel.fromEntity(ChatRequestEntity entity) {
    return ChatRequestModel(
      requestId: entity.requestId,
      senderId: entity.senderId,
      senderName: entity.senderName,
      senderImage: entity.senderImage,
      receiverId: entity.receiverId,
      receiverName: entity.receiverName,
      receiverImage: entity.receiverImage,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
