import '../../domain/entities/message_entity.dart';

enum MediaTransferPhase {
  uploading,
  uploadFailed,
  downloading,
  downloadFailed,
}

class PendingMediaTransfer {
  final String messageId;
  final String? localPath;
  final String? remoteUrl;
  final MessageType type;
  final String? fileName;
  final String? fileSize;
  final double progress;
  final MediaTransferPhase phase;
  final String? error;
  final DateTime timestamp;

  const PendingMediaTransfer({
    required this.messageId,
    this.localPath,
    this.remoteUrl,
    required this.type,
    this.fileName,
    this.fileSize,
    this.progress = 0,
    required this.phase,
    this.error,
    required this.timestamp,
  });

  PendingMediaTransfer copyWith({
    String? localPath,
    String? remoteUrl,
    double? progress,
    MediaTransferPhase? phase,
    String? error,
  }) {
    return PendingMediaTransfer(
      messageId: messageId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      progress: progress ?? this.progress,
      phase: phase ?? this.phase,
      error: error ?? this.error,
      timestamp: timestamp,
    );
  }

  int get progressPercent => (progress * 100).clamp(1, 100).round();

  bool get isUpload =>
      phase == MediaTransferPhase.uploading || phase == MediaTransferPhase.uploadFailed;

  bool get isDownload =>
      phase == MediaTransferPhase.downloading || phase == MediaTransferPhase.downloadFailed;

  bool get isFailed =>
      phase == MediaTransferPhase.uploadFailed || phase == MediaTransferPhase.downloadFailed;
}
