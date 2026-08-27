import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/theme.dart';
import '../../core/models/pending_media_transfer.dart';
import '../../core/services/media_download_service.dart';
import '../../core/services/storage_service.dart';
import '../../domain/entities/message_entity.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/audio/audio_bloc.dart';

mixin ChatMediaTransferMixin<T extends StatefulWidget> on State<T> {
  final Map<String, PendingMediaTransfer> pendingTransfers = {};
  final Set<String> _activeUploadPaths = {};

  StorageService get _storageService => sl<StorageService>();
  MediaDownloadService get _downloadService => sl<MediaDownloadService>();
  Uuid get _uuid => const Uuid();

  Future<void> uploadMediaFile({
    required String path,
    required MessageType type,
    required void Function({
      required String messageId,
      required String mediaUrl,
      String? fileName,
      String? fileSize,
    }) onSuccess,
    String? customFileName,
    String? fileSize,
  }) async {
    if (_activeUploadPaths.contains(path)) return;
    _activeUploadPaths.add(path);

    final messageId = _uuid.v4();
    final fileName = customFileName ?? p.basename(path);

    setState(() {
      pendingTransfers[messageId] = PendingMediaTransfer(
        messageId: messageId,
        localPath: path,
        type: type,
        fileName: fileName,
        fileSize: fileSize,
        progress: 0.01,
        phase: MediaTransferPhase.uploading,
        timestamp: DateTime.now(),
      );
    });

    var folder = 'chat_documents';
    if (type == MessageType.image) folder = 'chat_images';
    if (type == MessageType.video) folder = 'chat_videos';
    if (type == MessageType.voice) folder = 'chat_audio';

    try {
      final downloadUrl = await _storageService.uploadFile(
        filePath: path,
        folder: folder,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            final current = pendingTransfers[messageId];
            if (current != null) {
              pendingTransfers[messageId] = current.copyWith(
                progress: progress.clamp(0.01, 1.0),
              );
            }
          });
        },
      );

      if (!mounted) return;
      setState(() => pendingTransfers.remove(messageId));
      onSuccess(
        messageId: messageId,
        mediaUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pendingTransfers[messageId] = pendingTransfers[messageId]!.copyWith(
          phase: MediaTransferPhase.uploadFailed,
          error: e.toString().replaceAll('Exception: ', ''),
        );
      });
    } finally {
      _activeUploadPaths.remove(path);
    }
  }

  void retryUpload({
    required String messageId,
    required void Function({
      required String messageId,
      required String mediaUrl,
      String? fileName,
      String? fileSize,
    }) onSuccess,
  }) {
    final transfer = pendingTransfers[messageId];
    if (transfer == null || transfer.localPath == null) return;

    pendingTransfers.remove(messageId);
    uploadMediaFile(
      path: transfer.localPath!,
      type: transfer.type,
      onSuccess: onSuccess,
      customFileName: transfer.fileName,
      fileSize: transfer.fileSize,
    );
  }

  Future<void> handleMediaTap(MessageEntity message) async {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;

    if (message.type == MessageType.file) {
      await openDocument(docURL: url);
      return;
    }

    await downloadMediaMessage(message);
  }

  Future<void> downloadMediaMessage(MessageEntity message) async {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;
    if (_downloadService.isDownloading(message.messageId)) return;
    if (message.type == MessageType.location || message.type == MessageType.text) return;

    setState(() {
      pendingTransfers[message.messageId] = PendingMediaTransfer(
        messageId: message.messageId,
        remoteUrl: url,
        type: message.type,
        fileName: message.fileName ?? p.basename(Uri.parse(url).path),
        progress: 0.01,
        phase: MediaTransferPhase.downloading,
        timestamp: DateTime.now(),
      );
    });

    try {
      final localPath = await _downloadService.downloadFile(
        downloadId: message.messageId,
        url: url,
        fileName: message.fileName ?? p.basename(Uri.parse(url).path),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            final current = pendingTransfers[message.messageId];
            if (current != null) {
              pendingTransfers[message.messageId] = current.copyWith(
                progress: progress.clamp(0.01, 1.0),
              );
            }
          });
        },
      );

      if (!mounted) return;
      setState(() => pendingTransfers.remove(message.messageId));
      _openDownloadedMedia(message, localPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pendingTransfers[message.messageId] = pendingTransfers[message.messageId]!.copyWith(
          phase: MediaTransferPhase.downloadFailed,
          error: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  void retryDownload(MessageEntity message) {
    pendingTransfers.remove(message.messageId);
    downloadMediaMessage(message);
  }

  Future<void> openDocument({required String docURL}) async {
    try {
      final uri = Uri.parse(docURL);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open document\n$e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openDownloadedMedia(MessageEntity message, String localPath) {
    switch (message.type) {
      case MessageType.image:
        context.push(
          AppRoutes.imageViewer,
          extra: {'url': localPath, 'tag': message.messageId},
        );
        break;
      case MessageType.video:
        context.push(AppRoutes.videoPlayer, extra: {'url': localPath});
        break;
      case MessageType.voice:
        context.read<AudioBloc>().add(PlayAudioRequested(localPath));
        break;
      default:
        break;
    }
  }

  List<PendingMediaTransfer> get pendingUploads =>
      pendingTransfers.values.where((t) => t.isUpload).toList();
}
