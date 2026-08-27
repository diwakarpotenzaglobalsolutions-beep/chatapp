import '../entities/subscription_entity.dart';

abstract class SubscriptionRepository {
  Stream<SubscriptionEntity> watchSubscription(String userId);
  Future<SubscriptionEntity> initializeTrial(String userId);
  Future<SubscriptionEntity> verifySubscription(String userId);
  Future<PaymentSheetData> createSubscriptionPaymentSheet({
    required String userId,
    required String email,
    required String fullName,
  });
  Future<SubscriptionEntity> syncSubscriptionAfterPayment({
    required String userId,
    required String subscriptionId,
  });
}
