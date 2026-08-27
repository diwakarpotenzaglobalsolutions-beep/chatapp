import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/chat_usecases.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class LoadHome extends HomeEvent {
  final bool silent;
  const LoadHome({this.silent = false});
  @override
  List<Object?> get props => [silent];
}

class UpdatePresence extends HomeEvent {
  final bool isOnline;
  const UpdatePresence(this.isOnline);
  @override
  List<Object?> get props => [isOnline];
}

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final UserEntity currentUser;
  const HomeLoaded(this.currentUser);
  @override
  List<Object?> get props => [currentUser];
}

class HomeFailure extends HomeState {
  final String error;
  const HomeFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final UpdateUserPresenceUseCase _updateUserPresenceUseCase;

  HomeBloc({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required UpdateUserPresenceUseCase updateUserPresenceUseCase,
  })  : _getCurrentUserUseCase = getCurrentUserUseCase,
        _updateUserPresenceUseCase = updateUserPresenceUseCase,
        super(HomeInitial()) {
    on<LoadHome>(_onLoadHome);
    on<UpdatePresence>(_onUpdatePresence);
  }

  Future<void> _onLoadHome(LoadHome event, Emitter<HomeState> emit) async {
    if (!event.silent && state is! HomeLoaded) {
      emit(HomeLoading());
    }

    try {
      final user = await _getCurrentUserUseCase();
      if (user != null) {
        await _updateUserPresenceUseCase(user.uid, true);
        emit(HomeLoaded(user));
      } else if (state is! HomeLoaded) {
        emit(const HomeFailure('User not logged in.'));
      }
    } catch (e) {
      if (state is! HomeLoaded) {
        emit(HomeFailure(e.toString()));
      }
    }
  }

  Future<void> _onUpdatePresence(UpdatePresence event, Emitter<HomeState> emit) async {
    final current = state;
    if (current is HomeLoaded) {
      try {
        await _updateUserPresenceUseCase(current.currentUser.uid, event.isOnline);
      } catch (_) {}
    }
  }
}
