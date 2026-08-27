import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel extends SubscriptionEntity {
  const SubscriptionModel({
    super.status = SubscriptionStatus.unknown,
    super.trialStartDate,
    super.trialEndDate,
    super.subscriptionStartDate,
    super.subscriptionEndDate,
    super.stripeCustomerId,
    super.stripeSubscriptionId,
    super.stripePriceId,
    super.trialUsed = false,
    super.planName = 'Premium',
    super.billingPeriod = 'monthly',
    super.hasAccess = false,
    super.daysRemaining = 0,
  });

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  factory SubscriptionModel.fromFirestore(Map<String, dynamic> json) {
    return SubscriptionModel(
      status: SubscriptionStatusX.fromString(json['subscriptionStatus'] as String?),
      trialStartDate: parseDate(json['trialStartDate']),
      trialEndDate: parseDate(json['trialEndDate']),
      subscriptionStartDate: parseDate(json['subscriptionStartDate']),
      subscriptionEndDate: parseDate(json['subscriptionEndDate']),
      stripeCustomerId: json['stripeCustomerId'] as String?,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      stripePriceId: json['stripePriceId'] as String?,
      trialUsed: json['trialUsed'] == true,
      planName: json['planName'] as String? ?? 'Premium',
      billingPeriod: json['billingPeriod'] as String? ?? 'monthly',
    );
  }

  factory SubscriptionModel.fromCallable(Map<String, dynamic> json) {
    return SubscriptionModel(
      status: SubscriptionStatusX.fromString(json['subscriptionStatus'] as String?),
      trialStartDate: parseDate(json['trialStartDate']),
      trialEndDate: parseDate(json['trialEndDate']),
      subscriptionStartDate: parseDate(json['subscriptionStartDate']),
      subscriptionEndDate: parseDate(json['subscriptionEndDate']),
      stripeCustomerId: json['stripeCustomerId'] as String?,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      stripePriceId: json['stripePriceId'] as String?,
      trialUsed: json['trialUsed'] == true,
      planName: json['planName'] as String? ?? 'Premium',
      billingPeriod: json['billingPeriod'] as String? ?? 'monthly',
      hasAccess: json['hasAccess'] == true,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}
