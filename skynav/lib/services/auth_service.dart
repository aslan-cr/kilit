import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'cloud.dart';

class AuthService {
  /// Firebase web istemcisi (google-services.json, client_type 3): Firebase'e giriş jetonu bunun için alınır.
  static const _webClientId = '187082258469-jbhfj79cjp7372aohesqg5585ufkm74s.apps.googleusercontent.com';
  static bool _gsiInit = false;
  static User? get user => Cloud.ready ? FirebaseAuth.instance.currentUser : null;
  static Stream<User?> get changes => Cloud.ready ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  /// Ortak Google/Gmail girişi. Başarısızsa null döner ve hata metnini [lastError]'a yazar.
  static String? lastError;
  static Future<User?> signInWithGoogle() async {
    lastError = null;
    if (!Cloud.ready) { lastError = 'Bulut yapılandırması (google-services.json) yok; giriş şimdilik kapalı.'; return null; }
    try {
      if (!_gsiInit) { await GoogleSignIn.instance.initialize(serverClientId: _webClientId); _gsiInit = true; }
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

  /// Hassas işlemlerden (hesap silme) önce: aynı Google hesabıyla yeniden doğrular. Başarılıysa null, değilse hata metni.
  static Future<String?> reauthenticate() async {
    final u = user;
    if (u == null) return 'Giriş yapılmamış.';
    try {
      if (!_gsiInit) { await GoogleSignIn.instance.initialize(serverClientId: _webClientId); _gsiInit = true; }
      final acc = await GoogleSignIn.instance.authenticate();
      await u.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: acc.authentication.idToken));
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'user-mismatch' ? 'Giriş yaptığın Gmail hesabını seçmelisin.' : 'Doğrulanamadı: ${e.message ?? e.code}';
    } catch (e) {
      return 'Doğrulama iptal edildi.';
    }
  }

  static Future<void> signOut() async {
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
    if (Cloud.ready) await FirebaseAuth.instance.signOut();
  }
}
