import '../../domain/entities/subscription_entity.dart';

/// Centralized subscription access logic.
class SubscriptionService {
  const SubscriptionService._();

  static bool isTrialActive(SubscriptionEntity subscription) {
    return subscription.isTrialActive;
  }

  static bool isSubscriptionActive(SubscriptionEntity subscription) {
    return subscription.isSubscriptionActive && subscription.hasAccess;
  }

  static bool hasAccess(SubscriptionEntity subscription) {
    return subscription.hasAccess;
  }

  static int daysRemaining(SubscriptionEntity subscription) {
    if (subscription.daysRemaining > 0) {
      return subscription.daysRemaining;
    }
    final end = subscription.trialEndDate;
    if (end == null) return 0;
    final diff = end.difference(DateTime.now());
    if (end.isAfter(DateTime.now()) && diff.inDays == 0) {
      return 1;
    }
    return diff.inDays.clamp(0, 365);
  }

  static SubscriptionStatus subscriptionStatus(SubscriptionEntity subscription) {
    return subscription.status;
  }

  static SubscriptionEntity evaluateFromFields({
    required SubscriptionStatus status,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool trialUsed = false,
    String planName = 'Premium',
    String billingPeriod = 'monthly',
  }) {
    final now = DateTime.now();
    var resolvedStatus = status;

    if (resolvedStatus == SubscriptionStatus.trialing &&
        trialEndDate != null &&
        now.isAfter(trialEndDate)) {
      resolvedStatus = SubscriptionStatus.expired;
    }

    if (resolvedStatus == SubscriptionStatus.active &&
        subscriptionEndDate != null &&
        now.isAfter(subscriptionEndDate)) {
      resolvedStatus = SubscriptionStatus.expired;
    }

    final activeStatuses = {
      SubscriptionStatus.trialing,
      SubscriptionStatus.active,
      SubscriptionStatus.pastDue,
    };

    final access = activeStatuses.contains(resolvedStatus);

    var daysLeft = 0;
    if (resolvedStatus == SubscriptionStatus.trialing && trialEndDate != null) {
      daysLeft = trialEndDate.difference(now).inDays;
      if (trialEndDate.isAfter(now) && daysLeft == 0) {
        daysLeft = 1;
      }
      daysLeft = daysLeft.clamp(0, 365);
    }

    return SubscriptionEntity(
      status: resolvedStatus,
      trialStartDate: trialStartDate,
      trialEndDate: trialEndDate,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      trialUsed: trialUsed,
      planName: planName,
      billingPeriod: billingPeriod,
      hasAccess: access,
      daysRemaining: daysLeft,
    );
  }
}
