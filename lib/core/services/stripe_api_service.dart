import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/stripe_config.dart';

class StripeConfigException implements Exception {
  final String message;
  StripeConfigException(this.message);

  @override
  String toString() => message;
}

class StripeSubscriptionResult {
  final String subscriptionId;
  final String customerId;
  final String status;
  final String rawStatus;
  final String? priceId;
  final String? paymentIntentClientSecret;
  final String? setupIntentClientSecret;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const StripeSubscriptionResult({
    required this.subscriptionId,
    required this.customerId,
    required this.status,
    required this.rawStatus,
    this.priceId,
    this.paymentIntentClientSecret,
    this.setupIntentClientSecret,
    this.periodStart,
    this.periodEnd,
  });

  bool get hasPaymentSecret =>
      (paymentIntentClientSecret?.isNotEmpty ?? false) ||
      (setupIntentClientSecret?.isNotEmpty ?? false);
}

/// Calls Stripe REST API directly from Flutter for PaymentSheet subscriptions.
class StripeApiService {
  static const _baseUrl = 'https://api.stripe.com/v1';
  static const _apiVersion = '2024-06-20';

  String get _secretKey {
    if (StripeConfig.secretKey.isEmpty) {
      throw StripeConfigException(
        'STRIPE_SECRET_KEY is missing. Add it in stripe_config.dart or run with:\n'
        'flutter run --dart-define=STRIPE_SECRET_KEY=sk_test_... '
        '--dart-define=STRIPE_PRICE_ID=price_...',
      );
    }
    return StripeConfig.secretKey;
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Stripe-Version': _apiVersion,
      };

  Future<String> createCustomer({
    required String email,
    required String name,
    required String firebaseUid,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/customers'),
      headers: _authHeaders,
      body: {
        'email': email,
        'name': name,
        'metadata[firebaseUid]': firebaseUid,
      },
    );

    final json = _decode(response);
    return json['id'] as String;
  }

  Future<String> createEphemeralKey(String customerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ephemeral_keys'),
      headers: _authHeaders,
      body: {'customer': customerId},
    );

