import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/subscription/subscription_bloc.dart';

/// Holds global bloc references for GoRouter redirect logic.
class RouterAccess {
  static AuthBloc? authBloc;
  static SubscriptionBloc? subscriptionBloc;
}
