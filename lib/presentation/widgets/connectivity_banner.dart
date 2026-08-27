import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/theme.dart';
import '../blocs/connectivity/connectivity_bloc.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityBloc, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityUpdated && state.justReconnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Back online'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.success,
            ),
          );
          context.read<ConnectivityBloc>().add(ClearReconnectedFlag());
        }
      },
      builder: (context, state) {
        final isOffline = state is ConnectivityUpdated && !state.isConnected;
        if (!isOffline) return const SizedBox.shrink();

        return Material(
          color: AppColors.error,
          elevation: 4,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No internet connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

bool isDeviceOnline(BuildContext context) {
  final state = context.read<ConnectivityBloc>().state;
  if (state is ConnectivityUpdated) return state.isConnected;
  return true;
}

void showOfflineSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No internet connection. Please try again when you are back online.'),
      backgroundColor: AppColors.error,
    ),
  );
}

bool ensureOnlineOrNotify(BuildContext context) {
  if (isDeviceOnline(context)) return true;
  showOfflineSnackBar(context);
  return false;
}