    final json = _decode(response);
    return json['secret'] as String;
  }

  Future<void> cancelIncompleteSubscriptions(String customerId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/subscriptions?customer=$customerId&status=incomplete&limit=10',
      ),
      headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
    );

    final json = _decode(response);
    final data = json['data'] as List<dynamic>? ?? [];

    for (final item in data) {
      final subId = item['id'] as String?;
      if (subId != null) {
        await http.delete(
          Uri.parse('$_baseUrl/subscriptions/$subId'),
          headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
        );
      }
    }
  }

  Future<StripeSubscriptionResult> createSubscription({
    required String customerId,
    required String firebaseUid,
  }) async {
    if (StripeConfig.priceId.isEmpty) {
      throw StripeConfigException(
        'STRIPE_PRICE_ID is missing. Add it in stripe_config.dart or run with:\n'
        'flutter run --dart-define=STRIPE_SECRET_KEY=sk_test_... '
        '--dart-define=STRIPE_PRICE_ID=price_...',
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/subscriptions'),
      headers: _authHeaders,
      body: {
        'customer': customerId,
        'items[0][price]': StripeConfig.priceId,
        'payment_behavior': 'default_incomplete',
        'payment_settings[save_default_payment_method]': 'on_subscription',
        'payment_settings[payment_method_types][0]': 'card',
        'expand[0]': 'latest_invoice.confirmation_secret',
        'expand[1]': 'latest_invoice.payment_intent',
        'expand[2]': 'pending_setup_intent',
        'metadata[firebaseUid]': firebaseUid,
      },
    );

    var result = _parseSubscription(_decode(response));

    if (!result.hasPaymentSecret) {
      result = await retrieveSubscription(result.subscriptionId);
    }

    return result;
  }

  Future<StripeSubscriptionResult> retrieveSubscription(String subscriptionId) async {
    final raw = await retrieveSubscriptionRaw(subscriptionId);
    return _parseSubscriptionWithFallbacks(raw);
  }

  Future<StripeSubscriptionResult> parseSubscriptionResponse(
    Map<String, dynamic> stripeJson,
  ) {
    return _parseSubscriptionWithFallbacks(stripeJson);
  }

  /// Returns the complete Stripe subscription JSON (expanded for backend use).
  Future<Map<String, dynamic>> retrieveSubscriptionRaw(String subscriptionId) async {
    Map<String, dynamic>? lastResponse;

    for (var attempt = 0; attempt < 3; attempt++) {
      lastResponse = await _fetchSubscriptionRaw(subscriptionId);
      final status = lastResponse['status'] as String?;
      if (status == 'active' || status == 'trialing' || attempt == 2) {
        return lastResponse;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    return lastResponse!;
  }

  Future<Map<String, dynamic>> _fetchSubscriptionRaw(String subscriptionId) async {
    final uri = Uri.parse('$_baseUrl/subscriptions/$subscriptionId').replace(
      queryParameters: {
        'expand[0]': 'latest_invoice',
        'expand[1]': 'latest_invoice.payment_intent',
        'expand[2]': 'latest_invoice.confirmation_secret',
        'expand[3]': 'customer',
        'expand[4]': 'pending_setup_intent',
        'expand[5]': 'default_payment_method',
        'expand[6]': 'items.data.price',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
    );

    return _decode(response);
  }

  /// Logs the full Stripe JSON after a successful payment for backend integration.
  void logPaymentSuccessResponse(Map<String, dynamic> stripeJson) {
    const encoder = JsonEncoder.withIndent('  ');
    final formatted = encoder.convert(stripeJson);

    developer.log(
      formatted,
      name: 'StripePaymentSuccess',
    );

    debugPrint('========== STRIPE PAYMENT SUCCESS — FULL JSON RESPONSE ==========');
    _printLongDebug(formatted);
    debugPrint('=================================================================');
  }

  void _printLongDebug(String text) {
    const chunkSize = 800;
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      debugPrint(text.substring(i, end));
    }
  }

  Future<StripeSubscriptionResult> _parseSubscriptionWithFallbacks(
    Map<String, dynamic> raw,
  ) async {
    var result = _parseSubscription(raw);

    if (!result.hasPaymentSecret) {
      final invoiceId = _invoiceIdFromSubscription(raw);
      if (invoiceId != null) {
        final secrets = await _resolveInvoiceSecrets(invoiceId);
        result = StripeSubscriptionResult(
          subscriptionId: result.subscriptionId,
          customerId: result.customerId,
          status: result.status,
          rawStatus: result.rawStatus,
          priceId: result.priceId,
          paymentIntentClientSecret: secrets.paymentIntentClientSecret,
          setupIntentClientSecret: secrets.setupIntentClientSecret,
          periodStart: result.periodStart,
          periodEnd: result.periodEnd,
        );
      }

      if (!result.hasPaymentSecret) {
        final pendingSetupIntent = raw['pending_setup_intent'];
        if (pendingSetupIntent is String && pendingSetupIntent.isNotEmpty) {
          final setupSecret = await _fetchSetupIntentSecret(pendingSetupIntent);
          result = StripeSubscriptionResult(
            subscriptionId: result.subscriptionId,
            customerId: result.customerId,
            status: result.status,
            rawStatus: result.rawStatus,
            priceId: result.priceId,
            setupIntentClientSecret: setupSecret,
            periodStart: result.periodStart,
            periodEnd: result.periodEnd,
          );
        }
      }
    }

    return result;
  }

  StripeSubscriptionResult _parseSubscription(Map<String, dynamic> json) {
    final secrets = _extractPaymentSecrets(json);
    final rawStatus = json['status'] as String? ?? 'unknown';

    final items = json['items']?['data'] as List<dynamic>?;
    String? priceId;
    if (items != null && items.isNotEmpty) {
      final item = items.first;
      if (item is Map<String, dynamic>) {
        final price = item['price'];
        if (price is Map<String, dynamic>) {
          priceId = price['id'] as String?;
        } else if (price is String) {
          priceId = price;
        }
      }
    }

    return StripeSubscriptionResult(
      subscriptionId: _readStripeId(json['id']) ?? '',
      customerId: _readStripeId(json['customer']) ?? '',
      status: _mapStripeStatus(rawStatus),
      rawStatus: rawStatus,
      priceId: priceId,
      paymentIntentClientSecret: secrets.paymentIntentClientSecret,
      setupIntentClientSecret: secrets.setupIntentClientSecret,
      periodStart: _fromUnix(json['current_period_start']) ?? _fromUnix(json['start_date']),
      periodEnd: _fromUnix(json['current_period_end']),
    );
  }

  String? _readStripeId(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map<String, dynamic>) {
      final id = value['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  _PaymentSecrets _extractPaymentSecrets(Map<String, dynamic> json) {
    String? paymentIntentSecret;
    String? setupIntentSecret;

    final invoice = json['latest_invoice'];
    if (invoice is Map<String, dynamic>) {
      paymentIntentSecret ??= _confirmationSecret(invoice);
      paymentIntentSecret ??= _paymentIntentSecret(invoice);
    }

    final pendingSetupIntent = json['pending_setup_intent'];
    if (pendingSetupIntent is Map<String, dynamic>) {
      setupIntentSecret ??= pendingSetupIntent['client_secret'] as String?;
    }

    return _PaymentSecrets(
      paymentIntentClientSecret: paymentIntentSecret,
      setupIntentClientSecret: setupIntentSecret,
    );
  }

  String? _invoiceIdFromSubscription(Map<String, dynamic> json) {
    final invoice = json['latest_invoice'];
    if (invoice is String) return invoice;
    if (invoice is Map<String, dynamic>) return invoice['id'] as String?;
    return null;
  }

  Future<_PaymentSecrets> _resolveInvoiceSecrets(String invoiceId) async {
    final uri = Uri.parse('$_baseUrl/invoices/$invoiceId').replace(
      queryParameters: {
        'expand[0]': 'confirmation_secret',
        'expand[1]': 'payment_intent',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
    );

    final invoice = _decode(response);
    var paymentIntentSecret =
        _confirmationSecret(invoice) ?? _paymentIntentSecret(invoice);

    if (paymentIntentSecret == null) {
      final paymentIntent = invoice['payment_intent'];
      if (paymentIntent is String && paymentIntent.isNotEmpty) {
        paymentIntentSecret = await _fetchPaymentIntentSecret(paymentIntent);
      }
    }

    return _PaymentSecrets(
      paymentIntentClientSecret: paymentIntentSecret,
      setupIntentClientSecret: null,
    );
  }

  String? _confirmationSecret(Map<String, dynamic> invoice) {
    final confirmationSecret = invoice['confirmation_secret'];
    if (confirmationSecret is Map<String, dynamic>) {
      return confirmationSecret['client_secret'] as String?;
    }
    return null;
  }

  String? _paymentIntentSecret(Map<String, dynamic> invoice) {
    final paymentIntent = invoice['payment_intent'];
    if (paymentIntent is Map<String, dynamic>) {
      return paymentIntent['client_secret'] as String?;
    }
    return null;
  }

  Future<String?> _fetchPaymentIntentSecret(String paymentIntentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/payment_intents/$paymentIntentId'),
      headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
    );
    final json = _decode(response);
    return json['client_secret'] as String?;
  }

  Future<String?> _fetchSetupIntentSecret(String setupIntentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/setup_intents/$setupIntentId'),
      headers: {'Authorization': 'Bearer $_secretKey', 'Stripe-Version': _apiVersion},
    );
    final json = _decode(response);
    return json['client_secret'] as String?;
  }

  String _mapStripeStatus(String? raw) {
    switch (raw) {
      case 'trialing':
        return 'trialing';
      case 'active':
        return 'active';
      case 'past_due':
        return 'past_due';
      case 'canceled':
        return 'canceled';
      case 'unpaid':
      case 'incomplete':
      case 'incomplete_expired':
        return 'payment_failed';
      default:
        return 'expired';
    }
  }

  DateTime? _fromUnix(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return null;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final json = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final error = json is Map<String, dynamic> ? json['error'] : null;
      final message = error is Map<String, dynamic>
          ? error['message'] as String? ?? response.body
          : response.body;
      throw Exception(message);
    }
    return Map<String, dynamic>.from(json as Map);
  }
}

class _PaymentSecrets {
  final String? paymentIntentClientSecret;
  final String? setupIntentClientSecret;

  const _PaymentSecrets({
    this.paymentIntentClientSecret,
    this.setupIntentClientSecret,
  });
}
