// Configuración de Firebase del proyecto «sippt-trucha».
//
// Equivale a lo que genera «flutterfire configure». Estos valores identifican
// el proyecto; no son secretos: la seguridad la dan las reglas de Firestore
// (firestore.rules) y Firebase Authentication.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('SIPPT está configurado para Android. Ejecuta «flutterfire configure» para otras plataformas.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBczIaiJIuBYdOfGAISLt5fA6C6iERAWxw',
    appId: '1:178215622306:android:4c43c3edcd0dafbe0ce9fb',
    messagingSenderId: '178215622306',
    projectId: 'sippt-trucha',
    storageBucket: 'sippt-trucha.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBczIaiJIuBYdOfGAISLt5fA6C6iERAWxw',
    appId: '1:178215622306:web:460430499932a0c50ce9fb',
    messagingSenderId: '178215622306',
    projectId: 'sippt-trucha',
    authDomain: 'sippt-trucha.firebaseapp.com',
    storageBucket: 'sippt-trucha.firebasestorage.app',
  );
}
