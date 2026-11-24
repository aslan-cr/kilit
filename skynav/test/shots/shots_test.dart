// Ekran görüntüsü düzeneği: `flutter test test/shots --dart-define=SHOTS=1`
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/astro/astro_math.dart' show sunAltitude;
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/weather_engine.dart';
import 'package:skynav/services/store.dart';
import 'package:skynav/services/location_service.dart';
import 'package:skynav/services/weather_repository.dart';
import 'package:skynav/ui/app_shell.dart';
import 'package:skynav/ui/lab_screen.dart';
import 'package:skynav/ui/badges_screen.dart';
import 'package:skynav/ui/tools_screens.dart';
import 'package:skynav/ui/map3d_screen.dart';
import 'package:skynav/ui/plane_radar_screen.dart';
import 'package:skynav/ui/onboarding.dart';
import 'package:skynav/ui/paywall.dart';
import 'package:skynav/ui/settings_screen.dart';
import 'package:skynav/ui/road_screen.dart';
import 'package:skynav/ui/sky_screen.dart';
import 'package:skynav/ui/weather_screen.dart' show SkyMoonPage, ToolsPage;
import 'package:skynav/ui/clouds.dart';
import 'package:skynav/ui/detail_screens.dart';
import 'package:skynav/ui/plain.dart';
import 'package:skynav/ui/places_screen.dart';
import 'package:skynav/ui/compare_screen.dart';
import 'package:skynav/ui/ski_screen.dart';
import 'package:skynav/services/ski_service.dart';
import 'package:skynav/ui/best_time_screen.dart';
import 'package:skynav/ui/climate_screen.dart';
import 'package:skynav/ui/air_screen.dart';
import 'package:skynav/services/air_service.dart';
import 'package:skynav/services/climate_service.dart';
import 'package:skynav/ui/wx_glyph.dart' show Wx;
import 'package:skynav/ui/hero_scene.dart' show Lightning;
import 'package:skynav/ui/scene_shaders.dart';
import 'package:skynav/ui/sky_bodies.dart';
import 'package:skynav/ui/bento.dart';
import 'package:skynav/ui/theme.dart';
import 'package:skynav/widgets/widget_faces.dart';

const outDir = String.fromEnvironment('OUT', defaultValue: '/tmp/shots');

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) { final b = File(f).readAsBytesSync(); l.addFont(Future.value(ByteData.view(b.buffer))); }
  await l.load();
}

WeatherSnapshot fake({PrecipKind k = PrecipKind.snow, bool day = true, double t = -2}) {
  final now = DateTime.now();
  return WeatherSnapshot(
    place: const GeoPoint2(39.9, 41.27, elevation: 1850, name: 'Erzurum'), fetchedAt: now,
    temp: t, feelsLike: t - 6, humidity: 88, dewPoint: t - 2, pressure: 1012, windSpeed: 6.5, windDir: 300, windGust: 11,
    cloudCover: k == PrecipKind.none ? 20 : 90, cloudHigh: 30, precip: k == PrecipKind.none ? 0 : 1.1, snowfall: k == PrecipKind.snow ? .9 : 0,
    visibilityM: 4000, cape: 30, uv: 1.2, freezingLevelM: 900, snowDepthM: .18, wetBulb: t - .6, weatherCode: 73, isDay: day,
    soil0: -1.2, soil6: -.4, soil18: .8, soil54: 3.1, soil0Past3dAvg: -.6,
    pressureLevels: const {1000: {'temp': -2}, 925: {'temp': -6}, 850: {'temp': -9}, 700: {'temp': -16}, 500: {'temp': -30}, 300: {'temp': -48}},
    // Figma örneğiyle aynı saatlik seri (3 saat geçmiş + 24 saat); basınç son 3 saatte sabit.
    // Basınç son 3 saatte sabit; daha eskisi (72 sa grafiği için) yavaşça yükselen bir dalga.
    hourly: [for (var i = -48; i < 48; i++) HourPoint(time: now.add(Duration(hours: i)), temp: t + _ht[(i + 48) % 24] + 2, precip: _hp[(i + 48) % 24], snowfall: _hp[(i + 48) % 24] * .9,
        windSpeed: 5 + 2 * sin(i / 5), windDir: 300, cloud: 70, humidity: 85, dewPoint: t - 3, weatherCode: _hp[(i + 48) % 24] > 0 ? 73 : 3,
        pressure: i >= -3 ? 1012 + i * .1 : 1012 - .3 - 4 * sin((i + 3) / 14), gust: 9 + 3 * sin(i / 5), uv: max(0, 2.2 * sin(((i + now.hour + 48) % 24 - 7) / 10 * pi)))],
    daily: [for (var i = 0; i < 7; i++) DayPoint(date: now.add(Duration(days: i)), tMax: t + 3 + i, tMin: t - 5 + i * .5, precipSum: i.isEven ? 3 : 0, snowSum: i.isEven ? 4 : 0, windMax: 9, weatherCode: i.isEven ? 73 : 2,
        sunrise: DateTime(now.year, now.month, now.day, 7, 48), sunset: DateTime(now.year, now.month, now.day, 17, 19))],
    // Kar 35 dk sonra başlıyor (15 dakikalık tahmin)
    nowcast: k == PrecipKind.none ? const [] : [for (var i = 0; i < 12; i++) NowPoint(DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 15).add(Duration(minutes: 15 * i)),
        i >= 3 && i < 8 ? [.15, .35, .6, .45, .2][i - 3] : 0, i >= 3 && i < 8 ? .3 : 0)],
    ensembleMembers: 82, ensembleSnowProb: 74, ensembleRainProb: 12, modelTemp24h: const {'ecmwf': -2.4, 'gfs': -1.8, 'icon': -2.9, 'gem': -2.1}, modelPrecip24h: const {'ecmwf': 4.1, 'gfs': 3.2, 'icon': 5.0, 'gem': 3.6},
    aqPm10: 18, mountains: const [Mountain(lat: 40, lon: 41.1, elevation: 3140, distanceKm: 25, bearingDeg: 300, snowDepthM: .8, tempC: -12)],
  );
}

