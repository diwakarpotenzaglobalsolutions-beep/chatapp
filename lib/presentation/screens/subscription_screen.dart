import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/stripe_config.dart';
import '../../core/constants/theme.dart';
import '../../domain/entities/subscription_entity.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/subscription/subscription_bloc.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isPresentingSheet = false;

  Future<void> _presentPaymentSheet({
    required PaymentSheetData data,
    required String userId,
  }) async {
    if (_isPresentingSheet) return;
    _isPresentingSheet = true;

    try {
      final SetupPaymentSheetParameters paymentSheetParameters;

      if (data.setupIntentClientSecret?.isNotEmpty ?? false) {
        paymentSheetParameters = SetupPaymentSheetParameters(
          setupIntentClientSecret: data.setupIntentClientSecret,
          customerEphemeralKeySecret: data.ephemeralKeySecret,
          customerId: data.customerId,
          merchantDisplayName: StripeConfig.merchantDisplayName,
          style: ThemeMode.dark,
        );
      } else if (data.paymentIntentClientSecret?.isNotEmpty ?? false) {
        paymentSheetParameters = SetupPaymentSheetParameters(
          paymentIntentClientSecret: data.paymentIntentClientSecret,
          customerEphemeralKeySecret: data.ephemeralKeySecret,
          customerId: data.customerId,
          merchantDisplayName: StripeConfig.merchantDisplayName,
          style: ThemeMode.dark,
        );
      } else {
        throw Exception('Missing Stripe payment client secret.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: paymentSheetParameters,
      );
      await Stripe.instance.presentPaymentSheet();

      if (!mounted) return;
      context.read<SubscriptionBloc>().add(
            SubscriptionPaymentCompleted(
              userId: userId,
              subscriptionId: data.subscriptionId,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful! Verifying subscription...'),
          backgroundColor: AppColors.success,
        ),
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      final message = e.error.localizedMessage ?? 'Payment failed. Please try again.';
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      _isPresentingSheet = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }

        if (state is SubscriptionLoaded && state.paymentSheetData != null) {
          final authState = context.read<AuthBloc>().state;
          if (authState is! Authenticated) return;

          final sheetData = state.paymentSheetData!;
          context.read<SubscriptionBloc>().add(SubscriptionPaymentSheetCleared());
          _presentPaymentSheet(data: sheetData, userId: authState.user.uid);
        }
      },
      builder: (context, state) {
        final subscription = state is SubscriptionLoaded
            ? state.subscription
            : const SubscriptionEntity();
        final isLoading = state is SubscriptionLoading ||
            (state is SubscriptionLoaded && state.actionInProgress);

        final trialExpired = subscription.status == SubscriptionStatus.expired ||
            (!subscription.hasAccess && subscription.trialUsed);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: context.scaffoldGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: const Icon(Icons.workspace_premium_rounded, size: 72, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      trialExpired ? 'Your Free Trial Has Ended' : 'Upgrade to Premium',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      trialExpired
                          ? 'Subscribe to continue using the application and unlock all premium features.'
                          : 'Continue using all premium features with a subscription.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondaryColor, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    _PlanCard(subscription: subscription),
                    const SizedBox(height: 24),
                    const _BenefitsList(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState is! Authenticated) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please sign in to subscribe.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              final user = authState.user;
                              context.read<SubscriptionBloc>().add(
                                    SubscriptionPaymentSheetRequested(
                                      userId: user.uid,
                                      email: user.email,
                                      fullName: user.fullName,
                                    ),
                                  );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Subscribe Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState is! Authenticated) return;
                              context.read<SubscriptionBloc>().add(
                                    SubscriptionVerifyRequested(authState.user.uid),
                                  );
                            },
                      child: const Text('Restore / Check Subscription'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(StripeConfig.termsUrl)),
                          child: const Text('Terms'),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(StripeConfig.privacyUrl)),
                          child: const Text('Privacy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionEntity subscription;

  const _PlanCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              subscription.planName.isNotEmpty ? subscription.planName : StripeConfig.planName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${StripeConfig.displayPrice} / ${StripeConfig.billingPeriodLabel}',
              style: const TextStyle(fontSize: 18, color: AppColors.secondary),
            ),
            if (subscription.isTrialActive) ...[
              const SizedBox(height: 8),
              Text(
                '${subscription.daysRemaining} day${subscription.daysRemaining == 1 ? '' : 's'} remaining in trial',
                style: TextStyle(color: context.textMutedColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Full application access',
      'Chat & group messaging',
      'Media sharing & documents',
      'Audio & video calling',
      'All premium features',
    ];

    return Column(
      children: benefits
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 15))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
