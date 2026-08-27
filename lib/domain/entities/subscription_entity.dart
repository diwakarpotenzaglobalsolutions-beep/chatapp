import 'package:equatable/equatable.dart';

enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  canceled,
  expired,
  paymentFailed,
  unknown,
}

extension SubscriptionStatusX on SubscriptionStatus {
  String get value {
    switch (this) {
      case SubscriptionStatus.trialing:
        return 'trialing';
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.pastDue:
        return 'past_due';
      case SubscriptionStatus.canceled:
        return 'canceled';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.paymentFailed:
        return 'payment_failed';
      case SubscriptionStatus.unknown:
        return 'unknown';
    }
  }

  static SubscriptionStatus fromString(String? raw) {
    switch (raw) {
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'payment_failed':
        return SubscriptionStatus.paymentFailed;
      default:
        return SubscriptionStatus.unknown;
    }
  }
}

class SubscriptionEntity extends Equatable {
  final SubscriptionStatus status;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripePriceId;
  final bool trialUsed;
  final String planName;
  final String billingPeriod;
  final bool hasAccess;
  final int daysRemaining;

  const SubscriptionEntity({
    this.status = SubscriptionStatus.unknown,
    this.trialStartDate,
    this.trialEndDate,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePriceId,
    this.trialUsed = false,
    this.planName = 'Premium',
    this.billingPeriod = 'monthly',
    this.hasAccess = false,
    this.daysRemaining = 0,
  });

  bool get isTrialActive => status == SubscriptionStatus.trialing && hasAccess;

  bool get isSubscriptionActive =>
      status == SubscriptionStatus.active || status == SubscriptionStatus.pastDue;

  SubscriptionEntity copyWith({
    SubscriptionStatus? status,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripePriceId,
    bool? trialUsed,
    String? planName,
    String? billingPeriod,
    bool? hasAccess,
    int? daysRemaining,
  }) {
    return SubscriptionEntity(
      status: status ?? this.status,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      trialUsed: trialUsed ?? this.trialUsed,
      planName: planName ?? this.planName,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      hasAccess: hasAccess ?? this.hasAccess,
      daysRemaining: daysRemaining ?? this.daysRemaining,
    );
  }

  @override
  List<Object?> get props => [
        status,
        trialStartDate,
        trialEndDate,
        subscriptionStartDate,
        subscriptionEndDate,
        stripeCustomerId,
        stripeSubscriptionId,
        stripePriceId,
        trialUsed,
        planName,
        billingPeriod,
        hasAccess,
        daysRemaining,
      ];
}

class PaymentSheetData extends Equatable {
  final String? paymentIntentClientSecret;
  final String? setupIntentClientSecret;
  final String ephemeralKeySecret;
  final String customerId;
  final String subscriptionId;

  const PaymentSheetData({
    this.paymentIntentClientSecret,
    this.setupIntentClientSecret,
    required this.ephemeralKeySecret,
    required this.customerId,
    required this.subscriptionId,
  });

  bool get hasClientSecret =>
      (paymentIntentClientSecret?.isNotEmpty ?? false) ||
      (setupIntentClientSecret?.isNotEmpty ?? false);

  @override
  List<Object?> get props => [
        paymentIntentClientSecret,
        setupIntentClientSecret,
        ephemeralKeySecret,
        customerId,
        subscriptionId,
      ];
}
