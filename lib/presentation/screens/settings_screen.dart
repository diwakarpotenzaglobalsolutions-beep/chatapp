import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/theme.dart';
import '../../routes/router.dart';
import '../../domain/entities/subscription_entity.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/subscription/subscription_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state;
    final currentUser = homeState is HomeLoaded ? homeState.currentUser : null;

    return BlocListener<SettingsBloc, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLogoutSuccess) {
          context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        backgroundColor: context.cardColor,
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: currentUser == null
              ? const Center(child: Text('User profile not loaded'))
              : ListView(
                  children: [
                    InkWell(
                      onTap: () => context.push(AppRoutes.editProfile),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.surfaceLight,
                              backgroundImage: currentUser.profilePicture.isNotEmpty
                                  ? CachedNetworkImageProvider(currentUser.profilePicture)
                                  : null,
                              child: currentUser.profilePicture.isEmpty
                                  ? const Icon(Icons.person, size: 36, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser.fullName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: context.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${currentUser.username}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.qr_code_2, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: context.borderColor),
                    const SizedBox(height: 8),

                    // Options Group
                    Card(
                      color: context.surfaceColor,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                            title: const Text('View Profile'),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            onTap: () => context.push('${AppRoutes.profile}/${currentUser.uid}'),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          ListTile(
                            leading: const Icon(Icons.history_rounded, color: AppColors.textSecondary),
                            title: const Text('Call History'),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            onTap: () => context.push(AppRoutes.callHistory),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          ListTile(
                            leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.secondary),
                            title:   Text('Subscription'),
                            subtitle: BlocBuilder<SubscriptionBloc, SubscriptionState>(
                              builder: (context, state) {
                                if (state is SubscriptionLoaded) {
                                  if (state.isTrialActive) {
                                    return Text('Trial • ${state.daysRemaining} days left');
                                  }
                                  if (state.subscription.status == SubscriptionStatus.active) {

                                    return   Row(
                                      spacing: 3,
                                      children: [
                                        Text('Premium'),
                                        Text("Expired ${DateFormat('d MMM h:mm a').format(state.subscription.subscriptionEndDate??DateTime.now())}")
                                      ],
                                    );
                                  }
                                  return const Text('Manage or renew subscription');
                                }
                                return const Text('View subscription status');
                              },
                            ),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            onTap: () => context.push(AppRoutes.subscription),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          ListTile(
                            leading: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                            title: const Text('Change Password'),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            onTap: () => context.push(AppRoutes.changePassword),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preferences Card
                    Card(
                      child: BlocBuilder<SettingsBloc, SettingsState>(
                        builder: (context, state) {
                          bool isDark = true;
                          if (state is SettingsLoaded) {
                            isDark = state.isDarkMode;
                          }
                          return Column(
                            children: [
                              SwitchListTile(
                                secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.textSecondary),
                                title: const Text('Dark Mode'),
                                activeColor: AppColors.primaryLight,
                                value: isDark,
                                onChanged: (val) {
                                  context.read<SettingsBloc>().add(ToggleDarkMode(val));
                                },
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              ListTile(
                                leading: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
                                title: const Text('Notification Settings'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                onTap: () {
                                  // Mock notification settings dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Notifications configuration is enabled by default.')),
                                  );
                                },
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              ListTile(
                                leading: const Icon(Icons.block_outlined, color: AppColors.textSecondary),
                                title: const Text('Blocked Users'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                onTap: () => context.push(AppRoutes.blockedUsers),
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              ListTile(
                                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
                                title: const Text('Privacy Settings'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Your chat end-to-end signals are secure.')),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button Card
                    Card(
                      color: AppColors.error.withOpacity(0.1),
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                        title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        onTap: () {
                          // Update online status offline inside AuthBloc then log out
                          context.read<AuthBloc>().add(LogOutRequested());
                          context.go(AppRoutes.login);
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
