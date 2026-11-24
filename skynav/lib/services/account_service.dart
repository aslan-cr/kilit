import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';
import 'cloud.dart';
import 'store.dart';

/// Hesap silme (Google Play hesap silme şartı): Ayarlar > Gizlilik & izinler > Hesabımı ve verilerimi sil.
///
/// Silinenler: users/{uid} belgesi ve alt koleksiyonları (apps: bulut yedeği ve uygulama kaydı, grants: Pro hakları,
/// credits: davet kredileri) ve Firebase Auth kullanıcısı. Kötüye kullanımı önlemek için devices (cihaz özeti) ve
/// invites (kullanılmış davet kodları) saklanır; gizlilik metninde yazılı. Telefondaki yerel veriler (kayıtlı yerler vb.)
/// silinmez; yalnızca hesapla ilgili yerel izler temizlenir.
///
/// firestore.rules: users/{uid}, grants ve credits için sahibine delete izni gerekir (3.2'de eklendi; konsolda yayınlanmalı).
class AccountService {
  /// Başarılıysa null, değilse kullanıcıya gösterilecek hata metni.
  static Future<String?> deleteAccount() async {
    final u = AuthService.user;
    if (!Cloud.ready || u == null) return 'Giriş yapılmamış.';
    // Firebase hesap silmek için yakın tarihli giriş ister: önce doğrula, sonra sil (yarım kalmasın)
    final re = await AuthService.reauthenticate();
    if (re != null) return re;
    final me = FirebaseFirestore.instance.collection('users').doc(u.uid);
    try {
      for (final c in const ['apps', 'grants', 'credits']) {
        final q = await me.collection(c).get();
        for (var i = 0; i < q.docs.length; i += 400) {
          final b = FirebaseFirestore.instance.batch();
          for (final d in q.docs.skip(i).take(400)) { b.delete(d.reference); }
          await b.commit();
        }
      }
      await me.delete();
      await u.delete();
    } on FirebaseException catch (e) {
      debugPrint('hesap silme: $e');
      return e.code == 'permission-denied'
          ? 'Silme şu an yapılamadı (sunucu izni). Lütfen daha sonra tekrar dene.'
          : 'Silinemedi: ${e.message ?? e.code}. İnternet bağlantını kontrol edip tekrar dene.';
    } catch (e) {
      debugPrint('hesap silme: $e');
      return 'Silinemedi. İnternet bağlantını kontrol edip tekrar dene.';
    }
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
    // Hesapla ilgili yerel izler (Pro önbelleği, bulut eşitleme damgası, davet kodu)
    for (final k in const ['cloud_rev', 'cloud_backup_at', 'cloud_backup_off', 'pro_until', 'pro_life', 'dev_account', 'discount_until', 'launch_checked', 'pending_code']) {
      try { await Store.prefs.delete(k); } catch (_) {}
    }
    return null;
  }
}
