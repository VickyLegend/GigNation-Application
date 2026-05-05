import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    serverClientId: '992691882325-635avr6q3h02ov8uf8qngo9no23hpdif.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  static Future<String?> signIn() async {
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign-in cancelled';

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) return 'Could not get Google ID token';

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign-in failed. Please try again.';
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
  }
}