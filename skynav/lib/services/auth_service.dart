import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'cloud.dart';

class AuthService {
  static bool _gsiInit = false;
  static User? get user => Cloud.ready ? FirebaseAuth.instance.currentUser : null;
  static Stream<User?> get changes => Cloud.ready ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  /// Ortak Google/Gmail girişi. Başarısızsa null döner ve hata metnini [lastError]'a yazar.
  static String? lastError;
  static Future<User?> signInWithGoogle() async {
    lastError = null;
    if (!Cloud.ready) { lastError = 'Bulut yapılandırması (google-services.json) yok; giriş şimdilik kapalı.'; return null; }
    try {
      if (!_gsiInit) { await GoogleSignIn.instance.initialize(); _gsiInit = true; }
      final acc = await GoogleSignIn.instance.authenticate();
      final idToken = acc.authentication.idToken;
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      final res = await FirebaseAuth.instance.signInWithCredential(cred);
      return res.user;
    } catch (e) {
      lastError = 'Giriş yapılamadı: $e';
      return null;
    }
  }

  static Future<void> signOut() async {
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
    if (Cloud.ready) await FirebaseAuth.instance.signOut();
  }
}
