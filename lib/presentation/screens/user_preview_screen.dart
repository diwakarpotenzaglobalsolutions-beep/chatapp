import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/theme.dart';
import '../../domain/entities/chat_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/chat_request/chat_request_bloc.dart';
import '../blocs/home/home_bloc.dart';

class UserPreviewScreen extends StatelessWidget {
  final UserEntity peer;

  const UserPreviewScreen({super.key, required this.peer});

  @override
  Widget build(BuildContext context) {
    final homeState = context.read<HomeBloc>().state;
    final currentUserId = homeState is HomeLoaded ? homeState.currentUser.uid : '';

    return BlocProvider(
      create: (_) => sl<ChatRequestBloc>()
        ..add(SubscribeToRequestBetweenUsers(
          user1: currentUserId,
          user2: peer.uid,
        )),
      child: _UserPreviewBody(peer: peer),
    );
  }
}

class _UserPreviewBody extends StatefulWidget {
  final UserEntity peer;

  const _UserPreviewBody({required this.peer});

  @override
  State<_UserPreviewBody> createState() => _UserPreviewBodyState();
}

class _UserPreviewBodyState extends State<_UserPreviewBody> {
  bool _isSending = false;
  bool _isOpeningChat = false;
  bool _isAccepting = false;
  bool _isRejecting = false;

  UserEntity? get _currentUser {
    final homeState = context.read<HomeBloc>().state;
    return homeState is HomeLoaded ? homeState.currentUser : null;
  }

  void _sendRequest(UserEntity currentUser) {
    setState(() => _isSending = true);
    final request = ChatRequestEntity(
      requestId: const Uuid().v4(),
      senderId: currentUser.uid,
      senderName: currentUser.fullName,
      senderImage: currentUser.profilePicture,
      receiverId: widget.peer.uid,
      receiverName: widget.peer.fullName,
      receiverImage: widget.peer.profilePicture,
      status: ChatRequestStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    context.read<ChatRequestBloc>().add(SendChatRequestEvent(request));
  }

  Future<void> _openChat(String currentUserId) async {
    setState(() => _isOpeningChat = true);
    final roomId = await context.read<ChatRequestBloc>().openChatAfterAccept(
      currentUserId,
      widget.peer.uid,
    );
    if (!mounted) return;
    if (roomId != null) {
      context.push(
        '${AppRoutes.chat}/$roomId',
        extra: {
          'peerId': widget.peer.uid,
          'peerName': widget.peer.fullName,
          'peerImage': widget.peer.profilePicture,
        },
      );
    }
    if (mounted) setState(() => _isOpeningChat = false);
  }

  void _acceptRequest(String requestId) {
    setState(() => _isAccepting = true);
    context.read<ChatRequestBloc>().add(AcceptChatRequestEvent(requestId));
  }

  void _rejectRequest(String requestId) {
    setState(() => _isRejecting = true);
    context.read<ChatRequestBloc>().add(RejectChatRequestEvent(requestId));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _currentUser;

    return BlocConsumer<ChatRequestBloc, ChatRequestState>(
      listenWhen: (prev, curr) {
        if (curr is BetweenUsersRequestLoaded && curr.feedbackMessage != null) {
          return true;
        }
        return curr is ChatRequestFailure;
      },
      listener: (context, state) {
        if (state is BetweenUsersRequestLoaded) {
          setState(() {
            _isSending = false;
            _isAccepting = false;
            _isRejecting = false;
          });
          if (state.feedbackMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.feedbackMessage!),
                backgroundColor:
                state.isErrorFeedback ? AppColors.error : AppColors.success,
              ),
            );
            context.read<ChatRequestBloc>().add(ClearChatRequestFeedback());
          }
        } else if (state is ChatRequestFailure) {
          setState(() {
            _isSending = false;
            _isAccepting = false;
            _isRejecting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
          );
        }
      },
      builder: (context, state) {
        ChatRequestEntity? request;
        final isLoading = state is ChatRequestLoading || state is ChatRequestInitial;

        if (state is BetweenUsersRequestLoaded) {
          request = state.request;
        }

        final status = request?.status;
        final isSender = request?.senderId == currentUser?.uid;

        return Scaffold(
          appBar: AppBar(title: const Text('User Profile')),
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surfaceLight,
                    backgroundImage: widget.peer.profilePicture.isNotEmpty
                        ? CachedNetworkImageProvider(widget.peer.profilePicture)
                        : null,
                    child: widget.peer.profilePicture.isEmpty
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.peer.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '@${widget.peer.username}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  if (widget.peer.onlineStatus) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Online',
                          style: TextStyle(color: AppColors.success, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildActionSection(
                    request: request,
                    status: status,
                    isSender: isSender,
                    currentUser: currentUser,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSection({
    required ChatRequestEntity? request,
    required ChatRequestStatus? status,
    required bool isSender,
    required UserEntity? currentUser,
  }) {
    if (currentUser == null) {
      return const CircularProgressIndicator(color: AppColors.primary);
    }

    if (request == null) {
      return ElevatedButton.icon(
        onPressed: _isSending ? null : () => _sendRequest(currentUser),
        icon: _isSending
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.person_add_alt_1),
        label: Text(_isSending ? 'Sending...' : 'Send Chat Request'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    switch (status) {
      case ChatRequestStatus.pending:
        return Column(
          children: [
            _StatusChip(
              label: isSender ? 'Request Pending' : 'Incoming Request',
              color: Colors.orange,
              icon: Icons.hourglass_top_rounded,
            ),
            const SizedBox(height: 16),
            if (!isSender) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAccepting
                          ? null
                          : () => _acceptRequest(request!.requestId),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: _isAccepting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRejecting
                          ? null
                          : () => _rejectRequest(request!.requestId),
                      child: _isRejecting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ] else
              const Text(
                'Waiting for the other user to accept your request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
          ],
        );

      case ChatRequestStatus.accepted:
        return Column(
          children: [
            const _StatusChip(
              label: 'Accepted — You can chat now',
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isOpeningChat ? null : () => _openChat(currentUser.uid),
              icon: _isOpeningChat
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.chat),
              label: Text(_isOpeningChat ? 'Opening...' : 'Open Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        );

      case ChatRequestStatus.rejected:
        return Column(
          spacing: 10,
          children: [
            const _StatusChip(
              label: 'Request Rejected',
              color: AppColors.error,
              icon: Icons.block,
            ),

            Text("Note : Connecting to the Team\n     support@gmail.com",style: TextStyle(fontSize: 15,color: Colors.white),)
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}