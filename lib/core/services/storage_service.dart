import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required String filePath,
    required String folder,
    String? customFileName,
    Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileName = customFileName ?? '${DateTime.now().millisecondsSinceEpoch}_${p.basename(filePath)}';
    final ref = _storage.ref().child('$folder/$fileName');

    final uploadTask = ref.putFile(file);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> deleteFile(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
