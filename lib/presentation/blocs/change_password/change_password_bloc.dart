import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/auth_usecases.dart';

// Events
abstract class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();
  @override
  List<Object?> get props => [];
}

class ChangePasswordSubmitted extends ChangePasswordEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordSubmitted({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

// States
abstract class ChangePasswordState extends Equatable {
  const ChangePasswordState();
  @override
  List<Object?> get props => [];
}

class ChangePasswordInitial extends ChangePasswordState {}

class ChangePasswordLoading extends ChangePasswordState {}

class ChangePasswordSuccess extends ChangePasswordState {}

class ChangePasswordFailure extends ChangePasswordState {
  final String error;
  const ChangePasswordFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class ChangePasswordBloc extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  final ChangePasswordUseCase _changePasswordUseCase;

  ChangePasswordBloc({required ChangePasswordUseCase changePasswordUseCase})
      : _changePasswordUseCase = changePasswordUseCase,
        super(ChangePasswordInitial()) {
    on<ChangePasswordSubmitted>(_onChangePasswordSubmitted);
  }

  Future<void> _onChangePasswordSubmitted(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    emit(ChangePasswordLoading());
    try {
      await _changePasswordUseCase(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(ChangePasswordSuccess());
    } catch (e) {
      emit(ChangePasswordFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
