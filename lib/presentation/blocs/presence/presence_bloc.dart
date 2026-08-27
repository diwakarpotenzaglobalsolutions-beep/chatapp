import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/chat_usecases.dart';

// Events
abstract class PresenceEvent extends Equatable {
  const PresenceEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToUserPresence extends PresenceEvent {
  final String uid;
  const SubscribeToUserPresence(this.uid);
  @override
  List<Object?> get props => [uid];
}

class PresenceUpdated extends PresenceEvent {
  final UserEntity? user;
  const PresenceUpdated(this.user);
  @override
  List<Object?> get props => [user];
}

// States
abstract class PresenceState extends Equatable {
  const PresenceState();
  @override
  List<Object?> get props => [];
}

class PresenceInitial extends PresenceState {}

class PresenceLoading extends PresenceState {}

class PresenceLoaded extends PresenceState {
  final UserEntity user;
  const PresenceLoaded(this.user);
  @override
  List<Object?> get props => [user];
}

class PresenceOffline extends PresenceState {
  final DateTime lastSeen;
  const PresenceOffline(this.lastSeen);
  @override
  List<Object?> get props => [lastSeen];
}

class PresenceFailure extends PresenceState {}

// Bloc
class PresenceBloc extends Bloc<PresenceEvent, PresenceState> {
  final GetUserPresenceUseCase _getUserPresenceUseCase;
  StreamSubscription<UserEntity?>? _presenceSubscription;

  PresenceBloc({required this._getUserPresenceUseCase})
      : super(PresenceInitial()) {
    on<SubscribeToUserPresence>(_onSubscribeToUserPresence);
    on<PresenceUpdated>(_onPresenceUpdated);
  }

  void _onSubscribeToUserPresence(SubscribeToUserPresence event, Emitter<PresenceState> emit) {
    emit(PresenceLoading());
    _presenceSubscription?.cancel();
    _presenceSubscription = _getUserPresenceUseCase(event.uid).listen(
      (user) {
        add(PresenceUpdated(user));
      },
      onError: (_) {
        emit(PresenceFailure());
      },
    );
  }

  void _onPresenceUpdated(PresenceUpdated event, Emitter<PresenceState> emit) {
    final user = event.user;
    if (user != null) {
      if (user.onlineStatus) {
        emit(PresenceLoaded(user));
      } else {
        emit(PresenceOffline(user.lastSeen));
      }
    } else {
      emit(PresenceFailure());
    }
  }

  @override
  Future<void> close() {
    _presenceSubscription?.cancel();
    return super.close();
  }
}
