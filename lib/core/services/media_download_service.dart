import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class MediaDownloadService {
  final Set<String> _activeDownloads = {};

  bool isDownloading(String id) => _activeDownloads.contains(id);

  Future<String> downloadFile({
    required String downloadId,
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (_activeDownloads.contains(downloadId)) {
      throw Exception('Download already in progress');
    }

    _activeDownloads.add(downloadId);
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }

      final totalBytes = response.contentLength ?? 0;
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final filePath = p.join(Directory.systemTemp.path, '${downloadId}_$safeName');
      final file = File(filePath);
      final sink = file.openWrite();

      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null) {
          final progress = totalBytes > 0 ? received / totalBytes : 0.5;
          onProgress(progress.clamp(0.01, 0.99));
        }
      }

      await sink.close();
      onProgress?.call(1.0);
      return file.path;
    } finally {
      _activeDownloads.remove(downloadId);
    }
  }
}
