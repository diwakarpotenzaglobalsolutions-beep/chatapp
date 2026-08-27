import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signUp({
    required String fullName,
    required String email,
    required String username,
    required String password,
  });

  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Stream<UserModel?> get currentUserStream;
  Future<UserModel?> get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserModel> signUp({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    // 1. Check if username is unique
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception('Username already taken. Please choose another.');
    }

    // 2. Create Auth User
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user == null) {
      throw Exception('User registration failed.');
    }

    final uid = credential.user!.uid;

    // 3. Save details to Firestore
    final userModel = UserModel(
      uid: uid,
      fullName: fullName,
      username: username,
      email: email,
      phoneNumber: '',
      bio: 'Hello! I am using this Chat App.',
      profilePicture: '',
      dateOfBirth: '',
      gender: '',
      country: '',
      city: '',
      onlineStatus: true,
      lastSeen: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(userModel.toJson());

    return userModel;
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user == null) {
      throw Exception('Sign in failed.');
    }

    final uid = credential.user!.uid;
    
    // Get user from Firestore
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found in database.');
    }

    // Update status to online
    final now = DateTime.now();
    await _firestore.collection('users').doc(uid).update({
      'onlineStatus': true,
      'lastSeen': now.toIso8601String(),
    });

    final data = doc.data()!;
    data['onlineStatus'] = true;
    data['lastSeen'] = now.toIso8601String();

    return UserModel.fromJson(data, uid);
  }

  @override
  Future<void> signOut() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'onlineStatus': false,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('User not logged in.');
    }

    // Re-authenticate user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  @override
  Stream<UserModel?> get currentUserStream {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!, user.uid);
    });
  }

  @override
  Future<UserModel?> get currentUser async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!, user.uid);
  }
}
