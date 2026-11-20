import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de configuración de Firebase para FreelancerHub generadas a partir de google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFH8GRuz-RJP4W8z3R-B6XMVNBFCBIpAs',
    appId: '1:417210536628:android:d18055898788acb00b3de1',
    messagingSenderId: '417210536628',
    projectId: 'freelancer-92fe8',
    storageBucket: 'freelancer-92fe8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCFH8GRuz-RJP4W8z3R-B6XMVNBFCBIpAs',
    appId: '1:417210536628:ios:d18055898788acb00b3de1',
    messagingSenderId: '417210536628',
    projectId: 'freelancer-92fe8',
    storageBucket: 'freelancer-92fe8.firebasestorage.app',
  );
}
