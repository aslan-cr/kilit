import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../data/models.dart';
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
      String? msg; String key = '';
      if (a.blizzardProb >= 50) { msg = 'Tipi ihtimali %${a.blizzardProb.round()} kanki, dışarıda dikkat!'; key = 'blizzard'; }
      else if (a.lentilProb >= 50) { msg = 'Mercimek karı ihtimali %${a.lentilProb.round()}!'; key = 'lentil'; }
      else if (a.snowProb >= 50) { msg = 'Kar ihtimali %${a.snowProb.round()}, yağıyor olabilir kanki.'; key = 'snow'; }
      else if (s.temp >= 38) { msg = 'Aşırı sıcak: ${s.temp.round()}°. Gölgede kal, su iç kanki.'; key = 'heat'; }
      else if (s.windGust >= 24) { msg = 'Fırtına hamlesi ${s.windGust.round()} m/s. Savrulacak şeyleri topla kanki.'; key = 'gale'; }
      if (msg != null) {
        final last = sp.getInt('sn_alarm_$key') ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - last > 6 * 3600 * 1000) { // aynı alarmı 6 saatte bir
          await sp.setInt('sn_alarm_$key', DateTime.now().millisecondsSinceEpoch);
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

  /// Uygulamadan çıkınca: ikon değişikliğini birkaç dakika sonraya planla (uygulama kapalıyken uygulanır).
  static Future<void> scheduleIconApply() async {
    try {
      await Workmanager().registerOneOffTask(iconTask, iconTask,
          initialDelay: IconService.idle + const Duration(seconds: 30), existingWorkPolicy: ExistingWorkPolicy.replace);
    } catch (_) {}
  }
}
