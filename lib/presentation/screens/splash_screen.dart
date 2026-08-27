import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/theme.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/subscription/subscription_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthInitial) {
      context.read<AuthBloc>().add(AppStarted());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateForCurrentState());
  }

  void _navigateForCurrentState() {
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthInitial) return;

    if (authState is Unauthenticated) {
      context.go(AppRoutes.login);
      return;
    }

    if (authState is Authenticated) {
      final subState = context.read<SubscriptionBloc>().state;
      if (_shouldGoToSubscription(subState)) {
        context.go(AppRoutes.subscription);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  bool _shouldGoToSubscription(SubscriptionState subState) {
    if (subState is! SubscriptionLoaded || subState.hasAccess) {
      return false;
    }

    final subscription = subState.subscription;
    final awaitingTrialInit = subscription.status == SubscriptionStatus.unknown &&
        !subscription.trialUsed;

    return !awaitingTrialInit;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) => _navigateForCurrentState(),
        ),
        BlocListener<SubscriptionBloc, SubscriptionState>(
          listener: (context, state) {
            final authState = context.read<AuthBloc>().state;
            if (authState is! Authenticated) return;
            _navigateForCurrentState();
          },
        ),
      ],
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: context.scaffoldGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                  child: const Icon(
                    Icons.bubble_chart_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ELITE CHAT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Real-time. Premium. Secure.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
