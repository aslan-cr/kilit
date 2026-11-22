import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Yalnızca gerçek kayıtlar (assets/audio/*.ogg|mp3, CC0) ve sistemin kendi dokunuş/tık sesleri.
/// Kodla üretilmiş sentetik ses yoktur. Dosya yoksa sessizce atlar.
class Sfx {
  static void tap() { HapticFeedback.selectionClick(); SystemSound.play(SystemSoundType.click); }
  static void alert() { HapticFeedback.heavyImpact(); SystemSound.play(SystemSoundType.alert); }
}

class SleepMixer {
  static final Map<String, AudioPlayer> _players = {};
  static const tracks = <String, String>{
    'rain': 'audio/rain_loop.ogg',
    'wind': 'audio/wind_loop.ogg',
    'thunder': 'audio/thunder_distant.ogg',
    'forest': 'audio/forest_night.ogg',
  };
  static const labels = {'rain': '🌧️ Yağmur', 'wind': '💨 Rüzgar', 'thunder': '⛈️ Uzak gök gürültüsü', 'forest': '🌲 Orman gecesi'};

  /// false dönerse ses dosyası pakette yok demektir (assets/audio/README.md).
  static Future<bool> setVolume(String key, double v) async {
    try {
      var p = _players[key];
      if (v <= 0.01) { await p?.stop(); return true; }
      if (p == null) {
        p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setSource(AssetSource(tracks[key]!));
        _players[key] = p;
      }
      await p.setVolume(v);
      if (p.state != PlayerState.playing) await p.resume();
      return true;
    } catch (_) { _players.remove(key); return false; }
  }
  static Future<void> stopAll() async { for (final p in _players.values) { await p.stop(); } }
}
