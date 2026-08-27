import '../../domain/entities/call_history_entity.dart';

class CallHistoryModel extends CallHistoryEntity {
  const CallHistoryModel({
    required super.callId,
    required super.callerId,
    required super.callerName,
    super.callerImage,
    required super.receiverId,
    required super.receiverName,
    super.receiverImage,
    required super.callType,
    required super.status,
    super.durationSeconds,
    required super.startedAt,
    super.endedAt,
    required super.participants,
    super.chatRoomId,
  });

  factory CallHistoryModel.fromJson(Map<String, dynamic> json, String id) {
    return CallHistoryModel(
      callId: id,
      callerId: json['callerId'] as String? ?? '',
      callerName: json['callerName'] as String? ?? '',
      callerImage: json['callerImage'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      receiverImage: json['receiverImage'] as String? ?? '',
      callType: json['callType'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      participants: List<String>.from(json['participants'] as List? ?? []),
      chatRoomId: json['chatRoomId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerImage': callerImage,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImage': receiverImage,
      'callType': callType.name,
      'status': status.name,
      'durationSeconds': durationSeconds,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'participants': participants,
      'chatRoomId': chatRoomId,
    };
  }

  factory CallHistoryModel.fromEntity(CallHistoryEntity entity) {
    return CallHistoryModel(
      callId: entity.callId,
      callerId: entity.callerId,
      callerName: entity.callerName,
      callerImage: entity.callerImage,
      receiverId: entity.receiverId,
      receiverName: entity.receiverName,
      receiverImage: entity.receiverImage,
      callType: entity.callType,
      status: entity.status,
      durationSeconds: entity.durationSeconds,
      startedAt: entity.startedAt,
      endedAt: entity.endedAt,
      participants: entity.participants,
      chatRoomId: entity.chatRoomId,
    );
  }
}
