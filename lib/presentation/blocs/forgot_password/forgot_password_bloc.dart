import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/auth_usecases.dart';

// Events
abstract class ForgotPasswordEvent extends Equatable {
  const ForgotPasswordEvent();
  @override
  List<Object?> get props => [];
}

class ForgotPasswordSubmitted extends ForgotPasswordEvent {
  final String email;
  const ForgotPasswordSubmitted(this.email);
  @override
  List<Object?> get props => [email];
}

// States
abstract class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();
  @override
  List<Object?> get props => [];
}

class ForgotPasswordInitial extends ForgotPasswordState {}

class ForgotPasswordLoading extends ForgotPasswordState {}

class ForgotPasswordSuccess extends ForgotPasswordState {}

class ForgotPasswordFailure extends ForgotPasswordState {
  final String error;
  const ForgotPasswordFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final ForgotPasswordUseCase _forgotPasswordUseCase;

  ForgotPasswordBloc({required ForgotPasswordUseCase forgotPasswordUseCase})
      : _forgotPasswordUseCase = forgotPasswordUseCase,
        super(ForgotPasswordInitial()) {
    on<ForgotPasswordSubmitted>(_onForgotPasswordSubmitted);
  }

  Future<void> _onForgotPasswordSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(ForgotPasswordLoading());
    try {
      await _forgotPasswordUseCase(event.email);
      emit(ForgotPasswordSuccess());
    } catch (e) {
      emit(ForgotPasswordFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
