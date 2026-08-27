import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/profile_usecases.dart';

// Events
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  final String uid;
  const LoadProfile(this.uid);
  @override
  List<Object?> get props => [uid];
}

// States
abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserEntity user;
  const ProfileLoaded(this.user);
  @override
  List<Object?> get props => [user];
}

class ProfileFailure extends ProfileState {
  final String error;
  const ProfileFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserProfileUseCase _getUserProfileUseCase;

  ProfileBloc({required GetUserProfileUseCase getUserProfileUseCase})
      : _getUserProfileUseCase = getUserProfileUseCase,
        super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    try {
      final user = await _getUserProfileUseCase(event.uid);
      emit(ProfileLoaded(user));
    } catch (e) {
      emit(ProfileFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
