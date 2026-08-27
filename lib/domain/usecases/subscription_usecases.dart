import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class WatchSubscriptionUseCase {
  final SubscriptionRepository repository;
  WatchSubscriptionUseCase(this.repository);

  Stream<SubscriptionEntity> call(String userId) => repository.watchSubscription(userId);
}

class InitializeTrialUseCase {
  final SubscriptionRepository repository;
  InitializeTrialUseCase(this.repository);

  Future<SubscriptionEntity> call(String userId) => repository.initializeTrial(userId);
}

class VerifySubscriptionUseCase {
  final SubscriptionRepository repository;
  VerifySubscriptionUseCase(this.repository);

  Future<SubscriptionEntity> call(String userId) => repository.verifySubscription(userId);
}

class CreateSubscriptionPaymentSheetUseCase {
  final SubscriptionRepository repository;
  CreateSubscriptionPaymentSheetUseCase(this.repository);

  Future<PaymentSheetData> call({
    required String userId,
    required String email,
    required String fullName,
  }) {
    return repository.createSubscriptionPaymentSheet(
      userId: userId,
      email: email,
      fullName: fullName,
    );
  }
}

class SyncSubscriptionAfterPaymentUseCase {
  final SubscriptionRepository repository;
  SyncSubscriptionAfterPaymentUseCase(this.repository);

  Future<SubscriptionEntity> call({
    required String userId,
    required String subscriptionId,
  }) {
    return repository.syncSubscriptionAfterPayment(
      userId: userId,
      subscriptionId: subscriptionId,
    );
  }
}
