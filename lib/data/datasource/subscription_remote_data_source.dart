import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/stripe_config.dart';
import '../../core/services/stripe_api_service.dart';
import '../../core/services/subscription_service.dart';
import '../../domain/entities/subscription_entity.dart';
import '../models/subscription_model.dart';

abstract class SubscriptionRemoteDataSource {
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

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StripeApiService _stripeApi;

  SubscriptionRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StripeApiService? stripeApi,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _stripeApi = stripeApi ?? StripeApiService();

  DocumentReference<Map<String, dynamic>> _userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  SubscriptionEntity _evaluateFromDoc(Map<String, dynamic>? data) {
    if (data == null) return const SubscriptionModel();
    final model = SubscriptionModel.fromFirestore(data);
    return SubscriptionService.evaluateFromFields(
      status: model.status,
      trialStartDate: model.trialStartDate,
      trialEndDate: model.trialEndDate,
      subscriptionStartDate: model.subscriptionStartDate,
      subscriptionEndDate: model.subscriptionEndDate,
      trialUsed: model.trialUsed,
      planName: model.planName,
      billingPeriod: model.billingPeriod,
    ).copyWith(
      stripeCustomerId: model.stripeCustomerId,
      stripeSubscriptionId: model.stripeSubscriptionId,
      stripePriceId: model.stripePriceId,
    );
  }

  @override
  Stream<SubscriptionEntity> watchSubscription(String userId) {
    return _userRef(userId).snapshots().map((snapshot) {
      return _evaluateFromDoc(snapshot.data());
    });
  }

