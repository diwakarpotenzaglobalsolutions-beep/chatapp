import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/chat_usecases.dart';

// Events
abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class EnterChatRoom extends ChatEvent {
  final String uid1;
  final String uid2;
  const EnterChatRoom({required this.uid1, required this.uid2});
  @override
  List<Object?> get props => [uid1, uid2];
}

// States
abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatRoomInitial extends ChatState {}

class ChatRoomLoading extends ChatState {}

class ChatRoomLoaded extends ChatState {
  final String roomId;
  const ChatRoomLoaded(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

class ChatRoomFailure extends ChatState {
  final String error;
  const ChatRoomFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetOrCreateChatRoomUseCase _getOrCreateChatRoomUseCase;

  ChatBloc({required GetOrCreateChatRoomUseCase getOrCreateChatRoomUseCase})
      : _getOrCreateChatRoomUseCase = getOrCreateChatRoomUseCase,
        super(ChatRoomInitial()) {
    on<EnterChatRoom>(_onEnterChatRoom);
  }

  Future<void> _onEnterChatRoom(EnterChatRoom event, Emitter<ChatState> emit) async {
    emit(ChatRoomLoading());
    try {
      final roomId = await _getOrCreateChatRoomUseCase(event.uid1, event.uid2);
      emit(ChatRoomLoaded(roomId));
    } catch (e) {
      emit(ChatRoomFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
