import '../entities/call_history_entity.dart';
import '../repositories/call_repository.dart';

class GetCallHistoryUseCase {
  final CallRepository repository;
  GetCallHistoryUseCase(this.repository);

  Stream<List<CallHistoryEntity>> call(String userId) => repository.getCallHistory(userId);
}

class CreateCallRecordUseCase {
  final CallRepository repository;
  CreateCallRecordUseCase(this.repository);

  Future<void> call(CallHistoryEntity call) => repository.createCallRecord(call);
}

class UpdateCallRecordStatusUseCase {
  final CallRepository repository;
  UpdateCallRecordStatusUseCase(this.repository);

  Future<void> call({
    required String callId,
    required CallStatus status,
    int? durationSeconds,
    DateTime? endedAt,
  }) =>
      repository.updateCallStatus(
        callId: callId,
        status: status,
        durationSeconds: durationSeconds,
        endedAt: endedAt,
      );
}

class IsUserInCallUseCase {
  final CallRepository repository;
  IsUserInCallUseCase(this.repository);

  Future<bool> call(String userId) => repository.isUserInCall(userId);
}

class SetUserCallAvailabilityUseCase {
  final CallRepository repository;
  SetUserCallAvailabilityUseCase(this.repository);

  Future<void> call(String userId, {required bool isInCall}) =>
      repository.setUserCallAvailability(userId, isInCall: isInCall);
}
