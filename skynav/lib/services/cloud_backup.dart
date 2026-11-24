import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../ui/plain.dart';
import 'auth_service.dart';
import 'cloud.dart';
import 'shared_state.dart';
import 'store.dart';

/// Geri yüklemenin özeti (kullanıcıya gösterilir).
class RestoreResult {
  final int places, badges, capsules;
  const RestoreResult(this.places, this.badges, this.capsules);
  bool get any => places + badges + capsules > 0;
  String get text {
    final p = <String>[
      if (places > 0) '$places yer',
      if (badges > 0) '$badges rozet',
      if (capsules > 0) '$capsules kapsül',
    ];
    return p.isEmpty ? 'Ayarların geri geldi.' : 'Yedeğin geri geldi: ${p.join(', ')}.';
  }
}

/// Gmail hesabına bağlı bulut yedeği: uygulama silinip yeniden kurulsa ya da telefon değişse de aynı hesapla
/// girince kayıtlı yerler, rozetler, zaman kapsülleri, gözlem öğrenmesi ve ayarlar geri gelir.
///
/// Yer: users/{uid}/apps/skynav belgesinin 'backup' alanı (JSON metni). Firestore kuralı bu belgeye yalnızca
/// sahibinin okuyup yazmasına izin verir. Belge ekosistem kaydıyla ortaktır; firstSeen/lastActive alanlarına
/// dokunulmaz, belge yoksa (henüz kayıt olmadıysa) yedek yazılmaz.
///
/// Geri yükleme BİRLEŞTİRİR, cihazdaki hiçbir veriyi silmez. Pro hakları burada değildir (hesaptan gelir).
/// Arka plan görevi bu sınıfı kullanmaz (Hive).
class CloudBackup {
  static const version = 1;
  // Hive 'prefs' içinden yedeklenen tekil ayarlar (cihazda değer varsa cihazdaki kalır)
  static const _prefScalars = ['plain_lang', 'muted', 'mixer_last', 'bias_c'];
  // Bildirim ve görünüm tercihleri (SharedState; arka plan görevi de okur)
  static const _spBools = ['sn_alerts_off', 'sn_rainsoon_off', 'sn_sky_off', 'sn_frost_off', 'sn_brief_off', 'sn_dyn_icon'];
  static const _spInts = ['sn_brief_hour'];
  static const _maxSelfcheck = 300;

  /// Uygulama geneli mesaj çubuğu (MaterialApp.scaffoldMessengerKey).
  static final messenger = GlobalKey<ScaffoldMessengerState>();

  /// Geri yükleme sonucunu kısa bir mesajla bildirir.
  static void announce(RestoreResult? r) {
    if (r == null || !r.any) return;
    messenger.currentState?.showSnackBar(SnackBar(content: Text(r.text), behavior: SnackBarBehavior.floating));
  }

  static bool get enabled => Store.prefs.get('cloud_backup_off', defaultValue: false) != true;
  static DateTime? get lastBackup {
    final t = Store.prefs.get('cloud_backup_at') as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final u = AuthService.user;
    if (!Cloud.ready || u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid).collection('apps').doc('skynav');
  }

  // ── Yerel anlık görüntü ───────────────────────────────────────────────
  /// Cihazdaki yedeklenecek verilerin anlık görüntüsü.
  static Map<String, dynamic> collect() {
    final prefs = Store.prefs;
    final sp = SharedState.cached;
    final selfcheck = Store.selfcheck.values.whereType<Map>().map((m) => _clean(m) as Map<String, dynamic>).toList();
    return {
      'v': version,
      'places': {for (final k in Store.places.keys) k.toString(): Store.places.get(k) as String},
      'badges': (prefs.get('badges', defaultValue: <dynamic>[]) as List).map((e) => e.toString()).toList(),
      'capsules': (prefs.get('capsules', defaultValue: <dynamic>[]) as List).map((e) => e.toString()).toList(),
      'xp': {for (final k in prefs.keys) if (k.toString().startsWith('xp_')) k.toString(): _clean(prefs.get(k))},
      'prefs': {for (final k in _prefScalars) if (prefs.containsKey(k)) k: _clean(prefs.get(k))},
      'sp': {
        if (sp != null) ...{
          for (final k in _spBools) if (sp.containsKey(k)) k: sp.getBool(k),
          for (final k in _spInts) if (sp.containsKey(k)) k: sp.getInt(k),
        },
      },
      'selfcheck': selfcheck.length > _maxSelfcheck ? selfcheck.sublist(selfcheck.length - _maxSelfcheck) : selfcheck,
    };
  }

