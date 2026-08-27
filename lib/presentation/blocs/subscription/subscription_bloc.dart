import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/stripe_api_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../domain/entities/subscription_entity.dart';
import '../../../domain/usecases/subscription_usecases.dart';

/// ===============================================================
/// EVENTS
/// ===============================================================

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching the user's subscription.
class SubscriptionWatchRequested extends SubscriptionEvent {
  final String userId;

  const SubscriptionWatchRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Stop watching the subscription.
class SubscriptionStopped extends SubscriptionEvent {}

/// Initialize the user's free trial.
class SubscriptionInitializeTrialRequested extends SubscriptionEvent {
  final String userId;
  const SubscriptionInitializeTrialRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

/// Verify the current subscription.
class SubscriptionVerifyRequested extends SubscriptionEvent {
  final String userId;
  const SubscriptionVerifyRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}

/// Create Stripe PaymentSheet data.
class SubscriptionPaymentSheetRequested extends SubscriptionEvent {
  final String userId;
  final String email;
  final String fullName;
  const SubscriptionPaymentSheetRequested({
    required this.userId,
    required this.email,
    required this.fullName,
  });
  @override
  List<Object?> get props => [userId, email, fullName];
}

/// Called after Stripe payment is completed.
class SubscriptionPaymentCompleted extends SubscriptionEvent {
  final String userId;
  final String subscriptionId;
  const SubscriptionPaymentCompleted({
    required this.userId,
    required this.subscriptionId,
  });
  @override
  List<Object?> get props => [userId, subscriptionId];
}

/// Clears PaymentSheet data after it has been consumed by the UI.
class SubscriptionPaymentSheetCleared extends SubscriptionEvent {}

/// Internal event used by the subscription stream.
///
/// IMPORTANT:
/// We do NOT call emit() directly inside Stream.listen().
/// Instead, we add this event to the Bloc.
class _SubscriptionUpdated extends SubscriptionEvent {
  final SubscriptionEntity subscription;

