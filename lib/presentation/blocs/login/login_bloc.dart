import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/network_error_formatter.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth_usecases.dart';

// Events
abstract class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;
  const LoginSubmitted({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

// States
abstract class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final UserEntity user;
  const LoginSuccess(this.user);
  @override
  List<Object?> get props => [user];
}

class LoginFailure extends LoginState {
  final String error;
  const LoginFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SignInUseCase _signInUseCase;

  LoginBloc({required this._signInUseCase})
      : super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    emit(LoginLoading());
    try {
      final user = await _signInUseCase(email: event.email, password: event.password);
      emit(LoginSuccess(user));
    } catch (e) {
      emit(LoginFailure(NetworkErrorFormatter.format(e)));
    }
  }
}
