import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/network_error_formatter.dart';
import '../../../domain/entities/chat_request_entity.dart';
import '../../../domain/usecases/chat_request_usecases.dart';
import '../../../domain/usecases/chat_usecases.dart';

// ── Events ──
abstract class ChatRequestEvent extends Equatable {
  const ChatRequestEvent();
  @override
  List<Object?> get props => [];
}

class SubscribeToIncomingRequests extends ChatRequestEvent {
  final String userId;
  const SubscribeToIncomingRequests(this.userId);
  @override
  List<Object?> get props => [userId];
}

class SubscribeToRequestBetweenUsers extends ChatRequestEvent {
  final String user1;
  final String user2;
  const SubscribeToRequestBetweenUsers({required this.user1, required this.user2});
  @override
  List<Object?> get props => [user1, user2];
}

class SendChatRequestEvent extends ChatRequestEvent {
  final ChatRequestEntity request;
  const SendChatRequestEvent(this.request);
  @override
  List<Object?> get props => [request];
}

class AcceptChatRequestEvent extends ChatRequestEvent {
  final String requestId;
  const AcceptChatRequestEvent(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

class RejectChatRequestEvent extends ChatRequestEvent {
  final String requestId;
  const RejectChatRequestEvent(this.requestId);
  @override
  List<Object?> get props => [requestId];
}

class IncomingRequestsUpdated extends ChatRequestEvent {
  final List<ChatRequestEntity> requests;
  const IncomingRequestsUpdated(this.requests);
  @override
  List<Object?> get props => [requests];
}

class BetweenUsersRequestUpdated extends ChatRequestEvent {
  final ChatRequestEntity? request;
  const BetweenUsersRequestUpdated(this.request);
  @override
  List<Object?> get props => [request];
}

class ClearChatRequestFeedback extends ChatRequestEvent {}

// ── States ──
abstract class ChatRequestState extends Equatable {
  const ChatRequestState();
  @override
  List<Object?> get props => [];
}

class ChatRequestInitial extends ChatRequestState {}

class ChatRequestLoading extends ChatRequestState {}

class IncomingRequestsLoaded extends ChatRequestState {
  final List<ChatRequestEntity> requests;
  final String? feedbackMessage;
  final bool isErrorFeedback;

  const IncomingRequestsLoaded(
      this.requests, {
        this.feedbackMessage,
        this.isErrorFeedback = false,
      });

  @override
  List<Object?> get props => [requests, feedbackMessage, isErrorFeedback];
}

class BetweenUsersRequestLoaded extends ChatRequestState {
  final ChatRequestEntity? request;
  final String? feedbackMessage;
  final bool isErrorFeedback;

  const BetweenUsersRequestLoaded(
      this.request, {
        this.feedbackMessage,
        this.isErrorFeedback = false,
      });

  @override
  List<Object?> get props => [request, feedbackMessage, isErrorFeedback];
}

class ChatRequestFailure extends ChatRequestState {
  final String error;
  const ChatRequestFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// ── Bloc ──
class ChatRequestBloc extends Bloc<ChatRequestEvent, ChatRequestState> {
  final SendChatRequestUseCase _sendChatRequestUseCase;
  final UpdateChatRequestStatusUseCase _updateChatRequestStatusUseCase;
  final GetChatRequestsUseCase _getChatRequestsUseCase;
  final GetChatRequestBetweenUsersUseCase _getChatRequestBetweenUsersUseCase;
  final GetOrCreateChatRoomUseCase _getOrCreateChatRoomUseCase;

  StreamSubscription<List<ChatRequestEntity>>? _incomingSub;
  StreamSubscription<ChatRequestEntity?>? _betweenUsersSub;

  ChatRequestEntity? _cachedBetweenUsersRequest;
  List<ChatRequestEntity> _cachedIncomingRequests = [];

  ChatRequestBloc({
    required SendChatRequestUseCase sendChatRequestUseCase,
    required UpdateChatRequestStatusUseCase updateChatRequestStatusUseCase,
    required GetChatRequestsUseCase getChatRequestsUseCase,
    required GetChatRequestBetweenUsersUseCase getChatRequestBetweenUsersUseCase,
    required GetOrCreateChatRoomUseCase getOrCreateChatRoomUseCase,
  })  : _sendChatRequestUseCase = sendChatRequestUseCase,
        _updateChatRequestStatusUseCase = updateChatRequestStatusUseCase,
        _getChatRequestsUseCase = getChatRequestsUseCase,
        _getChatRequestBetweenUsersUseCase = getChatRequestBetweenUsersUseCase,
        _getOrCreateChatRoomUseCase = getOrCreateChatRoomUseCase,
        super(ChatRequestInitial()) {
    on<SubscribeToIncomingRequests>(_onSubscribeIncoming);
    on<IncomingRequestsUpdated>(_onIncomingUpdated);
    on<SubscribeToRequestBetweenUsers>(_onSubscribeBetweenUsers);
    on<BetweenUsersRequestUpdated>(_onBetweenUsersUpdated);
    on<SendChatRequestEvent>(_onSendRequest);
    on<AcceptChatRequestEvent>(_onAcceptRequest);
    on<RejectChatRequestEvent>(_onRejectRequest);
    on<ClearChatRequestFeedback>(_onClearFeedback);
  }

  Future<void> _onSubscribeIncoming(
      SubscribeToIncomingRequests event,
      Emitter<ChatRequestState> emit,
      ) async {
    emit(ChatRequestLoading());
    await _incomingSub?.cancel();
    _incomingSub = _getChatRequestsUseCase(event.userId).listen(
          (requests) => add(IncomingRequestsUpdated(requests)),
    );
  }

  void _onIncomingUpdated(
      IncomingRequestsUpdated event,
      Emitter<ChatRequestState> emit,
      ) {
    _cachedIncomingRequests = event.requests;
    emit(IncomingRequestsLoaded(event.requests));
  }

  Future<void> _onSubscribeBetweenUsers(
      SubscribeToRequestBetweenUsers event,
      Emitter<ChatRequestState> emit,
      ) async {
    emit(ChatRequestLoading());
    await _betweenUsersSub?.cancel();
    _betweenUsersSub = _getChatRequestBetweenUsersUseCase(event.user1, event.user2).listen(
          (request) => add(BetweenUsersRequestUpdated(request)),
    );
  }

  void _onBetweenUsersUpdated(
      BetweenUsersRequestUpdated event,
      Emitter<ChatRequestState> emit,
      ) {
    _cachedBetweenUsersRequest = event.request;
    emit(BetweenUsersRequestLoaded(event.request));
  }

  Future<void> _onSendRequest(
      SendChatRequestEvent event,
      Emitter<ChatRequestState> emit,
      ) async {
    _cachedBetweenUsersRequest = event.request;
    emit(BetweenUsersRequestLoaded(event.request));

    try {
      await _sendChatRequestUseCase(event.request);
      emit(BetweenUsersRequestLoaded(
        event.request,
        feedbackMessage: 'Chat request sent',
      ));
    } catch (e) {
      emit(BetweenUsersRequestLoaded(
        _cachedBetweenUsersRequest,
        feedbackMessage: NetworkErrorFormatter.format(e),
        isErrorFeedback: true,
      ));
    }
  }

  Future<void> _onAcceptRequest(
      AcceptChatRequestEvent event,
      Emitter<ChatRequestState> emit,
      ) async {
    try {
      await _updateChatRequestStatusUseCase(event.requestId, ChatRequestStatus.accepted);

      if (_cachedBetweenUsersRequest?.requestId == event.requestId) {
        _cachedBetweenUsersRequest =
            _withStatus(_cachedBetweenUsersRequest!, ChatRequestStatus.accepted);
        emit(BetweenUsersRequestLoaded(
          _cachedBetweenUsersRequest,
          feedbackMessage: 'Request accepted',
        ));
      }

      if (_cachedIncomingRequests.isNotEmpty) {
        _cachedIncomingRequests = _cachedIncomingRequests
            .map((r) => r.requestId == event.requestId
            ? _withStatus(r, ChatRequestStatus.accepted)
            : r)
            .toList();
        emit(IncomingRequestsLoaded(
          _cachedIncomingRequests,
          feedbackMessage: 'Request accepted',
        ));
      }
    } catch (e) {
      _emitErrorForCurrentView(emit, e.toString());
    }
  }

  Future<void> _onRejectRequest(
      RejectChatRequestEvent event,
      Emitter<ChatRequestState> emit,
      ) async {
    try {
      await _updateChatRequestStatusUseCase(event.requestId, ChatRequestStatus.rejected);

      if (_cachedBetweenUsersRequest?.requestId == event.requestId) {
        _cachedBetweenUsersRequest =
            _withStatus(_cachedBetweenUsersRequest!, ChatRequestStatus.rejected);
        emit(BetweenUsersRequestLoaded(
          _cachedBetweenUsersRequest,
          feedbackMessage: 'Request rejected',
        ));
      }

      if (_cachedIncomingRequests.isNotEmpty) {
        _cachedIncomingRequests = _cachedIncomingRequests
            .where((r) => r.requestId != event.requestId)
            .toList();
        emit(IncomingRequestsLoaded(
          _cachedIncomingRequests,
          feedbackMessage: 'Request rejected',
        ));
      }
    } catch (e) {
      _emitErrorForCurrentView(emit, e.toString());
    }
  }

  void _onClearFeedback(ClearChatRequestFeedback event, Emitter<ChatRequestState> emit) {
    if (state is BetweenUsersRequestLoaded) {
      final s = state as BetweenUsersRequestLoaded;
      emit(BetweenUsersRequestLoaded(s.request));
    } else if (state is IncomingRequestsLoaded) {
      final s = state as IncomingRequestsLoaded;
      emit(IncomingRequestsLoaded(s.requests));
    }
  }

  void _emitErrorForCurrentView(Emitter<ChatRequestState> emit, String error) {
    if (state is BetweenUsersRequestLoaded) {
      final s = state as BetweenUsersRequestLoaded;
      emit(BetweenUsersRequestLoaded(
        s.request,
        feedbackMessage: error,
        isErrorFeedback: true,
      ));
    } else if (state is IncomingRequestsLoaded) {
      final s = state as IncomingRequestsLoaded;
      emit(IncomingRequestsLoaded(
        s.requests,
        feedbackMessage: error,
        isErrorFeedback: true,
      ));
    } else {
      emit(ChatRequestFailure(error));
    }
  }

  ChatRequestEntity _withStatus(ChatRequestEntity request, ChatRequestStatus status) {
    return ChatRequestEntity(
      requestId: request.requestId,
      senderId: request.senderId,
      senderName: request.senderName,
      senderImage: request.senderImage,
      receiverId: request.receiverId,
      receiverName: request.receiverName,
      receiverImage: request.receiverImage,
      status: status,
      createdAt: request.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<String?> openChatAfterAccept(String uid1, String uid2) async {
    return _getOrCreateChatRoomUseCase(uid1, uid2);
  }

  @override
  Future<void> close() {
    _incomingSub?.cancel();
    _betweenUsersSub?.cancel();
    return super.close();
  }
}