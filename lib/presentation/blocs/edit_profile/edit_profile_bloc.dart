import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/profile_usecases.dart';

// Events
abstract class EditProfileEvent extends Equatable {
  const EditProfileEvent();
  @override
  List<Object?> get props => [];
}

class EditProfileSubmitted extends EditProfileEvent {
  final UserEntity user;
  const EditProfileSubmitted(this.user);
  @override
  List<Object?> get props => [user];
}

// States
abstract class EditProfileState extends Equatable {
  const EditProfileState();
  @override
  List<Object?> get props => [];
}

class EditProfileInitial extends EditProfileState {}

class EditProfileLoading extends EditProfileState {}

class EditProfileSuccess extends EditProfileState {}

class EditProfileFailure extends EditProfileState {
  final String error;
  const EditProfileFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class EditProfileBloc extends Bloc<EditProfileEvent, EditProfileState> {
  final GetUserProfileUseCase _getUserProfileUseCase;
  final UpdateUserProfileUseCase _updateUserProfileUseCase;

  EditProfileBloc({
    required GetUserProfileUseCase getUserProfileUseCase,
    required UpdateUserProfileUseCase updateUserProfileUseCase,
  })  : _getUserProfileUseCase = getUserProfileUseCase,
        _updateUserProfileUseCase = updateUserProfileUseCase,
        super(EditProfileInitial()) {
    on<EditProfileSubmitted>(_onEditProfileSubmitted);
  }

  Future<void> _onEditProfileSubmitted(
    EditProfileSubmitted event,
    Emitter<EditProfileState> emit,
  ) async {
    emit(EditProfileLoading());
    try {
      await _updateUserProfileUseCase(event.user);
      emit(EditProfileSuccess());
    } catch (e) {
      emit(EditProfileFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