  const _SubscriptionUpdated(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

/// Internal event used when subscription stream fails.
class _SubscriptionWatchFailed extends SubscriptionEvent {
  final Object error;

  const _SubscriptionWatchFailed(this.error);

  @override
  List<Object?> get props => [error];
}

/// ===============================================================
/// STATES
/// ===============================================================

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// Initial state.
class SubscriptionInitial extends SubscriptionState {}

/// Subscription loading.
class SubscriptionLoading extends SubscriptionState {}

/// Subscription successfully loaded.
class SubscriptionLoaded extends SubscriptionState {
  final SubscriptionEntity subscription;

  /// Stripe PaymentSheet data.
  final PaymentSheetData? paymentSheetData;

  /// Indicates that an action such as payment/verification
  /// is currently running.
  final bool actionInProgress;

  const SubscriptionLoaded({
    required this.subscription,
    this.paymentSheetData,
    this.actionInProgress = false,
  });

  /// Whether the user currently has access.
  bool get hasAccess => SubscriptionService.hasAccess(subscription);

  /// Whether the free trial is active.
  bool get isTrialActive => SubscriptionService.isTrialActive(subscription);

  /// Number of days remaining in the trial/subscription.
  int get daysRemaining => SubscriptionService.daysRemaining(subscription);

  /// Create a modified copy of the current state.
  SubscriptionLoaded copyWith({
    SubscriptionEntity? subscription,
    PaymentSheetData? paymentSheetData,
    bool? actionInProgress,
    bool clearPaymentSheet = false,
  }) {
    return SubscriptionLoaded(
      subscription: subscription ?? this.subscription,

      paymentSheetData: clearPaymentSheet
          ? null
          : (paymentSheetData ?? this.paymentSheetData),

      actionInProgress: actionInProgress ?? this.actionInProgress,
    );
  }

  @override
  List<Object?> get props => [subscription, paymentSheetData, actionInProgress];
}

/// Subscription failure.
class SubscriptionFailure extends SubscriptionState {
  final String message;

  const SubscriptionFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// ===============================================================
/// BLOC
/// ===============================================================

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final WatchSubscriptionUseCase _watchSubscriptionUseCase;

  final InitializeTrialUseCase _initializeTrialUseCase;

  final VerifySubscriptionUseCase _verifySubscriptionUseCase;

  final CreateSubscriptionPaymentSheetUseCase _createPaymentSheetUseCase;

  final SyncSubscriptionAfterPaymentUseCase _syncAfterPaymentUseCase;

  StreamSubscription<SubscriptionEntity>? _subscription;

  SubscriptionBloc({
    required WatchSubscriptionUseCase watchSubscriptionUseCase,
    required InitializeTrialUseCase initializeTrialUseCase,
    required VerifySubscriptionUseCase verifySubscriptionUseCase,
    required CreateSubscriptionPaymentSheetUseCase createPaymentSheetUseCase,
    required SyncSubscriptionAfterPaymentUseCase syncAfterPaymentUseCase,
  })  : _watchSubscriptionUseCase = watchSubscriptionUseCase,
        _initializeTrialUseCase = initializeTrialUseCase,
        _verifySubscriptionUseCase = verifySubscriptionUseCase,
        _createPaymentSheetUseCase = createPaymentSheetUseCase,
        _syncAfterPaymentUseCase = syncAfterPaymentUseCase,
        super(SubscriptionInitial()) {
    /// Public events.
    on<SubscriptionWatchRequested>(_onWatch);

    on<SubscriptionStopped>(_onStop);

    on<SubscriptionInitializeTrialRequested>(_onInitializeTrial);

    on<SubscriptionVerifyRequested>(_onVerify);

    on<SubscriptionPaymentSheetRequested>(_onPaymentSheet);

    on<SubscriptionPaymentCompleted>(_onPaymentCompleted);

    on<SubscriptionPaymentSheetCleared>(_onPaymentSheetCleared);

    /// Internal stream events.
    on<_SubscriptionUpdated>(_onSubscriptionUpdated);

    on<_SubscriptionWatchFailed>(_onSubscriptionWatchFailed);
  }

  /// =============================================================
  /// WATCH SUBSCRIPTION
  /// =============================================================

  Future<void> _onWatch(
    SubscriptionWatchRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      /// Cancel previous subscription first.
      await _subscription?.cancel();

      _subscription = null;

      /// Show loading.
      emit(SubscriptionLoading());

      /// Start watching subscription.
      final stream = _watchSubscriptionUseCase(event.userId);

      _subscription = stream.listen(
        (subscription) {
          /// IMPORTANT:
          ///
          /// DO NOT do:
          ///
          /// emit(...)
          ///
          /// here.
          ///
          /// The stream callback can execute after
          /// _onWatch() has already completed.
          ///
          /// Instead add another Bloc event.
          if (!isClosed) {
            add(_SubscriptionUpdated(subscription));
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            add(_SubscriptionWatchFailed(error));
          }
        },
      );
    } catch (e) {
      if (!isClosed) {
        emit(
          SubscriptionFailure(
            _friendlyError(e, 'Could not load subscription status.'),
          ),
        );
      }
    }
  }

  /// =============================================================
  /// SUBSCRIPTION STREAM UPDATE
  /// =============================================================

  Future<void> _onSubscriptionUpdated(
    _SubscriptionUpdated event,
    Emitter<SubscriptionState> emit,
  ) async {
    /// Get current state.
    final current = state is SubscriptionLoaded
        ? state as SubscriptionLoaded
        : null;

    /// Preserve existing PaymentSheet data and
    /// action state when subscription changes.
    emit(
      SubscriptionLoaded(
        subscription: event.subscription,
        paymentSheetData: current?.paymentSheetData,
        actionInProgress: current?.actionInProgress ?? false,
      ),
    );
  }

  /// =============================================================
  /// SUBSCRIPTION STREAM ERROR
  /// =============================================================

  Future<void> _onSubscriptionWatchFailed(
    _SubscriptionWatchFailed event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(
      SubscriptionFailure(
        _friendlyError(event.error, 'Could not load subscription status.'),
      ),
    );
  }

  /// =============================================================
  /// STOP WATCHING
  /// =============================================================

  Future<void> _onStop(
    SubscriptionStopped event,
    Emitter<SubscriptionState> emit,
  ) async {
    await _subscription?.cancel();

    _subscription = null;

    emit(SubscriptionInitial());
  }

  /// =============================================================
  /// INITIALIZE FREE TRIAL
  /// =============================================================

  Future<void> _onInitializeTrial(
    SubscriptionInitializeTrialRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      /// Start the user's free trial.
      final subscription = await _initializeTrialUseCase(event.userId);

      emit(SubscriptionLoaded(subscription: subscription));
    } catch (e) {
      emit(
        SubscriptionFailure(
          _friendlyError(e, 'Could not start your free trial.'),
        ),
      );
    }
  }

