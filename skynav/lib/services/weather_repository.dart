import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/models.dart';
import '../engine/validator.dart';
import '../engine/weather_engine.dart';
import '../engine/lab_calculators.dart';
import '../pro/pro_service.dart';
import 'location_service.dart';
import 'metar_service.dart';
import 'mountain_radar.dart';
import 'open_meteo_service.dart';
import 'store.dart';

/// Onaylı hava durumu: ekranda yalnızca doğrulanmış (confirmed) veri görünür.
/// 1 sn'lik nabız adayı sessizce 10 kontrolden geçirir; geçene dek önceki onaylı veri kalır.
class WeatherController extends ChangeNotifier {
  static final WeatherController I = WeatherController._();
  WeatherController._();

  final _om = OpenMeteoService();
  final _radar = MountainRadar();
  final _metar = MetarService();

  WeatherSnapshot? confirmed;
  Analysis? analysis;
  List<LabResult> lab = const [];
  LocStatus locStatus = LocStatus.ok;
  bool offline = false;
  bool turbo = false;

  /// Yalnızca test/ekran görüntüsü için: veriyi doğrudan yerleştirir.
  @visibleForTesting
  void debugSet(WeatherSnapshot s, Analysis a) { confirmed = s; analysis = a; lab = computeLab(s, a); notifyListeners(); }

  WeatherSnapshot? _candidate;
  Analysis? _candAnalysis;
  GeoPoint2? _place;
  GeoPoint2? get place => _place;
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMountain = DateTime.fromMillisecondsSinceEpoch(0);
  List<Mountain> _mountains = const [];
  bool _busy = false;

  Duration get interval => turbo && ProService.I.state.isPro ? const Duration(minutes: 1) : const Duration(minutes: 15);

  /// Her saniye çağrılır (main'deki Timer).
  void pulse() {
    // 1) Adayı sessizce doğrula; onaylanırsa tek hamlede yer değiştir.
    final c = _candidate, ca = _candAnalysis;
    if (c != null && ca != null) {
      final ok = Validator.verify(c, ca, prev: confirmed, integrityOk: _integrity());
      _candidate = null; _candAnalysis = null;
      if (ok) {
        confirmed = c; analysis = ca; lab = computeLab(c, ca);
        notifyListeners();
      }
    }
    // 2) Hız limitli yenileme (API/pil koruması)
    if (!_busy && DateTime.now().difference(_lastFetch) >= interval) refresh();
  }

  bool _integrity() {
    final d = ProService.I.discount;
    if (d.until != null && d.until!.isAfter(DateTime.now().add(const Duration(days: 7, minutes: 5)))) return false; // indirim 7 günü aşamaz
    return true;
  }

  Future<void> setPlace(GeoPoint2 p) async { _place = p; _lastFetch = DateTime.fromMillisecondsSinceEpoch(0); _mountains = const []; await refresh(force: true); }
  Future<void> useGps() async { _place = null; await refresh(force: true); }

  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    if (!force && DateTime.now().difference(_lastFetch) < const Duration(seconds: 45)) return; // alt limit
    _busy = true;
    try {
      GeoPoint2 p;
      if (_place != null) { p = _place!; }
      else {
        final r = await LocationService.current();
        locStatus = r.status; p = r.point;
      }
      final conn = await Connectivity().checkConnectivity();
      offline = conn.contains(ConnectivityResult.none);
      final key = 'wx_${p.lat.toStringAsFixed(2)}_${p.lon.toStringAsFixed(2)}';
      WeatherSnapshot? snap;
      if (!offline) {
        try {
          snap = await _om.fetch(p);
          // Dağ taraması ağır: 30 dk'da bir
          if (_mountains.isEmpty || DateTime.now().difference(_lastMountain) > const Duration(minutes: 30)) {
            try { _mountains = await _radar.scan(p); _lastMountain = DateTime.now(); } catch (_) {}
          }
          MetarObs? m;
          try { m = await _metar.nearest(p); } catch (_) {}
          snap = snap.copyWith(mountains: _mountains, metar: m);
          Store.cache.put(key, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch}));
          _lastFetch = DateTime.now();
        } catch (_) { offline = true; }
      }
      if (snap == null) { notifyListeners(); return; } // önbellek göstergesi: confirmed zaten ekranda
      final bias = (Store.prefs.get('bias_c', defaultValue: 0.0) as num).toDouble();
      final a = WeatherEngine.analyze(snap, biasCorrection: bias);
      if (confirmed == null) {
        // İlk veri: önceki yok, doğrula-sonra-göster
        if (Validator.verify(snap, a, integrityOk: _integrity())) { confirmed = snap; analysis = a; lab = computeLab(snap, a); }
      } else {
        _candidate = snap; _candAnalysis = a; // sonraki nabızda 10 kontrolle onaylanır
      }
      notifyListeners();
    } finally { _busy = false; }
  }

  /// Gözlem butonu: kullanıcının gerçek gözlemi ile motor kararını kıyasla, sapmayı öğren.
  Future<void> observe(PrecipKind real) async {
    final a = analysis; final s = confirmed;
    if (a == null || s == null) return;
    await Store.selfcheck.add({'t': DateTime.now().millisecondsSinceEpoch, 'pred': a.kind.name, 'real': real.name, 'temp': s.temp, 'wb': s.wetBulb});
    // Basit öğrenme: kar gerçek ama tahmin yağmursa eşiği +0.2°C ısıt; tersiyse -0.2 (sınır ±1.5)
    var bias = (Store.prefs.get('bias_c', defaultValue: 0.0) as num).toDouble();
    final snowReal = real == PrecipKind.snow || real == PrecipKind.lentilSnow || real == PrecipKind.blizzard;
    final snowPred = a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.blizzard;
    if (snowReal && !snowPred) bias += .2;
    if (!snowReal && snowPred) bias -= .2;
    await Store.put('bias_c', bias.clamp(-1.5, 1.5));
    await refresh(force: true);
  }

  /// Doğruluk karnesi: son 30 gözlemde isabet oranı (0-100).
  double get accuracy {
    final l = Store.selfcheck.values.toList();
    if (l.isEmpty) return 0;
    final last = l.length > 30 ? l.sublist(l.length - 30) : l;
    final ok = last.where((e) => (e as Map)['pred'] == e['real']).length;
    return ok * 100 / last.length;
  }
}
