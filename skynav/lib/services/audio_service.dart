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
/// - Döngü: her kanalda iki oynatıcı; dosya bitmeden ikincisi baştan başlar ve 3 sn eşit-güç geçişle
///   devralır. Android MediaPlayer'ın başa sararken verdiği kısa boşluk böylece hiç duyulmaz.
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

  final Map<String, _Chan> _players = {};
  final Map<String, Future<void>> _locks = {};
  final Map<String, double> _cur = {};      // şu an uygulanan ses
  final Map<String, double> level = {for (final k in tracks.keys) k: 0.0}; // kullanıcının seçtiği 0..1
  final Map<String, double> last = {};      // son karışım (ekrana dönünce gösterilir)
  final Set<String> missing = {};
  double master = 1;
  DateTime? sleepAt;
  Timer? _ramp, _tick, _watch;
  bool _service = false;

  bool get playing => level.values.any((v) => v > .01);
  Duration? get sleepLeft => sleepAt == null ? null : sleepAt!.difference(DateTime.now());

  // Eski çağrılarla uyum
  static Future<bool> setVolume(String key, double v) => I.set(key, v);

  /// Algısal ses eğrisi: kaydırıcının ortası gerçekten "orta" duyulsun.
  static double _curve(double v) => pow(v.clamp(0.0, 1.0), 1.8).toDouble();

  /// Kanalın seviyesini ayarlar. false: ses dosyası pakette yok.
  Future<bool> set(String key, double v, {bool remember = true}) async {
    level[key] = v.clamp(0.0, 1.0);
    if (v > .01 && remember) { last
      ..clear()
      ..addAll({for (final e in level.entries) if (e.value > .01) e.key: e.value}); _saveLast(); }
    _startRamp();
    _syncService();
    notifyListeners();
    if (v > .01) await _ensure(key);
    return !missing.contains(key);
  }

  /// [remember] false: kullanıcının kaydettiği "son karışım" değişmez (ör. canlı pencerenin geçici sesi).
  Future<void> preset(Map<String, double> mix, {bool remember = true}) async {
    for (final k in tracks.keys) { await set(k, mix[k] ?? 0, remember: remember); }
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

  /// Tek bir zamanlayıcı tüm kanalları hedef sese doğru yumuşakça taşır (≈ 0,6 sn);
  /// döngü geçişi sürerken iki oynatıcının sesini de o ayarlar.
  void _startRamp() {
    _ramp ??= Timer.periodic(const Duration(milliseconds: 40), (_) => _rampTick());
  }

  void _rampTick() {
    var busy = false;
    for (final k in tracks.keys) {
      final c = _players[k];
      final want = _curve(level[k]!) * master * _fade();
      final cur = _cur[k] ?? 0;
      final double v;
      if ((want - cur).abs() < .002) {
        v = want;
      } else {
        busy = true;
        v = cur + (want - cur).clamp(-.035, .035);
      }
      final changed = v != cur;
      _cur[k] = v;
      if (c == null) continue;
      if (v <= .002) {
        if (c.playing) c.pause();
        continue;
      }
      if (!c.playing) { c.resume(); _startWatch(); }
      if (c.crossfading) {
        busy = true;
        c.apply(v);
      } else if (changed) {
        c.apply(v);
      }
    }
    if (!busy && sleepLeft == null) { _ramp?.cancel(); _ramp = null; }
  }

  /// Çalan kanalların konumunu izler; dosya sonu yaklaşınca geçişi başlatır.
  void _startWatch() {
    _watch ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
      var any = false;
      for (final c in _players.values) {
        if (!c.playing) continue;
        any = true;
        c.watch(_startRamp);
      }
      if (!any) { _watch?.cancel(); _watch = null; }
    });
  }

  /// Kanal için oynatıcıları bir kez kurar (aynı anda gelen çağrılar aynı kurulumu bekler).
  Future<void> _ensure(String key) => _locks[key] ??= () async {
        if (_players.containsKey(key)) return;
        final made = <AudioPlayer>[];
        try {
          for (final id in ['a', 'b']) {
            final p = AudioPlayer(playerId: 'mixer_${key}_$id');
            try {
              await p.setAudioContext(_ctx);
              // Güvenlik ağı: geçiş zamanlayıcısı kaçarsa oynatıcı kendi döngüsüyle sürer, sessizlik olmaz.
              await p.setReleaseMode(ReleaseMode.loop);
              await p.setVolume(0);
              await p.setSource(AssetSource(tracks[key]!));
              made.add(p);
            } catch (_) {
              try { await p.dispose(); } catch (_) {}
              if (made.isEmpty) rethrow; // ikinci oynatıcı kurulamazsa tek oynatıcıyla devam
            }
          }
          final c = _Chan(made);
          try { c.dur = await made.first.getDuration(); } catch (_) {}
          _players[key] = c;
          _cur[key] = 0;
          _startRamp();
        } catch (_) {
          for (final p in made) { try { await p.dispose(); } catch (_) {} }
          missing.add(key); level[key] = 0; notifyListeners();
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
      // Kanal yoksa (iOS/test) ya da servis başlatılamazsa sessizce geç: ses yine çalar.
      _native.invokeMethod('mixerService', {
        'on': on,
        'title': names.isEmpty ? 'Uyku mikseri' : names.join(' · '),
        'text': l == null ? 'Gerçek doğa kayıtları çalıyor' : 'Uyku zamanlayıcısı: ${l.inMinutes + 1} dk sonra yavaşça kısılır',
      }).catchError((_) => null);
    } catch (_) {}
  }
}

