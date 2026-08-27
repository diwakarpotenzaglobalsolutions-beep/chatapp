import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/chat_usecases.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final UserEntity? user;
  const AuthUserChanged(this.user);
  @override
  List<Object?> get props => [user];
}

class LogOutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class Authenticated extends AuthState {
  final UserEntity user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserStreamUseCase _getCurrentUserStreamUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final SignOutUseCase _signOutUseCase;
  final UpdateUserPresenceUseCase _updateUserPresenceUseCase;
  StreamSubscription<UserEntity?>? _userSubscription;

  AuthBloc({
    required this._getCurrentUserStreamUseCase,
    required this._getCurrentUserUseCase,
    required this._signOutUseCase,
    required this._updateUserPresenceUseCase,
  })  : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<AuthUserChanged>(_onAuthUserChanged);
    on<LogOutRequested>(_onLogOut);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _getCurrentUserUseCase();
      if (user != null) {
        // Go online
        await _updateUserPresenceUseCase(user.uid, true);
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }

    _userSubscription?.cancel();
    _userSubscription = _getCurrentUserStreamUseCase().listen((user) {
      add(AuthUserChanged(user));
    });
  }

  Future<void> _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) async {
    if (event.user != null) {
      emit(Authenticated(event.user!));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLogOut(LogOutRequested event, Emitter<AuthState> emit) async {
    final state = this.state;
    if (state is Authenticated) {
      await _updateUserPresenceUseCase(state.user.uid, false);
    }
    await _signOutUseCase();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
