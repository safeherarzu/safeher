import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Minimal FirebaseOptions for Android, generated from `android/app/google-services.json`.
///
/// This avoids relying on `values.xml` being present.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web is not configured in this MVP. Provide a stub if needed later.
      throw UnsupportedError('Web not supported in this build.');
    }

    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACex1qOjAuRR9t8ubCz6lwgDpNPhhzT1I',
    appId: '1:506037878629:android:76fdadf4c461045de7eb8c',
    messagingSenderId: '506037878629',
    projectId: 'safeher-66333',
    storageBucket: 'safeher-66333.firebasestorage.app',
  );
}

