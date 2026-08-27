import 'package:uuid/uuid.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import '../constants/zego_config.dart';
import '../../domain/entities/call_history_entity.dart';
import '../../domain/repositories/call_repository.dart';
import 'permission_service.dart';
import 'fcm_push_service.dart';

typedef CallErrorCallback = void Function(String message);

class ZegoCallService {
  final CallRepository _callRepository;
  final PermissionService _permissionService;
  final FcmPushService _fcmPushService;
  final _uuid = const Uuid();

  String? _currentUserId;
  String? _currentUserName;
  String? _activeCallId;
  DateTime? _callConnectedAt;
  CallErrorCallback? onError;

  ZegoCallService({
    required CallRepository callRepository,
    required PermissionService permissionService,
    required FcmPushService fcmPushService,
  })  : _callRepository = callRepository,
        _permissionService = permissionService,
        _fcmPushService = fcmPushService;

  bool get isInitialized => _currentUserId != null;

  static Future<void> setupSystemCallingUI() async {
    await ZegoUIKit().initLog();
    await ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );
  }

  Future<void> initialize({
    required String userId,
    required String userName,
  }) async {
    if (!ZegoConfig.isConfigured) {
      onError?.call('ZEGOCLOUD is not configured. Add your App ID and App Sign.');
      return;
    }

    _currentUserId = userId;
    _currentUserName = userName;

    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoConfig.appId,
      appSign: ZegoConfig.appSign,
      userID: userId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      requireConfig: (data) {
        final isVideo = data.type == ZegoCallInvitationType.videoCall;
        final config = isVideo
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

        config.topMenuBar.isVisible = true;
        config.turnOnCameraWhenJoining = isVideo;
        config.turnOnMicrophoneWhenJoining = true;
        config.useSpeakerWhenJoining = isVideo;
        return config;
      },
      invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
        onIncomingCallReceived: (
          callID,
          caller,
          callType,
          callees,
          customData,
        ) async {
          _activeCallId = callID;
          await _ensureIncomingCallRecord(
            callId: callID,
            caller: caller,
            callType: callType,
          );
        },
        onIncomingCallAcceptButtonPressed: () async {
          if (_activeCallId != null) {
            await _callRepository.updateCallStatus(
              callId: _activeCallId!,
              status: CallStatus.connecting,
            );
          }
        },
        onIncomingCallDeclineButtonPressed: () async {
          await _finalizeCall(status: CallStatus.rejected);
        },
        onIncomingCallTimeout: (callID, caller) async {
          _activeCallId = callID;
          await _finalizeCall(status: CallStatus.missed);
        },
        onOutgoingCallAccepted: (callID, callee) async {
          _activeCallId = callID;
          _callConnectedAt = DateTime.now();
          await _callRepository.updateCallStatus(
            callId: callID,
            status: CallStatus.connected,
          );
          if (_currentUserId != null) {
            await _callRepository.setUserCallAvailability(_currentUserId!, isInCall: true);
          }
        },
        onOutgoingCallRejectedCauseBusy: (callID, callee, customData) async {
          _activeCallId = callID;
          await _finalizeCall(status: CallStatus.busy);
        },
        onOutgoingCallDeclined: (callID, callee, customData) async {
          _activeCallId = callID;
          await _finalizeCall(status: CallStatus.rejected);
        },
        onOutgoingCallCancelButtonPressed: () async {
          await _finalizeCall(status: CallStatus.cancelled);
        },
        onOutgoingCallTimeout: (callID, callees, isVideoCall) async {
          _activeCallId = callID;
          await _finalizeCall(status: CallStatus.timeout);
        },
      ),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) async {
          final status = event.reason == ZegoCallEndReason.abandoned
              ? CallStatus.failed
              : CallStatus.completed;
          await _finalizeCall(status: status);
          defaultAction();
        },
      ),
    );
  }

  void uninitialize() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
    _currentUserId = null;
    _currentUserName = null;
    _activeCallId = null;
    _callConnectedAt = null;
  }

  void enterAcceptedOfflineCall() {
    ZegoUIKitPrebuiltCallInvitationService().enterAcceptedOfflineCall();
  }

  Future<bool> startCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    String calleeImage = '',
    String callerImage = '',
    required bool isVideo,
    String? chatRoomId,
  }) async {
    if (!ZegoConfig.isConfigured) {
      onError?.call('ZEGOCLOUD is not configured. Add your App ID and App Sign.');
      return false;
    }

    if (_currentUserId == null) {
      onError?.call('Call service not initialized. Please log in again.');
      return false;
    }

    final permissionsOk = await _permissionService.requestCallPermissions(isVideo: isVideo);
    if (!permissionsOk) {
      onError?.call('Microphone${isVideo ? ' and camera' : ''} permission is required for calls.');
      return false;
    }

    final calleeBusy = await _callRepository.isUserInCall(calleeId);
    if (calleeBusy) {
      onError?.call('User is busy on another call.');
      return false;
    }

    final callId = _uuid.v4();
    _activeCallId = callId;

    await _callRepository.createCallRecord(
      CallHistoryEntity(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerImage: callerImage,
        receiverId: calleeId,
        receiverName: calleeName,
        receiverImage: calleeImage,
        callType: isVideo ? CallType.video : CallType.audio,
        status: CallStatus.ringing,
        startedAt: DateTime.now(),
        participants: [callerId, calleeId],
        chatRoomId: chatRoomId,
      ),
    );
    await _callRepository.setUserCallAvailability(callerId, isInCall: true);

    final ok = await ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [ZegoCallUser(calleeId, calleeName)],
      isVideoCall: isVideo,
      resourceID: ZegoConfig.resourceId,
      callID: callId,
      timeoutSeconds: ZegoConfig.callTimeoutSeconds,
    );

    if (!ok) {
      await _callRepository.updateCallStatus(
        callId: callId,
        status: CallStatus.failed,
        endedAt: DateTime.now(),
      );
      await _callRepository.setUserCallAvailability(callerId, isInCall: false);
      _activeCallId = null;
      onError?.call('Failed to start call. Check network and ZEGOCLOUD configuration.');
      return false;
    }

    await _fcmPushService.sendCallNotification(
      receiverId: calleeId,
      callerName: callerName,
      callId: callId,
      isVideo: isVideo,
      callerImage: callerImage,
      chatRoomId: chatRoomId,
    );

    return true;
  }

  Future<void> _ensureIncomingCallRecord({
    required String callId,
    required ZegoCallUser caller,
    required ZegoCallInvitationType callType,
  }) async {
    if (_currentUserId == null) return;

    final existing = await _callRepository.getCallById(callId);
    if (existing != null) return;

    await _callRepository.createCallRecord(
      CallHistoryEntity(
        callId: callId,
        callerId: caller.id,
        callerName: caller.name,
        receiverId: _currentUserId!,
        receiverName: _currentUserName ?? '',
        callType: callType == ZegoCallInvitationType.videoCall
            ? CallType.video
            : CallType.audio,
        status: CallStatus.ringing,
        startedAt: DateTime.now(),
        participants: [caller.id, _currentUserId!],
      ),
    );
  }

  Future<void> _finalizeCall({required CallStatus status}) async {
    final callId = _activeCallId;
    if (callId == null) return;

    int duration = 0;
    if (_callConnectedAt != null) {
      duration = DateTime.now().difference(_callConnectedAt!).inSeconds;
    }
    if (status == CallStatus.completed && duration == 0) {
      duration = 1;
    }

    await _callRepository.updateCallStatus(
      callId: callId,
      status: status,
      durationSeconds: duration,
      endedAt: DateTime.now(),
    );

    if (_currentUserId != null) {
      await _callRepository.setUserCallAvailability(_currentUserId!, isInCall: false);
    }

    _activeCallId = null;
    _callConnectedAt = null;
  }
}
