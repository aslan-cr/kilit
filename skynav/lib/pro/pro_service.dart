import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/cloud.dart';
import '../services/store.dart';

/// Pro hakları. Kaynaklar: geliştirici modu, ömür boyu, süreli hibeler (lansman, davet, ekosistem, satın alma).
class ProState {
  final bool dev, lifetime;
  final DateTime? until;
  const ProState({this.dev = false, this.lifetime = false, this.until});
  bool get isPro => dev || lifetime || (until != null && until!.isAfter(DateTime.now()));
  String get label => dev ? 'Geliştirici' : lifetime ? 'Ömür Boyu Pro' : isPro ? 'Pro · ${until!.difference(DateTime.now()).inDays + 1} gün' : 'Ücretsiz';
}

class DiscountState {
  final int usedDays;          // son 7 günde... toplam aktif gün
  final bool usageOk, friendOk, active;
  final DateTime? until;
  const DiscountState({this.usedDays = 0, this.usageOk = false, this.friendOk = false, this.active = false, this.until});
  Duration get remaining => until == null ? Duration.zero : until!.difference(DateTime.now());
}

class ProService extends ChangeNotifier {
  static final ProService I = ProService._();
  ProService._();

  ProState state = const ProState();
  DiscountState discount = const DiscountState();
  String? myInviteCode;
  String? lastMessage; // kutlama / bilgi bildirimi (UI gösterir)
  String? _deviceId;

  static const _devKey = 'dev_mode';
  bool get devMode => Store.prefs.get(_devKey, defaultValue: false) as bool;
  Future<void> setDevMode(bool v) async { await Store.put(_devKey, v); await refresh(); }

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => AuthService.user?.uid;

