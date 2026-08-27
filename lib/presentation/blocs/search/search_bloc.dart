import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/usecases/search_usecases.dart';

// Events
abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchUsersRequested extends SearchEvent {
  final String query;
  const SearchUsersRequested(this.query);
  @override
  List<Object?> get props => [query];
}

class SearchMessagesRequested extends SearchEvent {
  final String roomId;
  final String query;
  const SearchMessagesRequested({required this.roomId, required this.query});
  @override
  List<Object?> get props => [roomId, query];
}

class ClearSearchRequested extends SearchEvent {}

// States
abstract class SearchState extends Equatable {
  const SearchState();
  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchUsersSuccess extends SearchState {
  final List<UserEntity> users;
  final String query;
  const SearchUsersSuccess(this.users, {this.query = ''});
  @override
  List<Object?> get props => [users, query];
}

class SearchMessagesSuccess extends SearchState {
  final List<MessageEntity> messages;
  const SearchMessagesSuccess(this.messages);
  @override
  List<Object?> get props => [messages];
}

class SearchFailure extends SearchState {
  final String error;
  const SearchFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchUsersUseCase _searchUsersUseCase;
  final SearchMessagesUseCase _searchMessagesUseCase;

  SearchBloc({
    required SearchUsersUseCase searchUsersUseCase,
    required SearchMessagesUseCase searchMessagesUseCase,
  })  : _searchUsersUseCase = searchUsersUseCase,
        _searchMessagesUseCase = searchMessagesUseCase,
        super(SearchInitial()) {
    on<SearchUsersRequested>(_onSearchUsers);
    on<SearchMessagesRequested>(_onSearchMessages);
    on<ClearSearchRequested>(_onClearSearch);
  }

  Future<void> _onSearchUsers(
      SearchUsersRequested event,
      Emitter<SearchState> emit,
      ) async {
    emit(SearchLoading());
    try {
      final users = await _searchUsersUseCase(event.query);
      emit(SearchUsersSuccess(users, query: event.query.trim()));
    } catch (e) {
      emit(SearchFailure(e.toString()));
    }
  }

  Future<void> _onSearchMessages(
      SearchMessagesRequested event,
      Emitter<SearchState> emit,
      ) async {
    if (event.query.trim().isEmpty) {
      emit(SearchInitial());
      return;
    }
    emit(SearchLoading());
    try {
      final messages = await _searchMessagesUseCase(event.roomId, event.query);
      emit(SearchMessagesSuccess(messages));
    } catch (e) {
      emit(SearchFailure(e.toString()));
    }
  }

  Future<void> _onClearSearch(
      ClearSearchRequested event,
      Emitter<SearchState> emit,
      ) async {
    add(const SearchUsersRequested(''));
  }
}