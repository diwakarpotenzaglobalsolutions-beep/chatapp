import '../entities/call_history_entity.dart';

abstract class CallRepository {
  Stream<List<CallHistoryEntity>> getCallHistory(String userId);
  Stream<CallHistoryEntity?> watchActiveCall(String userId);
  Future<void> createCallRecord(CallHistoryEntity call);
  Future<CallHistoryEntity?> getCallById(String callId);
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    int? durationSeconds,
    DateTime? endedAt,
  });
  Future<void> setUserCallAvailability(String userId, {required bool isInCall});
  Future<bool> isUserInCall(String userId);
}
