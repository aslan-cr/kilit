import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import '../data/models.dart';
import '../data/phrases.dart';
import '../services/weather_repository.dart';
import '../services/store.dart';
import '../pro/pro_service.dart';
import 'widget_faces.dart';

class WidgetService {
  static const _weather = 'com.skynav.skynav.SkyWeatherWidget';
  static const _speed = 'com.skynav.skynav.SkySpeedWidget';
  static DateTime _lastW = DateTime.fromMillisecondsSinceEpoch(0), _lastS = DateTime.fromMillisecondsSinceEpoch(0);

  /// 1) Hava, Kar & Gökyüzü Radarı widget'ı (ücretsiz).
  static Future<void> updateWeather(WeatherSnapshot s, Analysis a) async {
    if (DateTime.now().difference(_lastW) < const Duration(minutes: 5)) return;
    _lastW = DateTime.now();
    final name = switch (a.kind) { PrecipKind.snow => 'Kar', PrecipKind.lentilSnow => 'Mercimek karı', PrecipKind.blizzard => 'Tipi', PrecipKind.sleet => 'Karla karışık', PrecipKind.rain => 'Yağmur', PrecipKind.none => s.cloudCover > 60 ? 'Bulutlu' : (s.isDay ? 'Açık' : 'Açık gece') };
    final line2 = s.cloudCover > 75 && !s.isDay ? 'Yıldız yok kanki' : (!s.isDay ? 'Yıldız netliği %${a.starClarity.round()}' : 'Rüzgâr ${s.windSpeed.toStringAsFixed(0)} m/s · nem %${s.humidity.round()}');
    try {
      await HomeWidget.renderFlutterWidget(
        WeatherWidgetFace(s: s, a: a, place: s.place.name.isEmpty ? 'Konumum' : s.place.name, condition: name, line2: line2, today: _today(s)),
        key: 'weather_img', logicalSize: const Size(320, 160), pixelRatio: 3,
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _weather);
    } catch (_) {}
    await _renderExtras(s, a);
  }

  static const _hourly = 'com.skynav.skynav.SkyHourlyWidget';
  static const _moon = 'com.skynav.skynav.SkyMoonWidget';
  static const _mini = 'com.skynav.skynav.SkyMiniWidget';

  /// Ana ekrana yalnızca eklenmiş widget'ların görüntüsünü üretir (bilinemezse hepsini).
  static Future<void> _renderExtras(WeatherSnapshot s, Analysis a) async {
    Set<String>? placed;
    try {
      placed = {for (final w in await HomeWidget.getInstalledWidgets()) if (w.androidClassName != null) w.androidClassName!};
    } catch (_) {}
    bool want(String cls) => placed == null || placed.any((p) => p.endsWith(cls.split('.').last));
    final now = DateTime.now();
    final place = s.place.name.isEmpty ? 'Konumum' : s.place.name;
    Future<void> one(String cls, String key, Widget face, Size size) async {
      if (!want(cls)) return;
      try {
        await HomeWidget.renderFlutterWidget(face, key: key, logicalSize: size, pixelRatio: 3);
        await HomeWidget.updateWidget(qualifiedAndroidName: cls);
      } catch (_) {}
    }
    await one(_hourly, 'hourly_img', HourlyWidgetFace(s: s, place: place, now: now), const Size(320, 160));
    await one(_moon, 'moon_img', MoonWidgetFace(lat: s.place.lat, lon: s.place.lon, now: now), const Size(160, 160));
    await one(_mini, 'mini_img', MiniWidgetFace(s: s, a: a, place: place, today: _today(s), now: now), const Size(160, 160));
  }

  static DayPoint? _today(WeatherSnapshot s) {
    final n = DateTime.now();
    for (final d in s.daily) { if (d.date.year == n.year && d.date.month == n.month && d.date.day == n.day) return d; }
    return null;
  }

  /// 2) Bağımsız Araç Hızı & Yol Koşulları widget'ı (Pro).
  static Future<void> updateSpeed(double speedMs, {String gText = 'G 0.0', int driftLevel = 0}) async {
    if (DateTime.now().difference(_lastS) < const Duration(seconds: 2)) return;
    _lastS = DateTime.now();
    final s = WeatherController.I.confirmed, a = WeatherController.I.analysis;
    String road = 'Kuru'; int level = 0; String warn = 'Yol temiz, keyfine bak kanki.';
    if (s != null && a != null) {
      final ice = s.temp <= 1 && (a.kind != PrecipKind.none || (s.soil0 ?? 5) <= 0);
      if (a.kind == PrecipKind.blizzard) { road = 'Tipi'; level = 2; warn = 'Tipi var kanki, mümkünse yola çıkma.'; }
      else if (ice) { road = 'Buzlu'; level = 2; warn = Kanki.pick(Kanki.yolBuzlu, s.temp.round()); }
      else if (a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.sleet) { road = 'Karlı'; level = 1; warn = 'Yol kaygan, yavaş git kanki.'; }
      else if (a.kind == PrecipKind.rain) { road = 'Islak'; level = 1; warn = 'Yol ıslak, mesafeni aç kanki.'; }
      else if (a.fogDensity > 60) { road = 'Sisli'; level = 1; warn = 'Görüş düştü, farları yak kanki.'; }
    }
    if (driftLevel >= 2) { level = 2; warn = 'Kayma algılandı! Gazdan ayağını çek, direksiyonu yumuşak tut.'; }
    try {
      await HomeWidget.renderFlutterWidget(SpeedWidgetFace(speedKmh: speedMs * 3.6, road: road, gText: gText, warn: warn, level: level),
          key: 'speed_img', logicalSize: const Size(240, 160), pixelRatio: 3);
      await HomeWidget.updateWidget(qualifiedAndroidName: _speed);
    } catch (_) {}
  }

  // --- Bağımsız hız takibi: Yol Tarifi başlatılmasa bile (Pro, kullanıcı açarsa, görünür bildirimle) ---
  static StreamSubscription<Position>? _sub;
  static bool get speedTracking => _sub != null;
  static bool get speedEnabled => Store.prefs.get('speed_widget_on', defaultValue: false) as bool;

  static Future<void> startSpeedTracking() async {
    if (!ProService.I.state.isPro || _sub != null) return;
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    await Store.put('speed_widget_on', true);
    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'SkyNav hız widget\'ı açık', notificationText: 'Canlı araç hızı ana ekranda güncelleniyor.', enableWakeLock: false),
      ),
    ).listen((p) => updateSpeed(p.speed < 0 ? 0 : p.speed));
  }

  static Future<void> stopSpeedTracking() async {
    await _sub?.cancel(); _sub = null; await Store.put('speed_widget_on', false);
  }
}
