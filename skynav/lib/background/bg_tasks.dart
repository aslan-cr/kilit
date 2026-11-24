import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../data/models.dart';
import '../engine/alerts.dart';
import '../engine/brief.dart';
import '../engine/nowcast.dart';
import '../engine/sky_notice.dart';
import '../engine/weather_engine.dart';
import '../services/icon_service.dart';
import '../services/notify_service.dart';
import '../services/open_meteo_service.dart';
import '../services/shared_state.dart';

const _task = 'skynav_alarm_check';
const iconTask = 'skynav_icon_apply';

/// Arka plan görevleri. Hive'a DOKUNMAZ (ana uygulamayla aynı anda yazmak dosyayı bozup çökertebilir);
/// gereken değerleri SharedState'ten okur.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      if (task == iconTask) { await IconService.applyPending(); return true; }
      final sp = await SharedState.fresh();
      await Notify.init();
      final raw = sp.getString('sn_last_place');
      if (raw == null) return true;
      final p = GeoPoint2.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
      final s = await OpenMeteoService().fetch(p);
      final a = WeatherEngine.analyze(s, biasCorrection: sp.getDouble('sn_bias') ?? 0);
      await IconService.updateFromBackground(a, s);
      // Hava uyarıları (önem sırasıyla); her uyarı en fazla 6 saatte bir. Ayarlardan kapatılabilir.
      if (sp.getBool('sn_alerts_off') != true) {
        final now = DateTime.now();
        for (final al in weatherAlerts(s, a, now)) {
          final last = sp.getInt('sn_alarm_${al.key}') ?? 0;
          if (now.millisecondsSinceEpoch - last <= 6 * 3600 * 1000) continue;
          await sp.setInt('sn_alarm_${al.key}', now.millisecondsSinceEpoch);
          await Notify.show('SkyNav · ${al.title}', al.body);
          break; // tek çalıştırmada tek bildirim
        }
      }
      // Yağış başlıyor: 15 dakikalık tahminde 30 dk içinde yağış (3 saatte en fazla bir kez)
      if (sp.getBool('sn_rainsoon_off') != true) {
        final n = Nowcast.of(s.nowcast, DateTime.now());
        if (!n.wetNow && n.startsIn != null && n.startsIn! <= 30) {
          final last = sp.getInt('sn_alarm_rainsoon') ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - last > 3 * 3600 * 1000) {
            await sp.setInt('sn_alarm_rainsoon', DateTime.now().millisecondsSinceEpoch);
            await Notify.show('SkyNav · ${n.snow ? 'Kar' : 'Yağmur'} geliyor', '${n.headline}. ${n.snow ? 'Yollar kayganlaşabilir kanki.' : 'Şemsiyeni al kanki.'}');
          }
        }
      }
      // Gökyüzü olayı: akşam 18–23 arası, olay başına bir kez (meteor tepe gecesi, Türkiye'den görülen tutulma)
      final ev = DateTime.now();
      if (sp.getBool('sn_sky_off') != true && ev.hour >= 18 && ev.hour < 23) {
        final n = skyNotice(ev, p.lat, p.lon);
        if (n != null && sp.getString('sn_sky_last') != n.key) {
          await sp.setString('sn_sky_last', n.key);
          await Notify.show('SkyNav · ${n.title}', n.body);
        }
      }
      // Sabah özeti: 07:00–10:00 arası günde bir kez (Ayarlar'dan kapatılabilir)
      final t = DateTime.now();
      final bh = sp.getInt('sn_brief_hour') ?? 7; // Ayarlar'dan seçilen saat; 3 saatlik pencere
      if (sp.getBool('sn_brief_off') != true && t.hour >= bh && t.hour < bh + 3) {
        final day = '${t.year}-${t.month}-${t.day}';
        if (sp.getString('sn_brief_day') != day) {
          await sp.setString('sn_brief_day', day);
          final text = morningBrief(s, t);
          if (text.isNotEmpty) await Notify.show('Günaydın${p.name.isEmpty ? '' : ' · ${p.name}'}', text);
        }
      }
      return true;
    } catch (e) { debugPrint('bg: $e'); return true; }
  });
}

class Background {
  static Future<void> start() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(_task, _task,
        frequency: const Duration(minutes: 15), existingWorkPolicy: ExistingWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected));
  }

  /// Uygulamadan çıkınca: ikon değişikliğini birkaç dakika sonraya planla (uygulama kapalıyken uygulanır).
  static Future<void> scheduleIconApply() async {
    try {
      await Workmanager().registerOneOffTask(iconTask, iconTask,
          initialDelay: IconService.idle + const Duration(seconds: 30), existingWorkPolicy: ExistingWorkPolicy.replace);
    } catch (_) {}
  }
}
