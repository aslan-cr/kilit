import 'package:flutter_tts/flutter_tts.dart';
import 'store.dart';

/// Cihazdaki en doğal (enhanced/network/neural) yerel sesi seçer; insan ritminde konuşur.
class Voice {
  static final _tts = FlutterTts();
  static bool _ready = false;
  static String lang = 'tr-TR';

  static Future<void> init([String languageTag = 'tr-TR']) async {
    lang = languageTag;
    try {
      await _tts.setLanguage(languageTag);
      final voices = (await _tts.getVoices as List?) ?? [];
      Map? best; int bestScore = -1;
      for (final v in voices) {
        final m = (v as Map).cast<String, dynamic>();
        final loc = (m['locale'] ?? '').toString().replaceAll('_', '-').toLowerCase();
        if (!loc.startsWith(languageTag.split('-').first.toLowerCase())) continue;
        final name = (m['name'] ?? '').toString().toLowerCase();
        int sc = loc == languageTag.toLowerCase() ? 2 : 0;
        if (name.contains('neural') || name.contains('natural')) sc += 6;
        if (name.contains('enhanced') || name.contains('premium')) sc += 5;
        if (name.contains('network')) sc += 4;
        if (name.contains('local') && !name.contains('network')) sc += 0;
        if (sc > bestScore) { bestScore = sc; best = m; }
      }
      if (best != null) await _tts.setVoice({'name': best['name'].toString(), 'locale': best['locale'].toString()});
      await _tts.setSpeechRate(0.46); // doğal insan ritmi, robotik hızlı okuma yok
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) { _ready = false; }
  }

  static bool get muted => Store.muted;
  static Future<void> setMuted(bool v) async { await Store.put('muted', v); if (v) await stop(); }

  static Future<void> speak(String text) async {
    if (muted) return;
    if (!_ready) await init(lang);
    try { await _tts.stop(); await _tts.speak(text); } catch (_) {}
  }
  static Future<void> stop() async { try { await _tts.stop(); } catch (_) {} }
}
