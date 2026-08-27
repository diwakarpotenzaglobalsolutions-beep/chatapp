import '../../domain/entities/call_history_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasource/call_remote_data_source.dart';
import '../models/call_history_model.dart';

class CallRepositoryImpl implements CallRepository {
  final CallRemoteDataSource remoteDataSource;

  CallRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<CallHistoryEntity>> getCallHistory(String userId) =>
      remoteDataSource.getCallHistory(userId);

  @override
  Stream<CallHistoryEntity?> watchActiveCall(String userId) =>
      remoteDataSource.watchActiveCall(userId);

  @override
  Future<void> createCallRecord(CallHistoryEntity call) =>
      remoteDataSource.createCallRecord(CallHistoryModel.fromEntity(call));

  @override
  Future<CallHistoryEntity?> getCallById(String callId) =>
      remoteDataSource.getCallById(callId);

  @override
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    int? durationSeconds,
    DateTime? endedAt,
  }) =>
      remoteDataSource.updateCallStatus(
        callId: callId,
        status: status,
        durationSeconds: durationSeconds,
        endedAt: endedAt,
      );

  @override
  Future<void> setUserCallAvailability(String userId, {required bool isInCall}) =>
      remoteDataSource.setUserCallAvailability(userId, isInCall: isInCall);

  @override
  Future<bool> isUserInCall(String userId) => remoteDataSource.isUserInCall(userId);
}
