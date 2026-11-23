import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'store.dart';

/// Yalnızca gerçek kayıtlar (assets/audio/*.ogg, CC0) ve sistemin kendi dokunuş/tık sesleri.
/// Kodla üretilmiş sentetik ses yoktur. Dosya yoksa sessizce atlar.
class Sfx {
  static void tap() { HapticFeedback.selectionClick(); SystemSound.play(SystemSoundType.click); }
  static void alert() { HapticFeedback.heavyImpact(); SystemSound.play(SystemSoundType.alert); }
}

/// Doğa sesi mikseri.
/// - Her kanal ses odağı istemez (AndroidAudioFocus.none): kanallar birbirini susturmaz, gerçekten karışır.
/// - Kaydırıcı ne kadar hızlı oynarsa oynasın her kanal için tek oynatıcı; işlemler sıraya girer.
/// - Ses değişimleri yumuşak geçişle (tık/patlama yok); uyku zamanlayıcısı sonunda yavaşça kısılır.
/// - Çalarken Android'de bildirimli arka plan servisi: ekran kapanınca da sabaha kadar çalar.
class SleepMixer extends ChangeNotifier {
  static final I = SleepMixer._();
  SleepMixer._() {
    _native.setMethodCallHandler((c) async { if (c.method == 'mixerStop') await stopAll(); });
    try {
      final saved = (Store.prefs.get('mixer_last') as Map?)?.cast<String, dynamic>();
      if (saved != null) for (final e in saved.entries) { if (tracks.containsKey(e.key)) last[e.key] = (e.value as num).toDouble(); }
    } catch (_) {}
  }

  static const tracks = <String, String>{
    'rain': 'audio/rain_loop.ogg',
    'forest': 'audio/forest_night.ogg',
    'waves': 'audio/waves.ogg',
    'campfire': 'audio/campfire.ogg',
    'waterfall': 'audio/waterfall.ogg',
  };
  static const labels = {'rain': 'Gece yağmuru', 'forest': 'Orman gecesi (kurbağa & cırcır)', 'waves': 'Dalga sesi', 'campfire': 'Kamp ateşi', 'waterfall': 'Şelale'};
  static const presets = <String, Map<String, double>>{
    'Yağmurlu gece': {'rain': .75, 'forest': .25},
    'Kamp ateşi': {'campfire': .8, 'forest': .4},
    'Deniz kıyısı': {'waves': .8},
    'Şelale ormanı': {'waterfall': .6, 'forest': .35},
  };

