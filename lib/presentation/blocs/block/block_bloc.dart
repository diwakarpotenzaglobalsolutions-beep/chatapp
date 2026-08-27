import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/block_status_entity.dart';
import '../../../domain/entities/blocked_user_entity.dart';
import '../../../core/utils/network_error_formatter.dart';
import '../../../domain/usecases/block_usecases.dart';

abstract class BlockEvent extends Equatable {
  const BlockEvent();

  @override
  List<Object?> get props => [];
}

class WatchBlockStatusRequested extends BlockEvent {
  final String currentUserId;
  final String peerUserId;

  const WatchBlockStatusRequested({
    required this.currentUserId,
    required this.peerUserId,
  });

  @override
  List<Object?> get props => [currentUserId, peerUserId];
}

class BlockStatusUpdated extends BlockEvent {
  final BlockStatusEntity status;

  const BlockStatusUpdated(this.status);

  @override
  List<Object?> get props => [status];
}

class SubscribeToBlockedUsers extends BlockEvent {
  final String userId;

  const SubscribeToBlockedUsers(this.userId);

  @override
  List<Object?> get props => [userId];
}

class BlockedUsersUpdated extends BlockEvent {
  final List<BlockedUserEntity> users;

  const BlockedUsersUpdated(this.users);

  @override
  List<Object?> get props => [users];
}

class BlockUserRequested extends BlockEvent {
  final String blockerId;
  final String blockedUserId;
  final String blockedUserName;
  final String blockedUserImage;

  const BlockUserRequested({
    required this.blockerId,
    required this.blockedUserId,
    required this.blockedUserName,
    this.blockedUserImage = '',
  });

  @override
  List<Object?> get props => [
        blockerId,
        blockedUserId,
        blockedUserName,
        blockedUserImage,
      ];
}

class UnblockUserRequested extends BlockEvent {
  final String blockerId;
  final String blockedUserId;

  const UnblockUserRequested({
    required this.blockerId,
    required this.blockedUserId,
  });

  @override
  List<Object?> get props => [blockerId, blockedUserId];
}

class BlockActionCompleted extends BlockEvent {
  final String message;

  const BlockActionCompleted(this.message);

  @override
  List<Object?> get props => [message];
}

class BlockActionFailed extends BlockEvent {
  final String error;

  const BlockActionFailed(this.error);

  @override
  List<Object?> get props => [error];
}

class ClearBlockFeedback extends BlockEvent {}

abstract class BlockState extends Equatable {
  const BlockState();

  @override
  List<Object?> get props => [];
}

class BlockInitial extends BlockState {}

class BlockStatusState extends BlockState {
  final BlockStatusEntity status;
  final List<BlockedUserEntity> blockedUsers;
  final bool isActionInProgress;
  final String? actionMessage;
  final String? actionError;

  const BlockStatusState({
    this.status = const BlockStatusEntity(),
    this.blockedUsers = const [],
    this.isActionInProgress = false,
    this.actionMessage,
    this.actionError,
  });

