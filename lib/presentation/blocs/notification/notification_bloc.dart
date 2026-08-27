import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/notification_service.dart';

// Events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class InitializeNotifications extends NotificationEvent {}

class SaveFcmToken extends NotificationEvent {
  final String userId;
  const SaveFcmToken(this.userId);
  @override
  List<Object?> get props => [userId];
}

// States
abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationSuccess extends NotificationState {
  final String? fcmToken;
  const NotificationSuccess(this.fcmToken);
  @override
  List<Object?> get props => [fcmToken];
}

class NotificationFailure extends NotificationState {
  final String error;
  const NotificationFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService;
  StreamSubscription<String>? _tokenRefreshSubscription;

  NotificationBloc({required NotificationService notificationService})
      : _notificationService = notificationService,
        super(NotificationInitial()) {
    on<InitializeNotifications>(_onInitialize);
    on<SaveFcmToken>(_onSaveToken);
  }

  Future<void> _onInitialize(
      InitializeNotifications event,
      Emitter<NotificationState> emit,
      ) async {
    try {
      await _notificationService.initialize();
      final token = await _notificationService.getFcmToken();
      emit(NotificationSuccess(token));
    } catch (e) {
      emit(NotificationFailure(e.toString()));
    }
  }

  Future<void> _onSaveToken(
      SaveFcmToken event,
      Emitter<NotificationState> emit,
      ) async {
    try {
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(event.userId)
            .update({'fcmToken': token});
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(event.userId)
                .update({'fcmToken': newToken});
          });
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _tokenRefreshSubscription?.cancel();
    return super.close();
  }
}