import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call_history_model.dart';
import '../../domain/entities/call_history_entity.dart';

abstract class CallRemoteDataSource {
  Stream<List<CallHistoryModel>> getCallHistory(String userId);
  Stream<CallHistoryModel?> watchActiveCall(String userId);
  Future<void> createCallRecord(CallHistoryModel call);
  Future<CallHistoryModel?> getCallById(String callId);
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    int? durationSeconds,
    DateTime? endedAt,
  });
  Future<void> setUserCallAvailability(String userId, {required bool isInCall});
  Future<bool> isUserInCall(String userId);
}

class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CallHistoryModel>> getCallHistory(String userId) {
    return _firestore
        .collection('call_history')
        .where('participants', arrayContains: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CallHistoryModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<CallHistoryModel?> watchActiveCall(String userId) {
    return _firestore
        .collection('call_history')
        .where('participants', arrayContains: userId)
        .where('status', whereIn: ['ringing', 'connecting', 'connected'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return CallHistoryModel.fromJson(doc.data(), doc.id);
        });
  }

  @override
  Future<void> createCallRecord(CallHistoryModel call) async {
    await _firestore.collection('call_history').doc(call.callId).set(
          call.toJson(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<CallHistoryModel?> getCallById(String callId) async {
    final doc = await _firestore.collection('call_history').doc(callId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CallHistoryModel.fromJson(doc.data()!, doc.id);
  }

  @override
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    int? durationSeconds,
    DateTime? endedAt,
  }) async {
    final updates = <String, dynamic>{'status': status.name};
    if (durationSeconds != null) updates['durationSeconds'] = durationSeconds;
    if (endedAt != null) updates['endedAt'] = endedAt.toIso8601String();
    await _firestore.collection('call_history').doc(callId).update(updates);
  }

  @override
  Future<void> setUserCallAvailability(String userId, {required bool isInCall}) async {
    await _firestore.collection('users').doc(userId).update({
      'isInCall': isInCall,
      'lastCallActivity': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<bool> isUserInCall(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['isInCall'] as bool? ?? false;
  }
}