  Future<String> deviceHash() async {
    if (_deviceId != null) return _deviceId!;
    String raw = 'unknown';
    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        raw = '${a.id}|${a.brand}|${a.model}|${a.fingerprint}';
      }
    } catch (_) {}
    // Yerel sil-yükle için kalıcı kimlik bulutta cihaz defterinde tutulur; ham değer cihazdan çıkmaz, hash'lenir.
    _deviceId = sha256.convert(utf8.encode(raw)).toString().substring(0, 40);
    return _deviceId!;
  }

  /// Kuruluş kaynağı Google Play mi?
  Future<bool> installedFromPlay() async {
    try {
      final r = await const MethodChannel('skynav/native').invokeMethod<String>('installer');
      return r == 'com.android.vending';
    } catch (_) { return false; }
  }

  // ---------- Hibe hesabı ----------
  Future<void> refresh() async {
    DateTime? until; bool life = false;
    if (Cloud.ready && uid != null) {
      try {
        final snap = await _db.collection('users').doc(uid).collection('grants').get();
        for (final d in snap.docs) {
          final m = d.data();
          if (m['lifetime'] == true) life = true;
          final u = (m['until'] as Timestamp?)?.toDate();
          if (u != null && (until == null || u.isAfter(until))) until = u;
        }
        final u = await _db.collection('users').doc(uid).get();
        myInviteCode = u.data()?['inviteCode'] as String?;
      } catch (_) {}
    }
    // Çevrimdışı önbellek
    if (until == null && !life) {
      final c = Store.prefs.get('pro_until') as int?;
      if (c != null) until = DateTime.fromMillisecondsSinceEpoch(c);
      life = Store.prefs.get('pro_life', defaultValue: false) as bool;
    } else {
      await Store.put('pro_until', until?.millisecondsSinceEpoch);
      await Store.put('pro_life', life);
    }
    // Firebase'deki geliştirici e-postalarıyla giriş yapan hesap: Pro kendiliğinden açık (ödeme yok, sayaçtan muaf).
    bool devAccount = Store.prefs.get('dev_account', defaultValue: false) as bool;
    if (Cloud.ready && uid != null) {
      try { devAccount = await _isDeveloper(); await Store.put('dev_account', devAccount); } catch (_) {}
    } else if (uid == null) {
      devAccount = false;
    }
    state = ProState(dev: devMode || devAccount, lifetime: life, until: until);
    await _refreshDiscount();
    notifyListeners();
  }

  /// Hesap açıldığında bir kez çalışır: kullanıcı belgesi, davet kodu, ekosistem, lansman ödülü.
  Future<void> onSignedIn() async {
    if (!Cloud.ready || uid == null) return;
    final ref = _db.collection('users').doc(uid);
    try {
      final s = await ref.get();
      if (!s.exists) {
        await ref.set({
          'email': AuthService.user?.email,
          'createdAt': FieldValue.serverTimestamp(),
          'inviteCode': _newCode(),
          'device': await deviceHash(),
        });
      }
      await registerThisApp();
      await checkEcosystem();
      await claimLaunchReward();
    } catch (e) { debugPrint('onSignedIn: $e'); }
    await refresh();
  }

  String _newCode() {
    const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return 'SKY-${List.generate(6, (_) => a[r.nextInt(a.length)]).join()}';
  }

  /// Her açılışta: bu uygulamanın "yüklü ve aktif" kaydı (ekosistem motoru).
  Future<void> registerThisApp({String appId = 'skynav'}) async {
    if (!Cloud.ready || uid == null) return;
    final ref = _db.collection('users').doc(uid).collection('apps').doc(appId);
    final s = await ref.get();
    if (!s.exists) {
      await ref.set({'firstSeen': FieldValue.serverTimestamp(), 'lastActive': FieldValue.serverTimestamp()});
    } else {
      await ref.update({'lastActive': FieldValue.serverTimestamp()});
    }
  }

  /// Aynı Gmail'de ≥7 gündür yüklü + son 7 günde aktif ≥4 farklı uygulama → 30 gün Pro.
  Future<List<Map<String, dynamic>>> myApps() async {
    if (!Cloud.ready || uid == null) return [];
    final q = await _db.collection('users').doc(uid).collection('apps').get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<bool> checkEcosystem() async {
    final apps = await myApps();
    final now = DateTime.now();
    int ok = 0;
    for (final a in apps) {
      final f = (a['firstSeen'] as Timestamp?)?.toDate();
      final l = (a['lastActive'] as Timestamp?)?.toDate();
      if (f != null && l != null && now.difference(f).inDays >= 7 && now.difference(l).inDays <= 7) ok++;
    }
    if (ok < 4) return false;
    final g = _db.collection('users').doc(uid).collection('grants').doc('eco_30d');
    if ((await g.get()).exists) return false;
    await g.set({'kind': 'eco', 'days': 30, 'until': Timestamp.fromDate(now.add(const Duration(days: 30))), 'at': FieldValue.serverTimestamp()});
    lastMessage = '🎉 4 uygulamam = 1 ay Pro! Aynı hesapla 4 uygulamayı kullandığın için 30 gün SkyNav Pro hediye.';
    return true;
  }

  // ---------- Lansman ödül sayacı ----------
  Future<bool> _isDeveloper() async {
    if (devMode) return true;
    try {
      final c = await _db.collection('app_meta').doc('config').get();
      final list = ((c.data()?['developer_emails'] as List?) ?? []).cast<String>().map((e) => e.toLowerCase());
      final mail = AuthService.user?.email?.toLowerCase();
      return mail != null && list.contains(mail);
    } catch (_) { return false; }
  }

  Future<void> claimLaunchReward() async {
    if (!Cloud.ready || uid == null) return;
    if (Store.prefs.get('launch_checked', defaultValue: false) as bool) return;
    if (!await installedFromPlay()) return;           // yalnızca Google Play kurulumu
    if (await _isDeveloper()) return;                  // geliştirici muaf
    final cfg = await _db.collection('app_meta').doc('config').get();
    if (cfg.data()?['is_published_on_play_store'] != true) return;
    final dev = await deviceHash();
    final grantRef = _db.collection('users').doc(uid).collection('grants').doc('launch');
    final devRef = _db.collection('devices').doc(dev);
    final counter = _db.collection('app_meta').doc('launch_rewards');
    try {
      final rank = await _db.runTransaction<int>((tx) async {
        if ((await tx.get(grantRef)).exists) return -1;
        final d = await tx.get(devRef);
        if (d.exists && d.data()?['launchClaimed'] == true) return -1; // sil-yükle suistimali
        final c = await tx.get(counter);
        final n = (c.data()?['count'] as int?) ?? 0;
        if (n >= 10) return -1;
        final r = n + 1;
        tx.set(counter, {'count': r, 'uids': FieldValue.arrayUnion([uid])}, SetOptions(merge: true));
        tx.set(devRef, {'launchClaimed': true, 'uid': uid, 'at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        if (r <= 5) {
          tx.set(grantRef, {'kind': 'launch', 'lifetime': true, 'rank': r, 'at': FieldValue.serverTimestamp()});
        } else {
          tx.set(grantRef, {'kind': 'launch', 'days': 150, 'rank': r,
            'until': Timestamp.fromDate(DateTime.now().add(const Duration(days: 150))), 'at': FieldValue.serverTimestamp()});
        }
        return r;
      });
      await Store.put('launch_checked', true);
      if (rank > 0) {
        lastMessage = rank <= 5
            ? '🏆 Tebrikler kanki! $rank. kullanıcısın: Ömür Boyu SkyNav Pro hediye!'
            : '🎁 Tebrikler kanki! $rank. kullanıcısın: 5 ay (150 gün) SkyNav Pro hediye!';
      }
    } catch (e) { debugPrint('launch: $e'); }
  }

  // ---------- Davet kodu ----------
  /// Yeni kullanıcı kodu girer. Dönen metin kullanıcıya gösterilir. null = başarılı.
  Future<String?> redeemInvite(String raw) async {
    final code = raw.trim().toUpperCase();
    if (!Cloud.ready || uid == null) return 'Kodu kullanmak için önce Google ile giriş yapmalısın.';
    if (code.isEmpty) return 'Kodu yaz kanki.';
    final dev = await deviceHash();
    final me = uid!;
    final inviteRef = _db.collection('invites').doc(code);
    final myRef = _db.collection('users').doc(me);
    final devRef = _db.collection('devices').doc(dev);
    try {
      final err = await _db.runTransaction<String?>((tx) async {
        final inv = await tx.get(inviteRef);
        if (!inv.exists) return 'Bu kod bulunamadı.';
        final m = inv.data()!;
        if (m['used'] == true) return 'Bu kod daha önce kullanılmış.';
        final owner = m['ownerUid'] as String;
        if (owner == me) return 'Kendi kodunu kendine giremezsin.';
        if (m['ownerDevice'] == dev) return 'Aynı cihazdan davet onaylanamaz.';
        final my = await tx.get(myRef);
        if (my.data()?['inviteRedeemed'] == true) return 'Zaten bir davet kodu kullandın.';
        final d = await tx.get(devRef);
        if (d.exists && d.data()?['inviteRedeemed'] == true) return 'Bu cihazda daha önce davet kodu kullanılmış.';
        final until = Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));
        tx.update(inviteRef, {'used': true, 'usedBy': me, 'usedAt': FieldValue.serverTimestamp(), 'usedDevice': dev});
        tx.set(myRef, {'inviteRedeemed': true, 'invitedBy': owner}, SetOptions(merge: true));
        tx.set(devRef, {'inviteRedeemed': true, 'uid': me, 'at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        tx.set(myRef.collection('grants').doc('invite_in'), {'kind': 'invite_in', 'days': 7, 'until': until, 'at': FieldValue.serverTimestamp()});
        // Davet edene 7 gün + indirim kredisi (kendi alt koleksiyonuna yalnızca davet edilen yazabilir; kurallar kontrol eder)
        tx.set(_db.collection('users').doc(owner).collection('credits').doc(me),
            {'friend': me, 'code': code, 'days': 7, 'until': until, 'consumed': false, 'at': FieldValue.serverTimestamp()});
        return null;
      });
      if (err == null) { lastMessage = '🎉 Davet onaylandı! 7 gün SkyNav Pro senin; arkadaşına da 7 gün gitti.'; await refresh(); }
      return err;
    } catch (e) { return 'Şu an doğrulayamadım, internetini kontrol edip tekrar dene.'; }
  }

  /// Davet edilen arkadaşlardan gelen 7 günlük Pro'yu kendi hibelerime işle.
  Future<void> collectInviteCredits() async {
    if (!Cloud.ready || uid == null) return;
    try {
      final q = await _db.collection('users').doc(uid).collection('credits').get();
      for (final c in q.docs) {
        final g = _db.collection('users').doc(uid).collection('grants').doc('invite_out_${c.id}');
        if (!(await g.get()).exists) {
          await g.set({'kind': 'invite_out', 'days': 7, 'until': c['until'], 'friend': c.id, 'at': FieldValue.serverTimestamp()});
        }
      }
    } catch (_) {}
  }

  /// İndirim: ≥7 gün kullanım + onaylı yeni arkadaş (kredi) → 7 gün indirim. Tekrarlanabilir (her arkadaş yalnız bir kez).
  Future<void> _refreshDiscount() async {
    final days = Store.usageDays.length;
    final spanOk = DateTime.now().difference(Store.firstRun).inDays >= 6 && days >= 7;
    DateTime? until = Store.prefs.get('discount_until') != null
        ? DateTime.fromMillisecondsSinceEpoch(Store.prefs.get('discount_until') as int) : null;
    bool friendOk = false;
    if (Cloud.ready && uid != null) {
      try {
        await collectInviteCredits();
        final q = await _db.collection('users').doc(uid).collection('credits').where('consumed', isEqualTo: false).limit(1).get();
        friendOk = q.docs.isNotEmpty;
        final active = until != null && until.isAfter(DateTime.now());
        if (!active && spanOk && friendOk) {
          final credit = q.docs.first;
          until = DateTime.now().add(const Duration(days: 7));
          await credit.reference.update({'consumed': true, 'consumedAt': FieldValue.serverTimestamp()});
          await Store.put('discount_until', until.millisecondsSinceEpoch);
          lastMessage = '🏷️ İndirim açıldı! 7 gün boyunca Pro paketlerinde indirim var.';
        }
      } catch (_) {}
    }
    final active = until != null && until.isAfter(DateTime.now());
    discount = DiscountState(usedDays: days, usageOk: spanOk, friendOk: friendOk || active, active: active, until: active ? until : null);
  }

  Future<void> markUsageAndRefresh() async { await Store.markUsageToday(); await refresh(); }

  /// Satın alma sonrası bulut hibesi (ömür boyu veya 150 gün).
  Future<void> grantPurchase({required bool lifetime}) async {
    final until = DateTime.now().add(const Duration(days: 150));
    await Store.put('pro_life', lifetime);
    await Store.put('pro_until', lifetime ? null : until.millisecondsSinceEpoch);
    if (Cloud.ready && uid != null) {
      try {
        await _db.collection('users').doc(uid).collection('grants').doc(lifetime ? 'purchase_life' : 'purchase_5m_${DateTime.now().millisecondsSinceEpoch}')
            .set({'kind': 'purchase', if (lifetime) 'lifetime': true else 'days': 150, if (!lifetime) 'until': Timestamp.fromDate(until), 'at': FieldValue.serverTimestamp()});
      } catch (_) {}
    }
    await refresh();
  }
}
