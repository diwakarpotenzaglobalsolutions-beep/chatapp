import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/chat_room_entity.dart';
import '../../../domain/usecases/chat_usecases.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToChatRooms extends ChatListEvent {
  final String uid;
  final bool force;
  const SubscribeToChatRooms(this.uid, {this.force = false});
  @override
  List<Object?> get props => [uid, force];
}

class RefreshChatRooms extends ChatListEvent {
  const RefreshChatRooms();
}

class ChatRoomsUpdated extends ChatListEvent {
  final List<ChatRoomEntity> rooms;
  const ChatRoomsUpdated(this.rooms);
  @override
  List<Object?> get props => [rooms];
}

class ChatListState extends Equatable {
  final List<ChatRoomEntity> rooms;
  final bool isInitialLoading;
  final bool isRefreshing;
  final String? error;
  final String? subscribedUid;

  const ChatListState({
    this.rooms = const [],
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.error,
    this.subscribedUid,
  });

  bool get hasData => rooms.isNotEmpty;

  ChatListState copyWith({
    List<ChatRoomEntity>? rooms,
    bool? isInitialLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    String? subscribedUid,
  }) {
    return ChatListState(
      rooms: rooms ?? this.rooms,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      subscribedUid: subscribedUid ?? this.subscribedUid,
    );
  }

  @override
  List<Object?> get props => [
        rooms,
        isInitialLoading,
        isRefreshing,
        error,
        subscribedUid,
      ];
}

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final GetChatRoomsUseCase _getChatRoomsUseCase;
  StreamSubscription<List<ChatRoomEntity>>? _roomsSubscription;

  ChatListBloc({required GetChatRoomsUseCase getChatRoomsUseCase})
      : _getChatRoomsUseCase = getChatRoomsUseCase,
        super(const ChatListState()) {
    on<SubscribeToChatRooms>(_onSubscribeToChatRooms);
    on<RefreshChatRooms>(_onRefreshChatRooms);
    on<ChatRoomsUpdated>(_onChatRoomsUpdated);
  }

  void _onSubscribeToChatRooms(
    SubscribeToChatRooms event,
    Emitter<ChatListState> emit,
  ) {
    if (!event.force &&
        state.subscribedUid == event.uid &&
        _roomsSubscription != null) {
      return;
    }

    if (!state.hasData) {
      emit(state.copyWith(isInitialLoading: true, clearError: true));
    }

    _roomsSubscription?.cancel();
    _roomsSubscription = _getChatRoomsUseCase(event.uid).listen(
      (rooms) => add(ChatRoomsUpdated(rooms)),
      onError: (e) {
        if (state.hasData) {
          emit(state.copyWith(error: e.toString()));
        } else {
          emit(state.copyWith(
            isInitialLoading: false,
            error: e.toString(),
          ));
        }
      },
    );

    emit(state.copyWith(subscribedUid: event.uid));
  }

  Future<void> _onRefreshChatRooms(
    RefreshChatRooms event,
    Emitter<ChatListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emit(state.copyWith(isRefreshing: false));
  }

  void _onChatRoomsUpdated(ChatRoomsUpdated event, Emitter<ChatListState> emit) {
    emit(state.copyWith(
      rooms: event.rooms,
      isInitialLoading: false,
      isRefreshing: false,
      clearError: true,
    ));
  }

  @override
  Future<void> close() {
    _roomsSubscription?.cancel();
    return super.close();
  }
}
