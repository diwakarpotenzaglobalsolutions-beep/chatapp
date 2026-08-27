import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/theme.dart';
import '../../domain/entities/chat_request_entity.dart';
import '../../injection/injection_container.dart';
import '../blocs/chat_request/chat_request_bloc.dart';
import '../blocs/home/home_bloc.dart';

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final homeState = context.read<HomeBloc>().state;
    final currentUserId = homeState is HomeLoaded ? homeState.currentUser.uid : '';

    return BlocProvider(
      create: (_) => sl<ChatRequestBloc>()
        ..add(SubscribeToIncomingRequests(currentUserId)),
      child: const _ChatRequestsBody(),
    );
  }
}

class _ChatRequestsBody extends StatelessWidget {
  const _ChatRequestsBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatRequestBloc, ChatRequestState>(
      listenWhen: (prev, curr) =>
      curr is IncomingRequestsLoaded && curr.feedbackMessage != null,
      listener: (context, state) {
        if (state is IncomingRequestsLoaded && state.feedbackMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.feedbackMessage!),
              backgroundColor:
              state.isErrorFeedback ? AppColors.error : AppColors.success,
            ),
          );
          context.read<ChatRequestBloc>().add(ClearChatRequestFeedback());
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Chat Requests')),
          body: Container(
            decoration: BoxDecoration(gradient: context.scaffoldGradient),
            child: _buildBody(state, context),
          ),
        );
      },
    );
  }

  Widget _buildBody(ChatRequestState state, BuildContext context) {
    if (state is ChatRequestLoading || state is ChatRequestInitial) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state is IncomingRequestsLoaded) {
      final pending = state.requests
          .where((r) => r.status == ChatRequestStatus.pending)
          .toList();

      if (pending.isEmpty) {
        return const Center(
          child: Text(
            'No pending requests',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final req = pending[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: req.senderImage.isNotEmpty
                    ? CachedNetworkImageProvider(req.senderImage)
                    : null,
                child: req.senderImage.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Wants to chat with you'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                    onPressed: () => context.read<ChatRequestBloc>().add(
                      AcceptChatRequestEvent(req.requestId),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: AppColors.error),
                    onPressed: () => context.read<ChatRequestBloc>().add(
                      RejectChatRequestEvent(req.requestId),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}