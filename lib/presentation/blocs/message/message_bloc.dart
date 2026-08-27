import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/network_error_formatter.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/usecases/chat_usecases.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToMessages extends MessageEvent {
  final String roomId;
  final String currentUserId;
  const SubscribeToMessages({required this.roomId, required this.currentUserId});
  @override
  List<Object?> get props => [roomId, currentUserId];
}

class MessagesUpdated extends MessageEvent {
  final List<MessageEntity> messages;
  const MessagesUpdated(this.messages);
  @override
  List<Object?> get props => [messages];
}

class SendMessageRequested extends MessageEvent {
  final String roomId;
  final MessageEntity message;
  const SendMessageRequested({required this.roomId, required this.message});
  @override
  List<Object?> get props => [roomId, message];
}

class MarkAsSeenRequested extends MessageEvent {
  final String roomId;
  final String currentUserId;
  const MarkAsSeenRequested({required this.roomId, required this.currentUserId});
  @override
  List<Object?> get props => [roomId, currentUserId];
}

class DeleteMessageForMeRequested extends MessageEvent {
  final String roomId;
  final String messageId;
  final String userId;

  const DeleteMessageForMeRequested({
    required this.roomId,
    required this.messageId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, messageId, userId];
}

class DeleteMessageForEveryoneRequested extends MessageEvent {
  final String roomId;
  final String messageId;
  final String senderId;

  const DeleteMessageForEveryoneRequested({
    required this.roomId,
    required this.messageId,
    required this.senderId,
  });

  @override
  List<Object?> get props => [roomId, messageId, senderId];
}

abstract class MessageState extends Equatable {
  const MessageState();
  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {}

class MessagesLoaded extends MessageState {
  final List<MessageEntity> messages;
  const MessagesLoaded(this.messages);
  @override
  List<Object?> get props => [messages];
}

class MessageFailure extends MessageState {
  final String error;
  const MessageFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final GetMessagesUseCase _getMessagesUseCase;
  final SendMessageUseCase _sendMessageUseCase;
  final MarkMessagesAsSeenUseCase _markMessagesAsSeenUseCase;
  final DeleteMessageForMeUseCase _deleteMessageForMeUseCase;
  final DeleteMessageForEveryoneUseCase _deleteMessageForEveryoneUseCase;
  StreamSubscription<List<MessageEntity>>? _messageSubscription;

  String? _activeRoomId;
  String? _currentUserId;

  MessageBloc({
    required this._getMessagesUseCase,
    required this._sendMessageUseCase,
    required this._markMessagesAsSeenUseCase,
    required this._deleteMessageForMeUseCase,
    required this._deleteMessageForEveryoneUseCase,
  })  : super(MessageInitial()) {
    on<SubscribeToMessages>(_onSubscribeToMessages);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<SendMessageRequested>(_onSendMessage);
    on<MarkAsSeenRequested>(_onMarkAsSeen);
    on<DeleteMessageForMeRequested>(_onDeleteForMe);
    on<DeleteMessageForEveryoneRequested>(_onDeleteForEveryone);
  }

  Future<void> _onSubscribeToMessages(
      SubscribeToMessages event,
      Emitter<MessageState> emit,
      ) async {
    emit(MessageLoading());
    _activeRoomId = event.roomId;
    _currentUserId = event.currentUserId;

    await _messageSubscription?.cancel();
    await _markMessagesAsSeenUseCase(event.roomId, event.currentUserId);

    _messageSubscription = _getMessagesUseCase(event.roomId, event.currentUserId).listen((messages) {
      add(MessagesUpdated(messages));
    });
  }

  void _onMessagesUpdated(MessagesUpdated event, Emitter<MessageState> emit) {
    emit(MessagesLoaded(event.messages));

    if (_activeRoomId == null || _currentUserId == null) return;

    final hasUnseenIncoming = event.messages.any((m) {
      if (m.senderId == _currentUserId) return false;
      if (m.readBy.isNotEmpty) {
        return !m.readBy.containsKey(_currentUserId);
      }
      return m.status != MessageStatus.seen;
    });

    if (hasUnseenIncoming) {
      add(MarkAsSeenRequested(
        roomId: _activeRoomId!,
        currentUserId: _currentUserId!,
      ));
    }
  }

  Future<void> _onSendMessage(
      SendMessageRequested event,
      Emitter<MessageState> emit,
      ) async {
    try {
      await _sendMessageUseCase(event.roomId, event.message);
    } catch (e) {
      emit(MessageFailure(NetworkErrorFormatter.format(e)));
    }
  }

  Future<void> _onMarkAsSeen(
      MarkAsSeenRequested event,
      Emitter<MessageState> emit,
      ) async {
    try {
      await _markMessagesAsSeenUseCase(event.roomId, event.currentUserId);
    } catch (_) {}
  }

  Future<void> _onDeleteForMe(
    DeleteMessageForMeRequested event,
    Emitter<MessageState> emit,
  ) async {
    try {
      await _deleteMessageForMeUseCase(
        roomId: event.roomId,
        messageId: event.messageId,
        userId: event.userId,
      );
    } catch (e) {
      emit(MessageFailure(NetworkErrorFormatter.format(e)));
    }
  }

  Future<void> _onDeleteForEveryone(
    DeleteMessageForEveryoneRequested event,
    Emitter<MessageState> emit,
  ) async {
    try {
      await _deleteMessageForEveryoneUseCase(
        roomId: event.roomId,
        messageId: event.messageId,
        senderId: event.senderId,
      );
    } catch (e) {
      emit(MessageFailure(NetworkErrorFormatter.format(e)));
    }
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