/// Enlem 39.9'da güneşin şu an [alt] yükseklikte ve batmakta olduğu boylam.
double _lonForSun(double alt) {
  final now = DateTime.now().toUtc();
  var best = 0.0, err = 1e9;
  for (var lon = -180.0; lon < 180; lon += .25) {
    final a = sunAltitude(39.9, lon, now);
    final setting = sunAltitude(39.9, lon, now.add(const Duration(minutes: 10))) < a;
    if (setting && (a - alt).abs() < err) { err = (a - alt).abs(); best = lon; }
  }
  return best;
}

const _ht = <double>[-4, -4, -3, -3, -2, -1, 0, 1, 1, 0, -1, -2, -3, -3, -4, -5, -5, -6, -6, -5, -5, -4, -4, -3];
const _hp = <double>[.5, .6, .3, 0, 0, 0, .2, .8, 1.2, .9, .4, 0, 0, 0, .3, .7, .5, .2, 0, 0, 0, .4, .6, .3];

Future<void> shot(WidgetTester t, Widget w, String name, {Size size = const Size(412, 915), Duration extra = Duration.zero}) async {
  await t.binding.setSurfaceSize(size);
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: w)));
  for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 250)); }
  if (extra > Duration.zero) await t.pump(extra);
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const d = '/usr/share/fonts/opentype/inter';
    await _font('Inter', ['$d/Inter-Regular.otf', '$d/Inter-Medium.otf', '$d/Inter-SemiBold.otf', '$d/Inter-Bold.otf', '$d/Inter-ExtraBold.otf', '$d/Inter-Black.otf']);
    await _font('Roboto', ['$d/Inter-Regular.otf', '$d/Inter-Bold.otf']);
    await _font('MaterialIcons', ['/tmp/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('InterDisplay', ['/usr/share/fonts/opentype/inter/InterDisplay-Light.otf', '/usr/share/fonts/opentype/inter/InterDisplay-Medium.otf']);
    await _font('NotoColorEmoji', ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
    await Future.wait([CloudShader.load(), MountainShader.load(), MoonRenderer.load()]);
    final tmp = Directory.systemTemp.createTempSync('hive');
    await Store.init(testPath: tmp.path);
    await Store.put('onboarding_done', true);
    await LocationService.savePlace(const GeoPoint2(39.91, 41.28, name: 'Evim'));
    await LocationService.savePlace(const GeoPoint2(39.95, 41.10, name: 'Anneannem'));
  });

  testWidgets('ekranlar', (t) async {
    final s = fake();
    WeatherController.I.debugSet(s, WeatherEngine.analyze(s));
    final an = WeatherEngine.analyze(s);
    await shot(t, Scaffold(backgroundColor: const Color(0xFF6B7F99), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      WeatherWidgetFace(s: s, a: an, place: 'Erzurum', condition: 'Kar', line2: 'Rüzgâr 6 m/s · nem %88', today: s.daily.first),
      const SizedBox(height: 16),
      WeatherWidgetFace(s: fake(k: PrecipKind.none, day: false, t: 6), a: WeatherEngine.analyze(fake(k: PrecipKind.none, day: false, t: 6)), place: 'Erzurum', condition: 'Açık gece', line2: 'Yıldız netliği %80'),
      const SizedBox(height: 16),
      const Row(mainAxisSize: MainAxisSize.min, children: [
        SpeedWidgetFace(speedKmh: 54, road: 'Karlı', gText: 'G 0.2', warn: 'Yol kaygan, yavaş git kanki.', level: 1),
      ]),
      const SizedBox(height: 16),
      HourlyWidgetFace(s: s, place: 'Erzurum', now: DateTime.now()),
      const SizedBox(height: 16),
      Row(mainAxisSize: MainAxisSize.min, children: [
        MiniWidgetFace(s: s, a: an, place: 'Erzurum', today: s.daily.first, now: DateTime.now()),
        const SizedBox(width: 16),
        MoonWidgetFace(lat: s.place.lat, lon: s.place.lon, now: DateTime.now()),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisSize: MainAxisSize.min, children: [
        SkiWidgetFace(s: SkiNow(skiResorts.first, snowCm: 85, new24: 12, next72: 30, temp: -8, wind: 6, gust: 12, gustNext12: 14, code: 73), km: 4),
        const SizedBox(width: 16),
        AirWidgetFace(s: s, place: 'Erzurum'),
      ]),
    ]))), '00_widgets', size: const Size(412, 1200));
    await shot(t, const Onboarding(onDone: _noop), '01_onboarding');
    await shot(t, const AppShell(), '02_weather');
    await shot(t, const AppShell(), '02b_weather_full', size: const Size(412, 4900));
    // Saatlik grafikte parmakla gezinme
    final hb = find.byType(HourlyBlock);
    final g = await t.startGesture(t.getCenter(hb) + const Offset(-60, 40));
    await g.moveBy(const Offset(30, 0)); await t.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(40, 0)); for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 60)); }
    await t.runAsync(() async {
      final b = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final img = await b.toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/02c_scrub.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await g.up(); await t.pump(const Duration(seconds: 2));
    // Bir saate dokun: saatlik detay alt sayfası
    await t.tapAt(t.getCenter(hb) + const Offset(40, 40));
    for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 100)); }
    await t.runAsync(() async {
      final b = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final img = await b.toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/02e_hour_sheet.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await t.pump(const Duration(seconds: 2));
    // Anlaşılır dil açık: aynı ekran gündelik dille
    Plain.on = true;
    await shot(t, const AppShell(), '02d_plain_full', size: const Size(412, 4900));
    await shot(t, TrendScreen(s: s), '17b_trend_plain', size: const Size(412, 1050));
    Plain.on = false;
    // Yeni sayfalar: gün detayı, Ay, basınç/rüzgâr grafikleri, canlı pencere
    await shot(t, DayDetailScreen(s: s, day: s.daily[1], index: 1), '15_day', size: const Size(412, 1900));
    await shot(t, MoonDetailScreen(lat: s.place.lat, lon: s.place.lon), '16_moon', size: const Size(412, 1150));
    await shot(t, TrendScreen(s: s), '17_trend', size: const Size(412, 1050));
    await shot(t, SkyMoonPage(s: s, a: an), '19_sky_moon', size: const Size(412, 1700));
    await shot(t, const ToolsPage(), '20_tools', size: const Size(412, 700));
    await shot(t, PlacesScreen(fetch: (p) async => p.name == 'Evim'
        ? PlaceNow(place: p, temp: -3, tMax: 0, tMin: -8, wind: 4, precip: .4, cloud: 95, code: 73, isDay: true)
        : PlaceNow(place: p, temp: 1, tMax: 4, tMin: -6, wind: 2, precip: 0, cloud: 30, code: 2, isDay: true)), '21_places', size: const Size(412, 900));
    await shot(t, CompareScreen(
        a: PlaceNow(place: const GeoPoint2(39.9, 41.27, name: 'Erzurum'), temp: -2, tMax: 1, tMin: -7, wind: 6, precip: 1, cloud: 90, code: 73, isDay: true, days: s.daily),
        b: PlaceNow(place: const GeoPoint2(39.95, 41.10, name: 'Anneannem'), temp: -5, tMax: -1, tMin: -11, wind: 3, precip: 0, cloud: 30, code: 2, isDay: true,
            days: [for (final d in s.daily) DayPoint(date: d.date, tMax: d.tMax - 3, tMin: d.tMin - 4, precipSum: d.precipSum * 1.5, snowSum: d.snowSum * 1.6, windMax: d.windMax, weatherCode: d.weatherCode)])),
        '25_compare', size: const Size(412, 1000));
    await shot(t, BestTimeScreen(s: s), '22_best_time', size: const Size(412, 1000));
    await shot(t, SkiScreen(here: s.place, data: [for (final (i, r) in skiResorts.indexed) SkiNow(r, snowCm: <double>[85.0, 62.0, 120.0, 45.0, 70.0, 38.0, 20.0, 55.0][i], new24: <double>[12.0, 4.0, 0.0, 2.0, 6.0, 0.0, 0.0, 3.0][i],
        next72: <double>[30.0, 18.0, 6.0, 10.0, 14.0, 2.0, 0.0, 9.0][i], temp: <double>[-8.0, -6.0, -9.0, -3.0, -4.0, -2.0, 1.0, -3.0][i], wind: <double>[6.0, 4.0, 9.0, 3.0, 5.0, 4.0, 2.0, 3.0][i], gust: <double>[12.0, 8.0, 19.0, 6.0, 9.0, 7.0, 4.0, 6.0][i], gustNext12: <double>[14.0, 9.0, 21.0, 7.0, 9.0, 8.0, 5.0, 7.0][i], code: [73, 71, 3, 2, 73, 2, 3, 71][i])]),
        '26_ski', size: const Size(412, 1900));
    final n0 = DateTime.now();
    // İklim: sentetik 30 yıllık seri (yalnızca test; uygulamada ERA5 arşivinden)
    final ct = <String>[]; final cx = <double?>[]; final cn = <double?>[]; final cs = <double?>[];
    for (var d = DateTime.utc(1995); d.year < 2025; d = d.add(const Duration(days: 1))) {
      final b0 = 6 - 15 * cos(2 * pi * (ClimateNormals.doy(d) - 20) / 365);
      ct.add(d.toIso8601String().substring(0, 10)); cx.add(b0 + 5 + (d.year == 2010 ? 3 : 0) - (d.year == 2003 ? 6 : 0)); cn.add(b0 - 6 - (d.year == 2003 ? 8 : 0));
      cs.add(b0 < 1 ? (d.day % 3 == 0 ? 2.4 : 0) : 0);
    }
    final sd = <String>[]; final sv = <double?>[];
    for (var d = DateTime(n0.year, n0.month >= 9 ? 9 : 9, 1).subtract(Duration(days: n0.month >= 9 ? 0 : 365)); !d.isAfter(n0); d = d.add(const Duration(days: 1))) {
      sd.add(d.toIso8601String().substring(0, 10)); sv.add(d.month >= 11 && d.day % 4 == 0 ? 3.0 : 0);
    }
    final recent = [for (var i = 30; i >= 1; i--) () {
      final d = DateTime(n0.year, n0.month, n0.day).subtract(Duration(days: i));
      final b0 = 6 - 15 * cos(2 * pi * (ClimateNormals.doy(d) - 20) / 365);
      return DayPoint(date: d, tMax: b0 + 5 + 6 * sin(i / 4), tMin: b0 - 6, precipSum: i % 5 == 0 ? 3 : 0, snowSum: i % 5 == 0 && b0 < 4 ? 4 : 0, windMax: 0, weatherCode: 0);
    }()];
    await shot(t, ClimateScreen(s: s, normals: ClimateNormals.compute(ct, cx, cn, cs), season: SeasonSnow.fromDaily(sd, sv), recent: recent), '23_climate', size: const Size(412, 1900));
    await shot(t, AirScreen(s: s, data: [for (var i = -24; i < 72; i++) AirPoint(DateTime(n0.year, n0.month, n0.day, n0.hour).add(Duration(hours: i)),
        28 + 14 * sin(i / 5) + (i > 30 && i < 40 ? 18 : 0), 9 + 5 * sin(i / 5), 22 + 8 * sin(i / 5), 55 + 20 * sin(i / 7), 14 + 9 * sin(i / 4))]), '24_air', size: const Size(412, 1100));
    await shot(t, const LabScreen(), '03_lab');
    await shot(t, const Paywall(), '04_paywall');
    await shot(t, const SettingsScreen(), '05_settings');
    final n = fake(k: PrecipKind.none, day: false, t: 6);
    WeatherController.I.debugSet(n, WeatherEngine.analyze(n));
    await shot(t, const AppShell(), '06_weather_night');
    WeatherSnapshot variant(double t0, double cloud, int code, double precip, bool day, {double snowDepth = 0, double wind = 4, GeoPoint2? at}) => WeatherSnapshot(
        place: at ?? s.place, fetchedAt: s.fetchedAt, temp: t0, feelsLike: t0 - 1, humidity: 60, dewPoint: t0 - 6, pressure: 1014, windSpeed: wind, windDir: 230, windGust: wind * 1.5,
        cloudCover: cloud, cloudHigh: 10, precip: precip, snowfall: 0, visibilityM: 15000, cape: code >= 95 ? 1400 : 100, uv: day ? 5 : 0, freezingLevelM: 2600, snowDepthM: snowDepth,
        weatherCode: code, isDay: day, hourly: s.hourly, daily: s.daily);
    for (final (name, v) in [('06b_clear', variant(19, 25, 1, 0, true)), ('06c_rain', variant(9, 95, 63, 2.4, true, wind: 9)), ('06d_hot', variant(34, 10, 0, 0, true)), ('06e_overcast', variant(12, 92, 3, 0, true)),
        // Gün batımı / mavi saat: güneşin şu an tam o yükseklikte battığı boylam (çalıştırma saatinden bağımsız)
        ('06f_golden', variant(4, 30, 1, 0, true, snowDepth: .1, at: GeoPoint2(39.9, _lonForSun(3), elevation: 1850, name: 'Gün batımı'))),
        ('06g_bluehour', variant(2, 20, 0, 0, false, snowDepth: .1, at: GeoPoint2(39.9, _lonForSun(-3.5), elevation: 1850, name: 'Mavi saat'))),
        // Karanlık, açık gece: gerçek yıldızlar ve gezegenler
        ('06h_starry', variant(-4, 5, 0, 0, false, snowDepth: .1, at: GeoPoint2(39.9, _lonForSun(-35), elevation: 1850, name: 'Yıldızlı gece')))]) {
      WeatherController.I.debugSet(v, WeatherEngine.analyze(v));
      await shot(t, const AppShell(), name, size: const Size(412, 560));
    }
    // Fırtına: ilk şimşek çakışının tam anı (sahne saati açılıştan beri geçen saniye)
    final storm = variant(17, 96, 95, 6, true, wind: 11);
    WeatherController.I.debugSet(storm, WeatherEngine.analyze(storm));
    var strike = 2.0;
    while (Lightning.at(strike) == null || Lightning.at(strike)!.$2 < .9) { strike += .01; }
    await shot(t, const AppShell(), '06i_thunder', size: const Size(412, 560), extra: Duration(milliseconds: ((strike - 1.5) * 1000).round() + 20));
    // Sis: nemli, durgun, görüş 250 m
    final fogSnap = WeatherSnapshot(place: s.place, fetchedAt: s.fetchedAt, temp: 3, feelsLike: 2, humidity: 99, dewPoint: 2.9, pressure: 1022, windSpeed: 1.2, windDir: 90, windGust: 2,
        cloudCover: 55, cloudHigh: 0, precip: 0, snowfall: 0, visibilityM: 250, cape: 0, uv: 1, freezingLevelM: 2000, snowDepthM: 0, weatherCode: 45, isDay: true, hourly: s.hourly, daily: s.daily);
    WeatherController.I.debugSet(fogSnap, WeatherEngine.analyze(fogSnap));
    await shot(t, const AppShell(), '06j_fog', size: const Size(412, 560));
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: RoadScreen())), '07_road');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: RoadScreen())), '07b_road_full', size: const Size(412, 1500));
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08_sky');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08b_sky_full', size: const Size(412, 1500));
    final clear = fake(k: PrecipKind.none, day: false, t: 6);
    WeatherController.I.debugSet(WeatherSnapshot(place: clear.place, fetchedAt: clear.fetchedAt, temp: 6, feelsLike: 3, humidity: 60, dewPoint: 0, pressure: 1016, windSpeed: 3, windDir: 200, windGust: 5,
        cloudCover: 10, cloudHigh: 0, precip: 0, snowfall: 0, visibilityM: 20000, cape: 0, uv: 0, weatherCode: 0, isDay: false, hourly: clear.hourly, daily: clear.daily), WeatherEngine.analyze(clear));
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08c_sky_clear');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: Map3DScreen())), '09_map3d');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: PlaneRadarScreen())), '10_planes');
    await shot(t, const BadgesScreen(), '11_badges');
    await shot(t, const SleepMixerScreen(), '12_mixer');
    await shot(t, const SosScreen(), '13_sos');
    await shot(t, const TimeCapsuleScreen(), '14_capsule');
    // Canlı pencere en sonda: ses eklentisi test ortamında yok, hata sonraki görüntüleri kesmesin
    WeatherController.I.debugSet(s, an);
    await shot(t, LiveWindow(s: s, a: an, wx: Wx.snow, today: s.daily.first), '18_live');
  });
}
void _noop() {}
