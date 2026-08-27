import 'package:equatable/equatable.dart';

enum CallType { audio, video }

enum CallStatus {
  ringing,
  connecting,
  connected,
  completed,
  missed,
  rejected,
  busy,
  failed,
  timeout,
  cancelled,
}

class CallHistoryEntity extends Equatable {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerImage;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final CallType callType;
  final CallStatus status;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> participants;
  final String? chatRoomId;

  const CallHistoryEntity({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerImage = '',
    required this.receiverId,
    required this.receiverName,
    this.receiverImage = '',
    required this.callType,
    required this.status,
    this.durationSeconds = 0,
    required this.startedAt,
    this.endedAt,
    required this.participants,
    this.chatRoomId,
  });

  bool isIncomingFor(String userId) => receiverId == userId;
  bool isOutgoingFor(String userId) => callerId == userId;
  bool isMissedFor(String userId) =>
      isIncomingFor(userId) &&
      (status == CallStatus.missed ||
          status == CallStatus.timeout ||
          status == CallStatus.rejected);

  String peerIdFor(String userId) => callerId == userId ? receiverId : callerId;
  String peerNameFor(String userId) => callerId == userId ? receiverName : callerName;
  String peerImageFor(String userId) => callerId == userId ? receiverImage : callerImage;

  @override
  List<Object?> get props => [
        callId,
        callerId,
        callerName,
        callerImage,
        receiverId,
        receiverName,
        receiverImage,
        callType,
        status,
        durationSeconds,
        startedAt,
        endedAt,
        participants,
        chatRoomId,
      ];
}
