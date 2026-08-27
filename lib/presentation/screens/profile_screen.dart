import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/block/block_bloc.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/profile/profile_bloc.dart';
import '../widgets/message_options_sheet.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final homeState = context.read<HomeBloc>().state;
    final currentUserId = homeState is HomeLoaded ? homeState.currentUser.uid : '';
    final isMe = uid == currentUserId;

    if (!isMe && currentUserId.isNotEmpty) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => sl<ProfileBloc>()..add(LoadProfile(uid)),
          ),
          BlocProvider(
            create: (_) => sl<BlockBloc>()
              ..add(WatchBlockStatusRequested(
                currentUserId: currentUserId,
                peerUserId: uid,
              )),
          ),
        ],
        child: _ProfileScaffold(
          uid: uid,
          isMe: isMe,
          currentUserId: currentUserId,
        ),
      );
    }

    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(LoadProfile(uid)),
      child: _ProfileScaffold(
        uid: uid,
        isMe: isMe,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _ProfileScaffold extends StatelessWidget {
  final String uid;
  final bool isMe;
  final String currentUserId;

  const _ProfileScaffold({
    required this.uid,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.darkBackgroundGradient,
          ),
          child: BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoading) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (state is ProfileLoaded) {
                final user = state.user;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: user.profilePicture.isNotEmpty
                              ? CachedNetworkImageProvider(user.profilePicture)
                              : null,
                          child: user.profilePicture.isEmpty
                              ? const Icon(Icons.person, size: 60, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(fontSize: 16, color: AppColors.secondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('About', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                user.bio.isNotEmpty ? user.bio : 'No bio set yet.',
                                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            children: [
                              _buildProfileRow(Icons.email_outlined, 'Email', user.email),
                              const Divider(color: Colors.white12, height: 1),
                              _buildProfileRow(Icons.phone_outlined, 'Phone', user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not set'),
                              const Divider(color: Colors.white12, height: 1),
                              _buildProfileRow(Icons.cake_outlined, 'Date of Birth', user.dateOfBirth.isNotEmpty ? user.dateOfBirth : 'Not set'),
                              const Divider(color: Colors.white12, height: 1),
                              _buildProfileRow(Icons.face_outlined, 'Gender', user.gender.isNotEmpty ? user.gender : 'Not set'),
                              const Divider(color: Colors.white12, height: 1),
                              _buildProfileRow(Icons.location_on_outlined, 'Location', _formatLocation(user.city, user.country)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isMe)
                        ElevatedButton.icon(
                          onPressed: () => context.push(AppRoutes.editProfile),
                          icon: const Icon(Icons.edit),
                          label: const Text('EDIT PROFILE'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        )
                      else ...[
                        BlocBuilder<BlockBloc, BlockState>(
                          builder: (context, blockState) {
                            final isBlocked = blockState is BlockStatusState &&
                                blockState.status.blockedByMe;

                            return Column(
                              children: [
                                BlocListener<ChatBloc, ChatState>(
                                  listener: (context, chatState) {
                                    if (chatState is ChatRoomLoaded) {
                                      context.push(
                                        '${AppRoutes.chat}/${chatState.roomId}',
                                        extra: {
                                          'peerId': user.uid,
                                          'peerName': user.fullName,
                                          'peerImage': user.profilePicture,
                                        },
                                      );
                                    }
                                  },
                                  child: ElevatedButton.icon(
                                    onPressed: isBlocked
                                        ? null
                                        : () {
                                            context.read<ChatBloc>().add(
                                                  EnterChatRoom(
                                                    uid1: currentUserId,
                                                    uid2: user.uid,
                                                  ),
                                                );
                                          },
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text('MESSAGE'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    if (isBlocked) {
                                      final confirmed = await confirmUnblockUser(
                                        context,
                                        user.fullName,
                                      );
                                      if (confirmed && context.mounted) {
                                        context.read<BlockBloc>().add(
                                              UnblockUserRequested(
                                                blockerId: currentUserId,
                                                blockedUserId: user.uid,
                                              ),
                                            );
                                      }
                                    } else {
                                      final confirmed = await confirmBlockUser(
                                        context,
                                        user.fullName,
                                      );
                                      if (confirmed && context.mounted) {
                                        context.read<BlockBloc>().add(
                                              BlockUserRequested(
                                                blockerId: currentUserId,
                                                blockedUserId: user.uid,
                                                blockedUserName: user.fullName,
                                                blockedUserImage: user.profilePicture,
                                              ),
                                            );
                                      }
                                    }
                                  },
                                  icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                                  label: Text(isBlocked ? 'UNBLOCK USER' : 'BLOCK USER'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    foregroundColor: isBlocked ? AppColors.primary : AppColors.error,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }
              if (state is ProfileFailure) {
                return Center(child: Text('Failed to load profile: ${state.error}'));
              }
              return Container();
            },
          ),
        ),
      );

    if (isMe) return scaffold;

    return BlocListener<BlockBloc, BlockState>(
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
      child: scaffold,
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLocation(String city, String country) {
    if (city.isEmpty && country.isEmpty) return 'Not set';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }
}
