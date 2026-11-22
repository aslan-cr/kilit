import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Yerel depo (Hive). Tüm özetler, öz-denetim ve önbellek cihazda kalır.
class Store {
  static late Box prefs, cache, selfcheck, places;
  static Future<void> init() async {
    await Hive.initFlutter();
    prefs = await Hive.openBox('prefs');
    cache = await Hive.openBox('cache');
    selfcheck = await Hive.openBox('selfcheck');
    places = await Hive.openBox('places');
  }

  static T? get<T>(String k) => prefs.get(k) as T?;
  static Future<void> put(String k, dynamic v) => prefs.put(k, v);

  static bool get consentDone => prefs.get('consent_v1', defaultValue: false) as bool;
  static bool get onboardingDone => prefs.get('onboarding_done', defaultValue: false) as bool;
  static bool get muted => prefs.get('muted', defaultValue: false) as bool;

  // Basit önbellek: JSON + zaman damgası
  static void cachePut(String key, Map<String, dynamic> v) =>
      cache.put(key, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'v': v}));
  static ({DateTime t, Map<String, dynamic> v})? cacheGet(String key) {
    final s = cache.get(key) as String?;
    if (s == null) return null;
    final m = jsonDecode(s) as Map<String, dynamic>;
    return (t: DateTime.fromMillisecondsSinceEpoch(m['t'] as int), v: (m['v'] as Map).cast<String, dynamic>());
  }

  /// Aktif kullanım günleri (yyyy-MM-dd). 7 gün şartı için.
  static Set<String> get usageDays => ((prefs.get('usage_days', defaultValue: <dynamic>[]) as List).cast<String>()).toSet();
  static Future<void> markUsageToday() async {
    final d = DateTime.now();
    final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final s = usageDays..add(k);
    await prefs.put('usage_days', s.toList());
    if (prefs.get('first_run') == null) await prefs.put('first_run', d.millisecondsSinceEpoch);
  }
  static DateTime get firstRun => DateTime.fromMillisecondsSinceEpoch((prefs.get('first_run') as int?) ?? DateTime.now().millisecondsSinceEpoch);
}
