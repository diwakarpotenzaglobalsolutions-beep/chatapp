import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/storage_service.dart';
import '../models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getUserProfile(String uid);
  Future<void> updateUserProfile(UserModel user);
  Future<String> uploadProfilePicture(String uid, String filePath);
  Future<void> removeProfilePicture(String uid);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService;

  ProfileRemoteDataSourceImpl(this._storageService);

  @override
  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('User profile not found');
    }
    return UserModel.fromJson(doc.data()!, uid);
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toJson(), SetOptions(merge: true));
  }

  @override
  Future<String> uploadProfilePicture(String uid, String filePath) async {
    final downloadUrl = await _storageService.uploadFile(
      filePath: filePath,
      folder: 'profile_images',
      customFileName: 'profile_$uid.jpg',
    );
    await _firestore.collection('users').doc(uid).update({
      'profilePicture': downloadUrl,
    });
    return downloadUrl;
  }

  @override
  Future<void> removeProfilePicture(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final oldUrl = doc.data()!['profilePicture'] as String?;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await _storageService.deleteFile(oldUrl);
        } catch (_) {}
      }
    }
    await _firestore.collection('users').doc(uid).update({
      'profilePicture': '',
    });
  }
}
