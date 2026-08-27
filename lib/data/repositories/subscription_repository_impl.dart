import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasource/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource _remoteDataSource;

  SubscriptionRepositoryImpl({required SubscriptionRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Stream<SubscriptionEntity> watchSubscription(String userId) {
    return _remoteDataSource.watchSubscription(userId);
  }

  @override
  Future<SubscriptionEntity> initializeTrial(String userId) {
    return _remoteDataSource.initializeTrial(userId);
  }

  @override
  Future<SubscriptionEntity> verifySubscription(String userId) {
    return _remoteDataSource.verifySubscription(userId);
  }

  @override
  Future<PaymentSheetData> createSubscriptionPaymentSheet({
    required String userId,
    required String email,
    required String fullName,
  }) {
    return _remoteDataSource.createSubscriptionPaymentSheet(
      userId: userId,
      email: email,
      fullName: fullName,
    );
  }

  @override
  Future<SubscriptionEntity> syncSubscriptionAfterPayment({
    required String userId,
    required String subscriptionId,
  }) {
    return _remoteDataSource.syncSubscriptionAfterPayment(
      userId: userId,
      subscriptionId: subscriptionId,
    );
  }
}
