import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/theme.dart';
import '../../core/utils/date_time_formatter.dart';
import '../../domain/entities/call_history_entity.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/call/call_bloc.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        context.read<CallBloc>().add(SubscribeToCallHistory(authState.user.uid));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: Container(
        decoration: BoxDecoration(gradient: context.scaffoldGradient),
        child: BlocBuilder<CallBloc, CallState>(
          builder: (context, state) {
            if (state.isLoadingHistory && state.calls.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state.historyError != null && state.calls.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.historyError!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (authState is Authenticated) {
                          context
                              .read<CallBloc>()
                              .add(SubscribeToCallHistory(authState.user.uid));
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state.calls.isEmpty) {
              return Center(
                child: Text(
                  'No call history yet',
                  style: TextStyle(color: context.textSecondaryColor),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.calls.length,
              itemBuilder: (context, index) {
                final call = state.calls[index];
                return _CallHistoryTile(
                  call: call,
                  currentUserId: currentUserId,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CallHistoryTile extends StatelessWidget {
  final CallHistoryEntity call;
  final String currentUserId;

  const _CallHistoryTile({
    required this.call,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = call.isOutgoingFor(currentUserId);
    final isMissed = call.isMissedFor(currentUserId);
    final peerName = call.peerNameFor(currentUserId).isNotEmpty
        ? call.peerNameFor(currentUserId)
        : 'Unknown';
    final peerImage = call.peerImageFor(currentUserId);

    IconData directionIcon;
    Color directionColor;
    String subtitle;

    if (isMissed) {
      directionIcon = Icons.phone_missed;
      directionColor = AppColors.error;
      subtitle = 'Missed ${call.callType.name} call';
    } else if (isOutgoing) {
      directionIcon = Icons.call_made;
      directionColor = AppColors.primaryLight;
      subtitle = 'Outgoing ${call.callType.name} call';
    } else {
      directionIcon = Icons.call_received;
      directionColor = AppColors.success;
      subtitle = 'Incoming ${call.callType.name} call';
    }

    if (call.status == CallStatus.rejected) {
      subtitle = isOutgoing ? 'Call declined' : 'Declined call';
    } else if (call.status == CallStatus.busy) {
      subtitle = 'User busy';
    } else if (call.status == CallStatus.completed && call.durationSeconds > 0) {
      subtitle = 'Duration: ${DateTimeFormatter.formatDuration(call.durationSeconds)}';
    } else if (call.status == CallStatus.timeout) {
      subtitle = isOutgoing ? 'No answer' : 'Missed call';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: context.cardColor,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: context.surfaceColor,
              backgroundImage: peerImage.isNotEmpty
                  ? CachedNetworkImageProvider(peerImage)
                  : null,
              child: peerImage.isEmpty
                  ? Icon(Icons.person, color: context.textMutedColor)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Icon(
                call.callType == CallType.video ? Icons.videocam : Icons.call,
                size: 14,
                color: context.textMutedColor,
              ),
            ),
          ],
        ),
        title: Text(
          peerName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: context.textSecondaryColor)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(directionIcon, color: directionColor, size: 18),
            const SizedBox(height: 4),
            Text(
              DateTimeFormatter.formatCallHistoryDateTime(call.startedAt),
              style: TextStyle(fontSize: 11, color: context.textMutedColor),
            ),
          ],
        ),
      ),
    );
  }
}
