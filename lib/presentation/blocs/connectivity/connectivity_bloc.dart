import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/connectivity_service.dart';

abstract class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object?> get props => [];
}

class StartConnectivityMonitoring extends ConnectivityEvent {}

class ConnectivityStatusChanged extends ConnectivityEvent {
  final bool isConnected;

  const ConnectivityStatusChanged(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

class ClearReconnectedFlag extends ConnectivityEvent {}

abstract class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object?> get props => [];
}

class ConnectivityInitial extends ConnectivityState {}

class ConnectivityUpdated extends ConnectivityState {
  final bool isConnected;
  final bool justReconnected;

  const ConnectivityUpdated({
    required this.isConnected,
    this.justReconnected = false,
  });

  @override
  List<Object?> get props => [isConnected, justReconnected];
}

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _subscription;

  ConnectivityBloc({required ConnectivityService connectivityService})
      : _connectivityService = connectivityService,
        super(ConnectivityInitial()) {
    on<StartConnectivityMonitoring>(_onStart);
    on<ConnectivityStatusChanged>(_onStatusChanged);
    on<ClearReconnectedFlag>(_onClearReconnectedFlag);
  }

  Future<void> _onStart(
    StartConnectivityMonitoring event,
    Emitter<ConnectivityState> emit,
  ) async {
    final isConnected = await _connectivityService.checkConnection();
    emit(ConnectivityUpdated(isConnected: isConnected));

    await _subscription?.cancel();
    _subscription = _connectivityService.onConnectivityChanged.listen(
      (connected) => add(ConnectivityStatusChanged(connected)),
    );
  }

  void _onStatusChanged(
    ConnectivityStatusChanged event,
    Emitter<ConnectivityState> emit,
  ) {
    final wasConnected = state is ConnectivityUpdated
        ? (state as ConnectivityUpdated).isConnected
        : true;

    emit(ConnectivityUpdated(
      isConnected: event.isConnected,
      justReconnected: !wasConnected && event.isConnected,
    ));
  }

  void _onClearReconnectedFlag(
    ClearReconnectedFlag event,
    Emitter<ConnectivityState> emit,
  ) {
    if (state is! ConnectivityUpdated) return;
    final current = state as ConnectivityUpdated;
    emit(ConnectivityUpdated(
      isConnected: current.isConnected,
      justReconnected: false,
    ));
  }

  bool get isConnected {
    if (state is ConnectivityUpdated) {
      return (state as ConnectivityUpdated).isConnected;
    }
    return true;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
