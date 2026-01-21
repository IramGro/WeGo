import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

class AuthController {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // En Web, usamos signInWithPopup directamente con Firebase
        // Esto evita problemas de configuración de GoogleSignIn y 'null check operators'
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        // En Móvil, usamos el flujo nativo con GoogleSignIn package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return; // Usuario canceló

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      // Manejar error de login si es necesario
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}
