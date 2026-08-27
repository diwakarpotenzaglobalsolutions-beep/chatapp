import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/theme.dart';
import '../../../core/models/pending_media_transfer.dart';
import '../../../domain/entities/message_entity.dart';

class MediaTransferOverlay extends StatelessWidget {
  final PendingMediaTransfer transfer;
  final VoidCallback? onRetry;

  const MediaTransferOverlay({
    super.key,
    required this.transfer,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (transfer.isFailed) {
      return _FailedOverlay(
        label: transfer.isUpload ? 'Upload failed' : 'Download failed',
        error: transfer.error,
        onRetry: onRetry,
      );
    }

    final label = transfer.isUpload ? 'Uploading...' : 'Downloading...';
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 35,
              height: 35,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: transfer.progress > 0 ? transfer.progress : null,
                    strokeWidth: 3,
                    color: AppColors.secondary,
                    backgroundColor: Colors.white24,
                  ),
                  Text(
                    '${transfer.progressPercent}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedOverlay extends StatelessWidget {
  final String label;
  final String? error;
  final VoidCallback? onRetry;

  const _FailedOverlay({
    required this.label,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PendingUploadBubble extends StatelessWidget {
  final PendingMediaTransfer transfer;
  final VoidCallback? onRetry;

  const PendingUploadBubble({
    super.key,
    required this.transfer,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(0),
            ),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _previewHeight(transfer.type),
                width: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreview(transfer),
                    MediaTransferOverlay(transfer: transfer, onRetry: onRetry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _previewHeight(MessageType type) {
    switch (type) {
      case MessageType.image:
      case MessageType.video:
        return 150;
      case MessageType.voice:
        return 56;
      case MessageType.file:
        return 72;
      default:
        return 80;
    }
  }

  Widget _buildPreview(PendingMediaTransfer transfer) {
    final path = transfer.localPath;
    switch (transfer.type) {
      case MessageType.image:
        if (path != null && File(path).existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(path), fit: BoxFit.cover),
          );
        }
        return _placeholder(Icons.image, Colors.purple);
      case MessageType.video:
        return _placeholder(Icons.videocam, Colors.red);
      case MessageType.voice:
        return _placeholder(Icons.mic, Colors.orange);
      case MessageType.file:
        return Row(
          children: [
            const Icon(Icons.insert_drive_file_rounded, color: Colors.amber, size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                transfer.fileName ?? 'Document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      default:
        return _placeholder(Icons.attach_file, Colors.grey);
    }
  }

  Widget _placeholder(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, color: Colors.white54, size: 40)),
    );
  }
}