  /// JSON'a uygun hâle getirir: NaN/sonsuz sayılar null olur, anahtarlar metin olur.
  static Object? _clean(Object? v) {
    if (v is double) return v.isFinite ? v : null;
    if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key.toString(): _clean(e.value)};
    if (v is List) return [for (final e in v) _clean(e)];
    if (v == null || v is num || v is String || v is bool) return v;
    return v.toString();
  }

  /// İki anlık görüntüyü birleştirir; [local] her zaman kazanır, hiçbir şey silinmez. Saf fonksiyon (test edilir).
  /// Dönüş: birleşmiş görüntü ve buluttan GELEN yeni öğe sayıları.
  static (Map<String, dynamic>, RestoreResult) merge(Map<String, dynamic> local, Map<String, dynamic> cloud) {
    Map<String, dynamic> m(Object? x) => x is Map ? x.cast<String, dynamic>() : <String, dynamic>{};
    List<String> l(Object? x) => x is List ? x.map((e) => e.toString()).toList() : <String>[];

    final places = {...m(cloud['places']), ...m(local['places'])};
    final newPlaces = places.length - m(local['places']).length;

    final lb = l(local['badges']);
    final badges = [...lb, ...l(cloud['badges']).where((b) => !lb.contains(b))];

    // Kapsüller: aynı metin aynı kapsüldür; zamana göre sıralı
    final lc = l(local['capsules']);
    final caps = [...lc, ...l(cloud['capsules']).where((c) => !lc.contains(c))];
    String t(String s) { try { return (jsonDecode(s) as Map)['t'].toString(); } catch (_) { return ''; } }
    caps.sort((a, b) => t(a).compareTo(t(b)));

    final xp = <String, dynamic>{...m(cloud['xp'])};
    m(local['xp']).forEach((k, v) => xp[k] = (v is num && xp[k] is num) ? (v > (xp[k] as num) ? v : xp[k]) : v);

    final selfcheck = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final e in [...(local['selfcheck'] as List? ?? []), ...(cloud['selfcheck'] as List? ?? [])]) {
      if (e is! Map) continue;
      final k = '${e['t']}';
      if (seen.add(k)) selfcheck.add(e.cast<String, dynamic>());
    }
    selfcheck.sort((a, b) => ((a['t'] as num?) ?? 0).compareTo((b['t'] as num?) ?? 0));

    return ({
      'v': version,
      'places': places,
      'badges': badges,
      'capsules': caps,
      'xp': xp,
      'prefs': {...m(cloud['prefs']), ...m(local['prefs'])},
      'sp': {...m(cloud['sp']), ...m(local['sp'])},
      'selfcheck': selfcheck.length > _maxSelfcheck ? selfcheck.sublist(selfcheck.length - _maxSelfcheck) : selfcheck,
    }, RestoreResult(newPlaces, badges.length - lb.length, caps.length - lc.length));
  }

  /// Birleşmiş görüntüyü cihaza yazar (yalnızca ekler/günceller).
  static Future<void> apply(Map<String, dynamic> s) async {
    final prefs = Store.prefs;
    for (final e in (s['places'] as Map).entries) {
      if (!Store.places.containsKey(e.key)) await Store.places.put(e.key, e.value as String);
    }
    await prefs.put('badges', (s['badges'] as List).cast<String>().toList());
    await prefs.put('capsules', (s['capsules'] as List).cast<String>().toList());
    for (final e in (s['xp'] as Map).entries) { await prefs.put(e.key, e.value); }
    for (final e in (s['prefs'] as Map).entries) {
      if (!prefs.containsKey(e.key)) await prefs.put(e.key, e.value is Map ? (e.value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) : e.value);
    }
    final sp = await SharedState.get();
    for (final e in (s['sp'] as Map).entries) {
      if (sp.containsKey(e.key as String)) continue;
      if (e.value is bool) await sp.setBool(e.key, e.value as bool);
      if (e.value is int) await sp.setInt(e.key, e.value as int);
    }
    // Arka plan görevi düzeltmeyi SharedState'ten okur
    await sp.setDouble('sn_bias', ((prefs.get('bias_c', defaultValue: 0.0)) as num).toDouble());
    final have = Store.selfcheck.values.whereType<Map>().map((e) => '${e['t']}').toSet();
    for (final e in (s['selfcheck'] as List)) {
      if (e is Map && !have.contains('${e['t']}')) await Store.selfcheck.add(Map<String, dynamic>.from(e));
    }
    final plain = prefs.get('plain_lang', defaultValue: false) == true;
    if (plain != Plain.on) await Plain.set(plain);
  }

  // ── Bulut ─────────────────────────────────────────────────────────────
  // Her yazışta rastgele bir sürüm damgası (backupRev) yazılır; cihaz en son yazdığı ya da birleştirdiği damgayı
  // 'cloud_rev' olarak saklar ("uid:rev"). Buluttaki damga farklıysa (yeni kurulum, Android'in eski bir yerel
  // yedeği geri yüklemesi, başka telefon) önce buluttaki cihazdakiyle birleştirilir, sonra yazılır.
  // Böylece eski/boş yerel veri buluttaki yeni yedeği asla ezmez. Sunucuya ulaşılamazsa hiç yazılmaz.

  static String? _lastSent;
  static Future<RestoreResult?>? _running;

  static String _newRev() {
    final r = Random.secure();
    return List.generate(12, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)]).join();
  }

  /// Bulutla eşitle: gerekirse buluttakini birleştirir, değiştiyse yazar.
  /// Dönüş: buluttan yeni öğe geldiyse özeti (yoksa null). Aynı anda tek eşitleme çalışır.
  static Future<RestoreResult?> sync({bool forceMerge = false, bool forceWrite = false}) {
    return _running ??= _sync(forceMerge, forceWrite).whenComplete(() => _running = null);
  }

  /// Son eşitleme hatasız bitti mi (çevrimdışıysa false).
  static bool lastOk = false;

  static Future<RestoreResult?> _sync(bool forceMerge, bool forceWrite) async {
    final ref = _doc();
    final uid = AuthService.user?.uid;
    lastOk = false;
    if (ref == null || uid == null) return null;
    // Kullanıcı yedeği kapattıysa hiç dokunma (elle "geri getir" hariç)
    if (!enabled && !forceMerge) return null;
    try {
      final mine = Store.prefs.get('cloud_rev') as String?;
      final known = mine != null && mine.startsWith('$uid:');
      // Bu hesapla daha önce eşitlendiyse ve yerel veri son gönderilenle aynıysa okumaya bile gerek yok
      if (known && !forceMerge && !forceWrite && _lastSent != null && jsonEncode(collect()) == _lastSent) { lastOk = true; return null; }
      final d = await ref.get(const GetOptions(source: Source.server));
      if (!d.exists) return null; // ekosistem kaydı henüz yok; sonraki açılışta
      final data = d.data() ?? const {};
      final cloudRev = data['backupRev'] as String?;
      final raw = data['backup'];
      RestoreResult? res;
      if (raw is String && raw.isNotEmpty && (forceMerge || !known || mine != '$uid:$cloudRev')) {
        final cloud = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final (merged, r) = merge(collect(), cloud);
        await apply(merged);
        res = r;
      }
      if (cloudRev != null) await Store.put('cloud_rev', '$uid:$cloudRev');
      if (!enabled) { lastOk = true; return res; }
      var s = collect();
      var json = jsonEncode(s);
      // Firestore belgesi en fazla 1 MB: gerekirse eski gözlem ve kapsülleri kırp
      while (json.length > 800000 && ((s['selfcheck'] as List).isNotEmpty || (s['capsules'] as List).length > 20)) {
        final sc = s['selfcheck'] as List, caps = s['capsules'] as List;
        s = {...s, 'selfcheck': sc.isEmpty ? sc : sc.sublist(sc.length ~/ 2), 'capsules': sc.isEmpty ? caps.sublist(caps.length ~/ 2) : caps};
        json = jsonEncode(s);
      }
      if (forceWrite || res != null || raw != json) {
        final rev = _newRev();
        await ref.update({'backup': json, 'backupV': version, 'backupRev': rev, 'backupAt': FieldValue.serverTimestamp()});
        await Store.put('cloud_rev', '$uid:$rev');
        await Store.put('cloud_backup_at', DateTime.now().millisecondsSinceEpoch);
      }
      _lastSent = json;
      lastOk = true;
      return res;
    } catch (e) {
      debugPrint('cloud sync: $e'); // çevrimdışı vb.: hiçbir şey yazılmadı, sonraki seferde
      return null;
    }
  }

  /// Girişten sonra ve açılışta: buluttaki yedeği getirir ve eşitler.
  static Future<RestoreResult?> restoreIfNeeded({bool force = false}) => sync(forceMerge: force);

  /// Uygulamadan çıkarken ve "Şimdi yedekle": değiştiyse buluta yazar. Başarılıysa true.
  static Future<bool> backupNow({bool force = false}) async {
    if (_doc() == null || !enabled) return false;
    await sync(forceWrite: force);
    return lastOk;
  }

  /// Ayarlar: yedeklemeyi aç/kapat.
  static Future<void> setEnabled(bool v) async {
    await Store.put('cloud_backup_off', !v);
    if (v) await backupNow(force: true);
  }

  /// Ayarlar: buluttaki yedeği sil (cihazdaki veriler kalır) ve yedeklemeyi kapat.
  static Future<bool> deleteCloud() async {
    final ref = _doc();
    if (ref == null) return false;
    try {
      await ref.update({'backup': FieldValue.delete(), 'backupV': FieldValue.delete(), 'backupRev': FieldValue.delete(), 'backupAt': FieldValue.delete()});
      await Store.put('cloud_backup_off', true);
      await Store.put('cloud_backup_at', null);
      _lastSent = null;
      return true;
    } catch (e) {
      debugPrint('backup delete: $e');
      return false;
    }
  }
}
