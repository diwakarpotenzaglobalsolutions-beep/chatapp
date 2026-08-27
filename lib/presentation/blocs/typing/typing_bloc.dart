import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/chat_usecases.dart';

// Events
abstract class TypingEvent extends Equatable {
  const TypingEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToTypingStatus extends TypingEvent {
  final String roomId;
  const SubscribeToTypingStatus(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class TypingStatusUpdated extends TypingEvent {
  final Map<String, bool> typingMap;
  const TypingStatusUpdated(this.typingMap);
  @override
  List<Object?> get props => [typingMap];
}

class UpdateTypingRequest extends TypingEvent {
  final String roomId;
  final String uid;
  final bool isTyping;

  const UpdateTypingRequest({
    required this.roomId,
    required this.uid,
    required this.isTyping,
  });

  @override
  List<Object?> get props => [roomId, uid, isTyping];
}

// States
abstract class TypingState extends Equatable {
  const TypingState();
  @override
  List<Object?> get props => [];
}

class TypingInitial extends TypingState {}

class TypingUpdated extends TypingState {
  final Map<String, bool> typingMap;
  const TypingUpdated(this.typingMap);
  @override
  List<Object?> get props => [typingMap];
}

// Bloc
class TypingBloc extends Bloc<TypingEvent, TypingState> {
  final GetTypingStatusUseCase _getTypingStatusUseCase;
  final UpdateTypingStatusUseCase _updateTypingStatusUseCase;
  StreamSubscription<Map<String, bool>>? _typingSubscription;

  TypingBloc({
    required GetTypingStatusUseCase getTypingStatusUseCase,
    required UpdateTypingStatusUseCase updateTypingStatusUseCase,
  })  : _getTypingStatusUseCase = getTypingStatusUseCase,
        _updateTypingStatusUseCase = updateTypingStatusUseCase,
        super(TypingInitial()) {
    on<SubscribeToTypingStatus>(_onSubscribeToTypingStatus);
    on<TypingStatusUpdated>(_onTypingStatusUpdated);
    on<UpdateTypingRequest>(_onUpdateTypingRequest);
  }

  void _onSubscribeToTypingStatus(SubscribeToTypingStatus event, Emitter<TypingState> emit) {
    _typingSubscription?.cancel();
    _typingSubscription = _getTypingStatusUseCase(event.roomId).listen((typingMap) {
      add(TypingStatusUpdated(typingMap));
    });
  }

  void _onTypingStatusUpdated(TypingStatusUpdated event, Emitter<TypingState> emit) {
    emit(TypingUpdated(event.typingMap));
  }

  Future<void> _onUpdateTypingRequest(UpdateTypingRequest event, Emitter<TypingState> emit) async {
    try {
      await _updateTypingStatusUseCase(event.roomId, event.uid, event.isTyping);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _typingSubscription?.cancel();
    return super.close();
  }
}