  /// =============================================================
  /// VERIFY SUBSCRIPTION
  /// =============================================================

  Future<void> _onVerify(
    SubscriptionVerifyRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    /// Preserve current state if available.
    final current = state is SubscriptionLoaded
        ? state as SubscriptionLoaded
        : null;

    if (current != null) {
      /// Show progress.
      emit(current.copyWith(actionInProgress: true, clearPaymentSheet: true));
    } else {
      emit(SubscriptionLoading());
    }

    try {
      /// Verify subscription from backend.
      final subscription = await _verifySubscriptionUseCase(event.userId);

      /// Update state.
      emit(SubscriptionLoaded(subscription: subscription));
    } catch (e) {
      emit(
        SubscriptionFailure(
          _friendlyError(e, 'Could not verify subscription.'),
        ),
      );
    }
  }

  /// =============================================================
  /// CREATE STRIPE PAYMENT SHEET
  /// =============================================================

  Future<void> _onPaymentSheet(
    SubscriptionPaymentSheetRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    /// Get current state.
    final current = state is SubscriptionLoaded
        ? state as SubscriptionLoaded
        : SubscriptionLoaded(subscription: const SubscriptionEntity());

    /// Show payment loading.
    emit(current.copyWith(actionInProgress: true, clearPaymentSheet: true));

    try {
      /// Create PaymentSheet data.
      final paymentSheet = await _createPaymentSheetUseCase(
        userId: event.userId,
        email: event.email,
        fullName: event.fullName,
      );

      /// PaymentSheet data is ready.
      emit(
        current.copyWith(
          paymentSheetData: paymentSheet,
          actionInProgress: false,
        ),
      );
    } catch (e) {
      final currentState = state is SubscriptionLoaded ? state as SubscriptionLoaded : current;
      emit(
        SubscriptionLoaded(
          subscription: currentState.subscription,
          actionInProgress: false,
        ),
      );
      emit(SubscriptionFailure(_friendlyError(e, 'Could not start payment.')));
    }
  }

  Future<void> _onPaymentSheetCleared(
    SubscriptionPaymentSheetCleared event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (state is SubscriptionLoaded) {
      emit((state as SubscriptionLoaded).copyWith(clearPaymentSheet: true));
    }
  }

  /// =============================================================
  /// PAYMENT COMPLETED
  /// =============================================================

  Future<void> _onPaymentCompleted(
    SubscriptionPaymentCompleted event,
    Emitter<SubscriptionState> emit,
  ) async {
    final current = state is SubscriptionLoaded
        ? state as SubscriptionLoaded
        : SubscriptionLoaded(subscription: const SubscriptionEntity());

    emit(current.copyWith(actionInProgress: true, clearPaymentSheet: true));

    try {
      final subscription = await _syncAfterPaymentUseCase(
        userId: event.userId,
        subscriptionId: event.subscriptionId,
      );
      emit(SubscriptionLoaded(subscription: subscription));
    } catch (e) {
      emit(
        SubscriptionFailure(
          _friendlyError(e, 'Payment succeeded but subscription sync failed.'),
        ),
      );
    }
  }

  String _friendlyError(Object error, String fallback) {
    if (error is StripeConfigException) {
      return error.message;
    }
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return fallback;
  }

  /// =============================================================
  /// CLOSE BLOC
  /// =============================================================

  @override
  Future<void> close() async {
    /// Cancel subscription stream before closing Bloc.
    await _subscription?.cancel();

    _subscription = null;

    /// Close Bloc.
    await super.close();
  }
}