  @override
  Future<SubscriptionEntity> initializeTrial(String userId) async {
    final ref = _userRef(userId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('User profile not found.');
    }

    final data = snap.data() ?? {};
    final now = DateTime.now();

    if (data['trialUsed'] == true) {
      return _evaluateFromDoc(data);
    }

    if (['active', 'past_due'].contains(data['subscriptionStatus'])) {
      await ref.update({
        'trialUsed': true,
        'updatedAt': Timestamp.fromDate(now),
      });
      final updated = await ref.get();
      return _evaluateFromDoc(updated.data());
    }

    final createdAt = SubscriptionModel.parseDate(data['createdAt']) ?? now;
    final trialEnd = createdAt.add(Duration(days: StripeConfig.trialDays));
    final isTrialActive = !now.isAfter(trialEnd);

    await ref.set({
      'trialUsed': true,
      'trialStartDate': Timestamp.fromDate(createdAt),
      'trialEndDate': Timestamp.fromDate(trialEnd),
      'subscriptionStatus': isTrialActive ? 'trialing' : 'expired',
      'planName': StripeConfig.planName,
      'billingPeriod': 'monthly',
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    final updated = await ref.get();
    return _evaluateFromDoc(updated.data());
  }

  @override
  Future<SubscriptionEntity> verifySubscription(String userId) async {
    final ref = _userRef(userId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('User profile not found.');
    }

    var data = snap.data() ?? {};
    final subscriptionId = data['stripeSubscriptionId'] as String?;

    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      try {
        final stripeSub = await _stripeApi.retrieveSubscription(subscriptionId);
        await _saveStripeSubscription(userId, stripeSub);
        final updated = await ref.get();
        return _evaluateFromDoc(updated.data());
      } catch (_) {
        // Fall through to Firestore-only verification.
      }
    }

    final now = DateTime.now();
    if (data['subscriptionStatus'] == 'trialing') {
      final trialEnd = SubscriptionModel.parseDate(data['trialEndDate']);
      if (trialEnd != null && now.isAfter(trialEnd)) {
        await ref.update({
          'subscriptionStatus': 'expired',
          'updatedAt': Timestamp.fromDate(now),
        });
        final updated = await ref.get();
        return _evaluateFromDoc(updated.data());
      }
    }

    return _evaluateFromDoc(data);
  }

  @override
  Future<PaymentSheetData> createSubscriptionPaymentSheet({
    required String userId,
    required String email,
    required String fullName,
  }) async {
    final ref = _userRef(userId);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    var customerId = data['stripeCustomerId'] as String?;
    customerId ??= await _stripeApi.createCustomer(
      email: email,
      name: fullName,
      firebaseUid: userId,
    );

    await _stripeApi.cancelIncompleteSubscriptions(customerId);

    final ephemeralKey = await _stripeApi.createEphemeralKey(customerId);
    final subscription = await _stripeApi.createSubscription(
      customerId: customerId,
      firebaseUid: userId,
    );

    if (!subscription.hasPaymentSecret) {
      if (subscription.status == 'active' || subscription.status == 'trialing') {
        await _saveStripeSubscription(userId, subscription);
        throw Exception(
          'Subscription is already active. Pull down to refresh or tap Restore.',
        );
      }
      throw Exception(
        'Could not create Stripe payment session. '
        'Check that your Stripe Price is recurring and has no free trial on Stripe.',
      );
    }

    await ref.set({
      'stripeCustomerId': customerId,
      'stripeSubscriptionId': subscription.subscriptionId,
      'stripePriceId': StripeConfig.priceId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    return PaymentSheetData(
      paymentIntentClientSecret: subscription.paymentIntentClientSecret,
      setupIntentClientSecret: subscription.setupIntentClientSecret,
      ephemeralKeySecret: ephemeralKey,
      customerId: customerId,
      subscriptionId: subscription.subscriptionId,
    );
  }

  @override
  Future<SubscriptionEntity> syncSubscriptionAfterPayment({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      final stripeJson = await _stripeApi.retrieveSubscriptionRaw(subscriptionId);
      _stripeApi.logPaymentSuccessResponse(stripeJson);
      _logBackendSummary(stripeJson);

      final stripeSub = await _stripeApi.parseSubscriptionResponse(stripeJson);
      await _saveStripeSubscription(userId, stripeSub);
      final snap = await _userRef(userId).get();
      return _evaluateFromDoc(snap.data());
    } catch (e, stack) {
      developer.log(
        'Subscription sync failed after payment',
        name: 'StripePaymentSync',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  void _logBackendSummary(Map<String, dynamic> stripeJson) {
    final invoice = stripeJson['latest_invoice'];
    final items = stripeJson['items']?['data'] as List<dynamic>?;
    final price = items != null && items.isNotEmpty
        ? (items.first as Map<String, dynamic>)['price']
        : null;

    final summary = <String, dynamic>{
      'subscriptionId': stripeJson['id'],
      'status': stripeJson['status'],
      'customerId': stripeJson['customer'],
      'currentPeriodStart': stripeJson['current_period_start'],
      'currentPeriodEnd': stripeJson['current_period_end'],
      'cancelAtPeriodEnd': stripeJson['cancel_at_period_end'],
      'priceId': price is Map ? price['id'] : price,
      'metadata': stripeJson['metadata'],
      'latestInvoiceId': invoice is Map ? invoice['id'] : invoice,
      'latestInvoiceStatus': invoice is Map ? invoice['status'] : null,
      'latestInvoiceAmountPaid': invoice is Map ? invoice['amount_paid'] : null,
      'defaultPaymentMethod': stripeJson['default_payment_method'],
    };

    developer.log(
      const JsonEncoder.withIndent('  ').convert(summary),
      name: 'StripePaymentBackendFields',
    );
  }

  Future<void> _saveStripeSubscription(
    String userId,
    StripeSubscriptionResult stripeSub,
  ) async {
    if (stripeSub.subscriptionId.isEmpty || stripeSub.customerId.isEmpty) {
      throw Exception('Invalid Stripe subscription data received after payment.');
    }

    await _userRef(userId).set({
      'subscriptionStatus': stripeSub.status,
      'stripeSubscriptionId': stripeSub.subscriptionId,
      'stripeCustomerId': stripeSub.customerId,
      'stripePriceId': stripeSub.priceId ?? StripeConfig.priceId,
      if (stripeSub.periodStart != null)
        'subscriptionStartDate': Timestamp.fromDate(stripeSub.periodStart!),
      if (stripeSub.periodEnd != null)
        'subscriptionEndDate': Timestamp.fromDate(stripeSub.periodEnd!),
      'planName': StripeConfig.planName,
      'billingPeriod': 'monthly',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  String? get currentUserId => _auth.currentUser?.uid;
}
