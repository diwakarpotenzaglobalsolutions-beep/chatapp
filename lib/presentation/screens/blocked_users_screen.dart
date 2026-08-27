import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/theme.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/block/block_bloc.dart';
import '../widgets/message_options_sheet.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';

    return BlocProvider(
      create: (_) => sl<BlockBloc>()..add(SubscribeToBlockedUsers(currentUserId)),
      child: BlocConsumer<BlockBloc, BlockState>(
        listener: (context, state) {
          if (state is BlockStatusState) {
            if (state.actionMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.actionMessage!)),
              );
              context.read<BlockBloc>().add(ClearBlockFeedback());
            } else if (state.actionError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: AppColors.error,
                ),
              );
              context.read<BlockBloc>().add(ClearBlockFeedback());
            }
          }
        },
        builder: (context, state) {
          final blockedUsers = state is BlockStatusState ? state.blockedUsers : <BlockedUserEntity>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Blocked Users'),
            ),
            body: Container(
              decoration: BoxDecoration(gradient: context.scaffoldGradient),
              child: blockedUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'No blocked users',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: blockedUsers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = blockedUsers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.surfaceLight,
                                  backgroundImage: user.blockedUserImage.isNotEmpty
                                      ? CachedNetworkImageProvider(user.blockedUserImage)
                                      : null,
                                  child: user.blockedUserImage.isEmpty
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                                title: Text(user.blockedUserName),
                                subtitle: const Text('Tap to view profile'),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final confirmed = await confirmUnblockUser(
                                      context,
                                      user.blockedUserName,
                                    );
                                    if (confirmed && context.mounted) {
                                      context.read<BlockBloc>().add(
                                            UnblockUserRequested(
                                              blockerId: currentUserId,
                                              blockedUserId: user.blockedUserId,
                                            ),
                                          );
                                    }
                                  },
                                  child: const Text('Unblock'),
                                ),
                                onTap: () => context.push(
                                  '${AppRoutes.profile}/${user.blockedUserId}',
                                ),
                              ),
                            );
                          },
                        ),
            ),
          );
        },
      ),
    );
  }
}
