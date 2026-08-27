import 'package:flutter/material.dart';

import '../../core/constants/theme.dart';
import '../../domain/entities/message_entity.dart';

Future<void> showMessageOptionsSheet({
  required BuildContext context,
  required MessageEntity message,
  required bool isMe,
  required VoidCallback onDeleteForMe,
  VoidCallback? onDeleteForEveryone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(
                  context: context,
                  title: 'Delete for me?',
                  message: 'This message will be removed from your chat only.',
                  onConfirm: onDeleteForMe,
                );
              },
            ),
            if (isMe && onDeleteForEveryone != null && !message.isDeletedForEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                title: const Text('Delete for everyone'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(
                    context: context,
                    title: 'Delete for everyone?',
                    message: 'This message will be replaced with a deletion notice for all participants.',
                    onConfirm: onDeleteForEveryone,
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmDelete({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    onConfirm();
  }
}

Future<bool> confirmBlockUser(BuildContext context, String userName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          'Block $userName? They will not be able to message, call, or send chat requests to you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Block'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> confirmUnblockUser(BuildContext context, String userName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Unblock user?'),
        content: Text('Unblock $userName? Messaging and calls will work normally again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
