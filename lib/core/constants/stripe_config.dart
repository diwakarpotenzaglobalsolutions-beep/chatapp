/// Client-safe Stripe configuration.
/// Publishable key and price ID can live here.
/// Secret key MUST be passed via --dart-define at build time (never commit it).
class StripeConfig {
  /// Stripe publishable key (safe for client apps).
  static const String publishableKey =
      'pk_test_51U39FlP3vGQCAtHnW4EshL16VTasTrgWG2IGatA9UJn5ksMyqFuH63jHplshK7BbWgv7dXAcC4A1iqjofDZaAjgB00NTYSaqLf';

  /// Stripe secret key — inject at build time only:
  /// --dart-define=STRIPE_SECRET_KEY=sk_test_...
  static const String secretKey = String.fromEnvironment('STRIPE_SECRET_KEY');

  /// Stripe Price ID — inject at build time or set your price here:
  /// --dart-define=STRIPE_PRICE_ID=price_...
  static const String priceId = 'price_1U3BK5P3vGQCAtHnVitFeskI';

  static const String planName = 'Premium';
  static const String billingPeriodLabel = 'Monthly';
  static const String displayPrice = '\$9.99';
  static const int trialDays = 7;
  static const String merchantDisplayName = 'ELITE CHAT';

  static const String termsUrl = 'https://stripe.com/legal/consumer';
  static const String privacyUrl = 'https://stripe.com/privacy';
}
