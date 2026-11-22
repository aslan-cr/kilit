import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../engine/weather_engine.dart';
import '../services/location_service.dart';
import '../services/icon_service.dart';
import '../services/notify_service.dart';
import '../services/open_meteo_service.dart';
import '../services/store.dart';

const _task = 'skynav_alarm_check';

/// Uygulama kapalıyken ~15 dk'da bir (Android WorkManager alt sınırı) tehlikeli hava / %50+ kar kontrolü.
/// Bildirim sesi, sistemin kendi bildirim sesidir (sentetik ses yok).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await Store.init();
      await Notify.init();
      final p = LocationService.lastKnown;
      if (p == null) return true;
      final s = await OpenMeteoService().fetch(p);
      final a = WeatherEngine.analyze(s, biasCorrection: (Store.prefs.get('bias_c', defaultValue: 0.0) as num).toDouble());
      // Uygulama kapalıyken de ikon havaya göre değişsin (ekrandaysa ertelenir).
      await IconService.updateFromBackground(a, s);
      String? msg; String key = '';
      if (a.blizzardProb >= 50) { msg = 'Tipi ihtimali %${a.blizzardProb.round()} kanki, dışarıda dikkat!'; key = 'blizzard'; }
      else if (a.lentilProb >= 50) { msg = 'Mercimek karı ihtimali %${a.lentilProb.round()}!'; key = 'lentil'; }
      else if (a.snowProb >= 50) { msg = 'Kar ihtimali %${a.snowProb.round()}, yağıyor olabilir kanki.'; key = 'snow'; }
      else if (s.temp >= 38) { msg = 'Aşırı sıcak: ${s.temp.round()}°. Gölgede kal, su iç kanki.'; key = 'heat'; }
      else if (s.windGust >= 24) { msg = 'Fırtına hamlesi ${s.windGust.round()} m/s. Savrulacak şeyleri topla kanki.'; key = 'gale'; }
      if (msg != null) {
        final last = (Store.prefs.get('alarm_$key') as int?) ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - last > 6 * 3600 * 1000) { // aynı alarmı 6 saatte bir
          await Store.put('alarm_$key', DateTime.now().millisecondsSinceEpoch);
          await Notify.show('SkyNav uyarı', msg);
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
}
