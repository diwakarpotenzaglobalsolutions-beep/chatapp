import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'placeholder-api-key-web',
    appId: '1:123456789:web:123456789',
    messagingSenderId: '123456789',
    projectId: 'placeholder-project-id',
    authDomain: 'placeholder-project-id.firebaseapp.com',
    storageBucket: 'placeholder-project-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYluNgCiTLgmj7DMHZ9-GxHJvgpKJ4bgo',
    appId: '1:412770401351:android:f927215bff30db881ec562',
    messagingSenderId: '412770401351',
    projectId: 'chatapp-51e5d',
    storageBucket: 'chatapp-51e5d.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDhTSJswmh55e9D4qC_NvBQDbuoXdAi4rs',
    appId: '1:412770401351:ios:4717e55752ee798e1ec562',
    messagingSenderId: '412770401351',
    projectId: 'chatapp-51e5d',
    storageBucket: 'chatapp-51e5d.firebasestorage.app',
    iosBundleId: 'com.app.chatapp',
  );
}
