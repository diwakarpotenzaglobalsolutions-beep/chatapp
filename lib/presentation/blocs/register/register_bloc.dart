import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth_usecases.dart';

// Events
abstract class RegisterEvent extends Equatable {
  const RegisterEvent();
  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  final String fullName;
  final String email;
  final String username;
  final String password;

  const RegisterSubmitted({
    required this.fullName,
    required this.email,
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [fullName, email, username, password];
}

// States
abstract class RegisterState extends Equatable {
  const RegisterState();
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterState {}

class RegisterLoading extends RegisterState {}

class RegisterSuccess extends RegisterState {
  final UserEntity user;
  const RegisterSuccess(this.user);
  @override
  List<Object?> get props => [user];
}

class RegisterFailure extends RegisterState {
  final String error;
  const RegisterFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final SignUpUseCase _signUpUseCase;

  RegisterBloc({required this._signUpUseCase})
      : super(RegisterInitial()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onRegisterSubmitted(RegisterSubmitted event, Emitter<RegisterState> emit) async {
    emit(RegisterLoading());
    try {
      final user = await _signUpUseCase(
        fullName: event.fullName,
        email: event.email,
        username: event.username,
        password: event.password,
      );
      emit(RegisterSuccess(user));
    } catch (e) {
      emit(RegisterFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