  static const _native = MethodChannel('skynav/native');
  static final _ctx = AudioContext(
    android: const AudioContextAndroid(stayAwake: true, contentType: AndroidContentType.music, usageType: AndroidUsageType.media, audioFocus: AndroidAudioFocus.none),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.mixWithOthers}),
  );

  final Map<String, AudioPlayer> _players = {};
  final Map<String, Future<void>> _locks = {};
  final Map<String, double> _cur = {};      // şu an uygulanan ses
  final Map<String, double> level = {for (final k in tracks.keys) k: 0.0}; // kullanıcının seçtiği 0..1
  final Map<String, double> last = {};      // son karışım (ekrana dönünce gösterilir)
  final Set<String> missing = {};
  double master = 1;
  DateTime? sleepAt;
  Timer? _ramp, _tick;
  bool _service = false;

  bool get playing => level.values.any((v) => v > .01);
  Duration? get sleepLeft => sleepAt == null ? null : sleepAt!.difference(DateTime.now());

  // Eski çağrılarla uyum
  static Future<bool> setVolume(String key, double v) => I.set(key, v);

  /// Algısal ses eğrisi: kaydırıcının ortası gerçekten "orta" duyulsun.
  static double _curve(double v) => pow(v.clamp(0.0, 1.0), 1.8).toDouble();

  /// Kanalın seviyesini ayarlar. false: ses dosyası pakette yok.
  Future<bool> set(String key, double v) async {
    level[key] = v.clamp(0.0, 1.0);
    if (v > .01) { last
      ..clear()
      ..addAll({for (final e in level.entries) if (e.value > .01) e.key: e.value}); _saveLast(); }
    _startRamp();
    _syncService();
    notifyListeners();
    if (v > .01) await _ensure(key);
    return !missing.contains(key);
  }

  Future<void> preset(Map<String, double> mix) async {
    for (final k in tracks.keys) { await set(k, mix[k] ?? 0); }
  }

  Future<void> stopAll() async {
    for (final k in tracks.keys) { level[k] = 0; }
    sleepAt = null; _tick?.cancel();
    _startRamp(); _syncService(); notifyListeners();
  }

  void setMaster(double v) { master = v.clamp(0.0, 1.0); _startRamp(); notifyListeners(); }

  /// Uyku zamanlayıcısı: [d] sonunda son 30 sn'de yavaşça kısılır ve durur. null: kapalı.
  void setSleep(Duration? d) {
    sleepAt = d == null ? null : DateTime.now().add(d);
    _tick?.cancel();
    if (d != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = sleepLeft;
        if (left == null) return;
        if (left <= Duration.zero) { stopAll(); return; }
        if (left.inSeconds <= 30) _startRamp();
        if (left.inSeconds % 60 == 0) _syncService(force: true);
        notifyListeners();
      });
    }
    _syncService(force: true);
    notifyListeners();
  }

  double _fade() {
    final l = sleepLeft;
    if (l == null) return 1;
    return (l.inMilliseconds / 30000).clamp(0.0, 1.0);
  }

  /// Tek bir zamanlayıcı tüm kanalları hedef sese doğru yumuşakça taşır (≈ 0,6 sn).
  void _startRamp() {
    _ramp ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      var moving = false;
      for (final k in tracks.keys) {
        final p = _players[k];
        final want = _curve(level[k]!) * master * _fade();
        final cur = _cur[k] ?? 0;
        if ((want - cur).abs() < .002) {
          if (cur != want) { _cur[k] = want; p?.setVolume(want); }
          if (want <= .002 && p != null && p.state == PlayerState.playing) p.pause();
          continue;
        }
        moving = true;
        final next = cur + (want - cur).clamp(-.035, .035);
        _cur[k] = next;
        if (p != null) {
          p.setVolume(next);
          if (next > .002 && p.state != PlayerState.playing) p.resume();
        }
      }
      if (!moving && sleepLeft == null) { _ramp?.cancel(); _ramp = null; }
    });
  }

  /// Kanal için oynatıcıyı bir kez kurar (aynı anda gelen çağrılar aynı kurulumu bekler).
  Future<void> _ensure(String key) => _locks[key] ??= () async {
        if (_players.containsKey(key)) return;
        final p = AudioPlayer(playerId: 'mixer_$key');
        try {
          await p.setAudioContext(_ctx);
          await p.setReleaseMode(ReleaseMode.loop);
          await p.setVolume(0);
          await p.setSource(AssetSource(tracks[key]!));
          _players[key] = p;
          _cur[key] = 0;
          if (level[key]! > .01) await p.resume();
          _startRamp();
        } catch (_) {
          missing.add(key); level[key] = 0; await p.dispose(); notifyListeners();
        } finally {
          _locks.remove(key);
        }
      }();

  void _saveLast() { try { Store.put('mixer_last', Map<String, double>.from(last)); } catch (_) {} }

  /// Android: çalarken bildirimli arka plan servisi (ekran kapanınca sistem uygulamayı kapatmasın).
  void _syncService({bool force = false}) {
    final on = playing;
    if (on == _service && !force) return;
    _service = on;
    final names = [for (final e in level.entries) if (e.value > .01) labels[e.key]!.split(' (').first];
    final l = sleepLeft;
    try {
      _native.invokeMethod('mixerService', {
        'on': on,
        'title': names.isEmpty ? 'Uyku mikseri' : names.join(' · '),
        'text': l == null ? 'Gerçek doğa kayıtları çalıyor' : 'Uyku zamanlayıcısı: ${l.inMinutes + 1} dk sonra yavaşça kısılır',
      });
    } catch (_) {}
  }
}
