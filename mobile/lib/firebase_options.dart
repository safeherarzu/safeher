import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options per platform (see `firebase.json` / FlutterFire).
/// Android client matches `com.safeher.womensafety` in `google-services.json`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured in this build.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACex1qOjAuRR9t8ubCz6lwgDpNPhhzT1I',
    appId: '1:506037878629:android:daa9745968e41ec3e7eb8c',
    messagingSenderId: '506037878629',
    projectId: 'safeher-66333',
    storageBucket: 'safeher-66333.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACex1qOjAuRR9t8ubCz6lwgDpNPhhzT1I',
    appId: '1:506037878629:ios:2e20eb9537c9ac18e7eb8c',
    messagingSenderId: '506037878629',
    projectId: 'safeher-66333',
    storageBucket: 'safeher-66333.firebasestorage.app',
    iosBundleId: 'com.safeher.womensafety',
  );
}
