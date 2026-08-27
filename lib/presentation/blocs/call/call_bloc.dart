import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/zego_call_service.dart';
import '../../../domain/entities/call_history_entity.dart';
import '../../../domain/usecases/block_usecases.dart';
import '../../../domain/usecases/call_usecases.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToCallHistory extends CallEvent {
  final String userId;
  const SubscribeToCallHistory(this.userId);
  @override
  List<Object?> get props => [userId];
}

class CallHistoryUpdated extends CallEvent {
  final List<CallHistoryEntity> calls;
  const CallHistoryUpdated(this.calls);
  @override
  List<Object?> get props => [calls];
}

class StartAudioCallRequested extends CallEvent {
  final String callerId;
  final String callerName;
  final String callerImage;
  final String calleeId;
  final String calleeName;
  final String calleeImage;
  final String? chatRoomId;

  const StartAudioCallRequested({
    required this.callerId,
    required this.callerName,
    this.callerImage = '',
    required this.calleeId,
    required this.calleeName,
    this.calleeImage = '',
    this.chatRoomId,
  });

  @override
  List<Object?> get props => [
        callerId, callerName, callerImage,
        calleeId, calleeName, calleeImage, chatRoomId,
      ];
}

class StartVideoCallRequested extends CallEvent {
  final String callerId;
  final String callerName;
  final String callerImage;
  final String calleeId;
  final String calleeName;
  final String calleeImage;
  final String? chatRoomId;

  const StartVideoCallRequested({
    required this.callerId,
    required this.callerName,
    this.callerImage = '',
    required this.calleeId,
    required this.calleeName,
    this.calleeImage = '',
    this.chatRoomId,
  });

  @override
  List<Object?> get props => [
        callerId, callerName, callerImage,
        calleeId, calleeName, calleeImage, chatRoomId,
      ];
}

class ClearCallFeedback extends CallEvent {}

class CallErrorOccurred extends CallEvent {
  final String message;
  const CallErrorOccurred(this.message);
  @override
  List<Object?> get props => [message];
}

class CallState extends Equatable {
  final List<CallHistoryEntity> calls;
  final bool isLoadingHistory;
  final String? historyError;
  final bool isCallActionInProgress;
  final String? callActionError;

  const CallState({
    this.calls = const [],
    this.isLoadingHistory = false,
    this.historyError,
    this.isCallActionInProgress = false,
    this.callActionError,
  });

  CallState copyWith({
    List<CallHistoryEntity>? calls,
    bool? isLoadingHistory,
    String? historyError,
    bool clearHistoryError = false,
    bool? isCallActionInProgress,
    String? callActionError,
    bool clearCallActionError = false,
  }) {
    return CallState(
      calls: calls ?? this.calls,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError: clearHistoryError ? null : (historyError ?? this.historyError),
      isCallActionInProgress:
          isCallActionInProgress ?? this.isCallActionInProgress,
      callActionError:
          clearCallActionError ? null : (callActionError ?? this.callActionError),
    );
  }

  @override
  List<Object?> get props => [
        calls,
        isLoadingHistory,
        historyError,
        isCallActionInProgress,
        callActionError,
      ];
}

class CallBloc extends Bloc<CallEvent, CallState> {
  final GetCallHistoryUseCase _getCallHistoryUseCase;
  final ZegoCallService _zegoCallService;
  final IsBlockedEitherWayUseCase _isBlockedEitherWayUseCase;
  StreamSubscription<List<CallHistoryEntity>>? _historySub;

  CallBloc({
    required GetCallHistoryUseCase getCallHistoryUseCase,
    required ZegoCallService zegoCallService,
    required IsBlockedEitherWayUseCase isBlockedEitherWayUseCase,
  })  : _getCallHistoryUseCase = getCallHistoryUseCase,
        _zegoCallService = zegoCallService,
        _isBlockedEitherWayUseCase = isBlockedEitherWayUseCase,
        super(const CallState(isLoadingHistory: true)) {
    on<SubscribeToCallHistory>(_onSubscribe);
    on<CallHistoryUpdated>(_onHistoryUpdated);
    on<StartAudioCallRequested>(_onStartAudio);
    on<StartVideoCallRequested>(_onStartVideo);
    on<ClearCallFeedback>(_onClearFeedback);
    on<CallErrorOccurred>(_onCallError);

    _zegoCallService.onError = (message) {
      if (!isClosed) add(CallErrorOccurred(message));
    };
  }

  Future<void> _onSubscribe(
    SubscribeToCallHistory event,
    Emitter<CallState> emit,
  ) async {
    emit(state.copyWith(isLoadingHistory: state.calls.isEmpty, clearHistoryError: true));
    await _historySub?.cancel();
    _historySub = _getCallHistoryUseCase(event.userId).listen(
      (calls) => add(CallHistoryUpdated(calls)),
      onError: (_) => add(const CallErrorOccurred('Failed to load call history')),
    );
  }

  void _onCallError(CallErrorOccurred event, Emitter<CallState> emit) {
    if (state.calls.isEmpty) {
      emit(state.copyWith(isLoadingHistory: false, historyError: event.message));
    } else {
      emit(state.copyWith(
        isCallActionInProgress: false,
        callActionError: event.message,
      ));
    }
  }

  void _onHistoryUpdated(CallHistoryUpdated event, Emitter<CallState> emit) {
    emit(state.copyWith(
      calls: event.calls,
      isLoadingHistory: false,
      clearHistoryError: true,
    ));
  }

  Future<void> _onStartAudio(
    StartAudioCallRequested event,
    Emitter<CallState> emit,
  ) async {
    emit(state.copyWith(isCallActionInProgress: true, clearCallActionError: true));

    final blocked = await _isBlockedEitherWayUseCase(event.callerId, event.calleeId);
    if (blocked) {
      emit(state.copyWith(
        isCallActionInProgress: false,
        callActionError: 'Communication is blocked',
      ));
      return;
    }

    final ok = await _zegoCallService.startCall(
      callerId: event.callerId,
      callerName: event.callerName,
      callerImage: event.callerImage,
      calleeId: event.calleeId,
      calleeName: event.calleeName,
      calleeImage: event.calleeImage,
      isVideo: false,
      chatRoomId: event.chatRoomId,
    );
    emit(state.copyWith(isCallActionInProgress: false));
    if (!ok && state.callActionError == null) {
      // Error emitted via onError callback
    }
  }

  Future<void> _onStartVideo(
    StartVideoCallRequested event,
    Emitter<CallState> emit,
  ) async {
    emit(state.copyWith(isCallActionInProgress: true, clearCallActionError: true));

    final blocked = await _isBlockedEitherWayUseCase(event.callerId, event.calleeId);
    if (blocked) {
      emit(state.copyWith(
        isCallActionInProgress: false,
        callActionError: 'Communication is blocked',
      ));
      return;
    }

    final ok = await _zegoCallService.startCall(
      callerId: event.callerId,
      callerName: event.callerName,
      callerImage: event.callerImage,
      calleeId: event.calleeId,
      calleeName: event.calleeName,
      calleeImage: event.calleeImage,
      isVideo: true,
      chatRoomId: event.chatRoomId,
    );
    emit(state.copyWith(isCallActionInProgress: false));
    if (!ok && state.callActionError == null) {
      // Error emitted via onError callback
    }
  }

  void _onClearFeedback(ClearCallFeedback event, Emitter<CallState> emit) {
    emit(state.copyWith(clearCallActionError: true));
  }

  @override
  Future<void> close() {
    _historySub?.cancel();
    return super.close();
  }
}