  BlockStatusState copyWith({
    BlockStatusEntity? status,
    List<BlockedUserEntity>? blockedUsers,
    bool? isActionInProgress,
    String? actionMessage,
    String? actionError,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return BlockStatusState(
      status: status ?? this.status,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      actionMessage: clearActionMessage ? null : (actionMessage ?? this.actionMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        blockedUsers,
        isActionInProgress,
        actionMessage,
        actionError,
      ];
}

class BlockBloc extends Bloc<BlockEvent, BlockState> {
  final BlockUserUseCase _blockUserUseCase;
  final UnblockUserUseCase _unblockUserUseCase;
  final GetBlockedUsersUseCase _getBlockedUsersUseCase;
  final WatchBlockStatusUseCase _watchBlockStatusUseCase;

  StreamSubscription<BlockStatusEntity>? _statusSub;
  StreamSubscription<List<BlockedUserEntity>>? _blockedUsersSub;

  BlockBloc({
    required BlockUserUseCase blockUserUseCase,
    required UnblockUserUseCase unblockUserUseCase,
    required GetBlockedUsersUseCase getBlockedUsersUseCase,
    required WatchBlockStatusUseCase watchBlockStatusUseCase,
  })  : _blockUserUseCase = blockUserUseCase,
        _unblockUserUseCase = unblockUserUseCase,
        _getBlockedUsersUseCase = getBlockedUsersUseCase,
        _watchBlockStatusUseCase = watchBlockStatusUseCase,
        super(const BlockStatusState()) {
    on<WatchBlockStatusRequested>(_onWatchBlockStatus);
    on<BlockStatusUpdated>(_onBlockStatusUpdated);
    on<SubscribeToBlockedUsers>(_onSubscribeToBlockedUsers);
    on<BlockedUsersUpdated>(_onBlockedUsersUpdated);
    on<BlockUserRequested>(_onBlockUser);
    on<UnblockUserRequested>(_onUnblockUser);
    on<BlockActionCompleted>(_onBlockActionCompleted);
    on<BlockActionFailed>(_onBlockActionFailed);
    on<ClearBlockFeedback>(_onClearFeedback);
  }

  Future<void> _onWatchBlockStatus(
    WatchBlockStatusRequested event,
    Emitter<BlockState> emit,
  ) async {
    await _statusSub?.cancel();
    _statusSub = _watchBlockStatusUseCase(
      currentUserId: event.currentUserId,
      peerUserId: event.peerUserId,
    ).listen((status) => add(BlockStatusUpdated(status)));
  }

  void _onBlockStatusUpdated(BlockStatusUpdated event, Emitter<BlockState> emit) {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(status: event.status));
  }

  Future<void> _onSubscribeToBlockedUsers(
    SubscribeToBlockedUsers event,
    Emitter<BlockState> emit,
  ) async {
    emit(const BlockStatusState());
    await _blockedUsersSub?.cancel();
    _blockedUsersSub = _getBlockedUsersUseCase(event.userId).listen(
      (users) => add(BlockedUsersUpdated(users)),
    );
  }

  void _onBlockedUsersUpdated(
    BlockedUsersUpdated event,
    Emitter<BlockState> emit,
  ) {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(blockedUsers: event.users));
  }

  Future<void> _onBlockUser(
    BlockUserRequested event,
    Emitter<BlockState> emit,
  ) async {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(isActionInProgress: true, clearActionError: true));

    try {
      await _blockUserUseCase(
        blockerId: event.blockerId,
        blockedUserId: event.blockedUserId,
        blockedUserName: event.blockedUserName,
        blockedUserImage: event.blockedUserImage,
      );
      add(const BlockActionCompleted('User blocked'));
    } catch (e) {
      add(BlockActionFailed(NetworkErrorFormatter.format(e)));
    }
  }

  Future<void> _onUnblockUser(
    UnblockUserRequested event,
    Emitter<BlockState> emit,
  ) async {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(isActionInProgress: true, clearActionError: true));

    try {
      await _unblockUserUseCase(
        blockerId: event.blockerId,
        blockedUserId: event.blockedUserId,
      );
      add(const BlockActionCompleted('User unblocked'));
    } catch (e) {
      add(BlockActionFailed(NetworkErrorFormatter.format(e)));
    }
  }

  void _onBlockActionCompleted(
    BlockActionCompleted event,
    Emitter<BlockState> emit,
  ) {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(
      isActionInProgress: false,
      actionMessage: event.message,
      clearActionError: true,
    ));
  }

  void _onBlockActionFailed(BlockActionFailed event, Emitter<BlockState> emit) {
    final current = state is BlockStatusState
        ? state as BlockStatusState
        : const BlockStatusState();
    emit(current.copyWith(
      isActionInProgress: false,
      actionError: event.error,
      clearActionMessage: true,
    ));
  }

  void _onClearFeedback(ClearBlockFeedback event, Emitter<BlockState> emit) {
    if (state is! BlockStatusState) return;
    emit((state as BlockStatusState).copyWith(
      clearActionMessage: true,
      clearActionError: true,
    ));
  }

  @override
  Future<void> close() {
    _statusSub?.cancel();
    _blockedUsersSub?.cancel();
    return super.close();
  }
}
