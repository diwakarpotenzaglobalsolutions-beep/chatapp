import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/theme.dart';
import '../blocs/call/call_bloc.dart';

class ChatCallButtons extends StatelessWidget {
  final bool enabled;
  final String callerId;
  final String callerName;
  final String callerImage;
  final String calleeId;
  final String calleeName;
  final String calleeImage;
  final String? chatRoomId;

  const ChatCallButtons({
    super.key,
    required this.enabled,
    required this.callerId,
    required this.callerName,
    this.callerImage = '',
    required this.calleeId,
    required this.calleeName,
    this.calleeImage = '',
    this.chatRoomId,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return BlocListener<CallBloc, CallState>(
      listener: (context, state) {
        if (state.callActionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.callActionError!),
              backgroundColor: AppColors.error,
            ),
          );
          context.read<CallBloc>().add(ClearCallFeedback());
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call, color: AppColors.success),
            tooltip: 'Audio call',
            onPressed: stateGuard(context, () {
              context.read<CallBloc>().add(
                    StartAudioCallRequested(
                      callerId: callerId,
                      callerName: callerName,
                      callerImage: callerImage,
                      calleeId: calleeId,
                      calleeName: calleeName,
                      calleeImage: calleeImage,
                      chatRoomId: chatRoomId,
                    ),
                  );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: AppColors.primaryLight),
            tooltip: 'Video call',
            onPressed: stateGuard(context, () {
              context.read<CallBloc>().add(
                    StartVideoCallRequested(
                      callerId: callerId,
                      callerName: callerName,
                      callerImage: callerImage,
                      calleeId: calleeId,
                      calleeName: calleeName,
                      calleeImage: calleeImage,
                      chatRoomId: chatRoomId,
                    ),
                  );
            }),
          ),
        ],
      ),
    );
  }

  VoidCallback? stateGuard(BuildContext context, VoidCallback action) {
    final state = context.read<CallBloc>().state;
    if (state.isCallActionInProgress) return null;
    return action;
  }
}