/// Bir mikser kanalı: bir ya da iki oynatıcı. Etkin oynatıcı dosya sonuna yaklaşınca öbürü baştan
/// başlar, eşit-güç (cos/sin) eğrisiyle devralır; eski oynatıcı sona ulaşmadan durdurulur.
class _Chan {
  _Chan(this.p);
  final List<AudioPlayer> p;
  static const xf = Duration(milliseconds: 3000);
  static const _lead = Duration(milliseconds: 1200); // geçiş bittiğinde dosyada kalan pay

  int active = 0;
  Duration? dur;
  DateTime? _xfStart;
  bool playing = false;
  bool _checking = false;

  AudioPlayer get cur => p[active];
  AudioPlayer? get other => p.length > 1 ? p[1 - active] : null;
  bool get crossfading => _xfStart != null;

  void apply(double v) {
    final s = _xfStart, o = other;
    if (s == null || o == null) { cur.setVolume(v); return; }
    final t = (DateTime.now().difference(s).inMilliseconds / xf.inMilliseconds).clamp(0.0, 1.0);
    if (t >= 1) {
      o.setVolume(v);
      final old = cur;
      old.setVolume(0);
      old.pause();
      active = 1 - active;
      _xfStart = null;
      return;
    }
    cur.setVolume(v * cos(t * pi / 2));
    o.setVolume(v * sin(t * pi / 2));
  }

  void resume() {
    playing = true;
    cur.resume();
  }

  /// Duraklatınca yarım kalan geçiş bırakılır; devam edince izleyici yeniden başlatır.
  void pause() {
    playing = false;
    _xfStart = null;
    for (final x in p) { x.pause(); }
  }

  Future<void> watch(void Function() kick) async {
    final d = dur, o = other;
    if (!playing || _xfStart != null || _checking || o == null || d == null || d < xf * 4) return;
    _checking = true;
    try {
      final pos = await cur.getCurrentPosition();
      if (pos == null || !playing || _xfStart != null) return;
      if (d - pos > xf + _lead) return;
      await o.setVolume(0);
      await o.seek(Duration.zero);
      if (!playing) return;
      await o.resume();
      _xfStart = DateTime.now();
      kick();
    } catch (_) {
      // Konum okunamadıysa etkin oynatıcı kendi döngüsüyle sürer.
    } finally {
      _checking = false;
    }
  }
}
