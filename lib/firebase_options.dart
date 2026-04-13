import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyASMu8c8YY3JyghTOOXJi0GCFofFvqC3s8',
    appId: '1:204547887344:web:f04304afafba876e0cb235',
    messagingSenderId: '204547887344',
    projectId: 'arise-f494a',
    authDomain: 'arise-f494a.firebaseapp.com',
    storageBucket: 'arise-f494a.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTeLoaghFjnkIVeTDiV_rOi4f1aPrkwXo',
    appId: '1:204547887344:android:cc961ca3670adb110cb235',
    messagingSenderId: '204547887344',
    projectId: 'arise-f494a',
    storageBucket: 'arise-f494a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBKRylOcd-887-RY4r1681iWQKh8nsudFQ',
    appId: '1:204547887344:ios:8339eb7e339959c00cb235',
    messagingSenderId: '204547887344',
    projectId: 'arise-f494a',
    storageBucket: 'arise-f494a.firebasestorage.app',
    iosBundleId: 'com.example.ariseTest',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBKRylOcd-887-RY4r1681iWQKh8nsudFQ',
    appId: '1:204547887344:ios:8339eb7e339959c00cb235',
    messagingSenderId: '204547887344',
    projectId: 'arise-f494a',
    storageBucket: 'arise-f494a.firebasestorage.app',
    iosBundleId: 'com.example.ariseTest',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyASMu8c8YY3JyghTOOXJi0GCFofFvqC3s8',
    appId: '1:204547887344:web:6ba75c3b4158c7b30cb235',
    messagingSenderId: '204547887344',
    projectId: 'arise-f494a',
    authDomain: 'arise-f494a.firebaseapp.com',
    storageBucket: 'arise-f494a.firebasestorage.app',
  );
}
