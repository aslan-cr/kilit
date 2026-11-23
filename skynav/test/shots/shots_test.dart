// Ekran görüntüsü düzeneği: `flutter test test/shots --dart-define=SHOTS=1`
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/weather_engine.dart';
import 'package:skynav/services/store.dart';
import 'package:skynav/services/location_service.dart';
import 'package:skynav/services/weather_repository.dart';
import 'package:skynav/ui/app_shell.dart';
import 'package:skynav/ui/lab_screen.dart';
import 'package:skynav/ui/map3d_screen.dart';
import 'package:skynav/ui/plane_radar_screen.dart';
import 'package:skynav/ui/onboarding.dart';
import 'package:skynav/ui/paywall.dart';
import 'package:skynav/ui/settings_screen.dart';
import 'package:skynav/ui/road_screen.dart';
import 'package:skynav/ui/sky_screen.dart';
import 'package:skynav/ui/sky_background.dart';
import 'package:skynav/ui/clouds.dart';
import 'package:skynav/ui/scene_shaders.dart';
import 'package:skynav/ui/sky_bodies.dart';
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
    hourly: [for (var i = -3; i < 24; i++) HourPoint(time: now.add(Duration(hours: i)), temp: t + _ht[(i + 24) % 24] + 2, precip: _hp[(i + 24) % 24], snowfall: _hp[(i + 24) % 24] * .9, windSpeed: 5, windDir: 300, cloud: 70, humidity: 85, dewPoint: t - 3, weatherCode: _hp[(i + 24) % 24] > 0 ? 73 : 3, pressure: 1012 + i * .1)],
    daily: [for (var i = 0; i < 7; i++) DayPoint(date: now.add(Duration(days: i)), tMax: t + 3 + i, tMin: t - 5 + i * .5, precipSum: i.isEven ? 3 : 0, snowSum: i.isEven ? 4 : 0, windMax: 9, weatherCode: i.isEven ? 73 : 2,
        sunrise: DateTime(now.year, now.month, now.day, 7, 48), sunset: DateTime(now.year, now.month, now.day, 17, 19))],
    ensembleMembers: 82, ensembleSnowProb: 74, ensembleRainProb: 12, modelTemp24h: const {'ecmwf': -2.4, 'gfs': -1.8, 'icon': -2.9, 'gem': -2.1}, modelPrecip24h: const {'ecmwf': 4.1, 'gfs': 3.2, 'icon': 5.0, 'gem': 3.6},
    aqPm10: 18, mountains: const [Mountain(lat: 40, lon: 41.1, elevation: 3140, distanceKm: 25, bearingDeg: 300, snowDepthM: .8, tempC: -12)],
  );
}

const _ht = <double>[-4, -4, -3, -3, -2, -1, 0, 1, 1, 0, -1, -2, -3, -3, -4, -5, -5, -6, -6, -5, -5, -4, -4, -3];
const _hp = <double>[.5, .6, .3, 0, 0, 0, .2, .8, 1.2, .9, .4, 0, 0, 0, .3, .7, .5, .2, 0, 0, 0, .4, .6, .3];

Future<void> shot(WidgetTester t, Widget w, String name, {Size size = const Size(412, 915)}) async {
  await t.binding.setSurfaceSize(size);
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: w)));
  for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 250)); }
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
    ]))), '00_widgets', size: const Size(412, 600));
    await shot(t, const Onboarding(onDone: _noop), '01_onboarding');
    await shot(t, const AppShell(), '02_weather');
    await shot(t, const AppShell(), '02b_weather_full', size: const Size(412, 4600));
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
        // Gün batımı / mavi saat testi için güneşin şu an alçakta olduğu boylamlar (çalıştırma saatine göre ayarla)
        ('06f_golden', variant(4, 30, 1, 0, true, snowDepth: .1, at: const GeoPoint2(39.9, 15.6, elevation: 1850, name: 'Gün batımı'))),
        ('06g_bluehour', variant(2, 20, 0, 0, false, snowDepth: .1, at: const GeoPoint2(39.9, 24.0, elevation: 1850, name: 'Mavi saat')))]) {
      WeatherController.I.debugSet(v, WeatherEngine.analyze(v));
      await shot(t, const AppShell(), name, size: const Size(412, 560));
    }
    await shot(t, const Scaffold(body: Stack(children: [Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30))), SafeArea(child: RoadScreen())])), '07_road');
    await shot(t, const Scaffold(body: Stack(children: [Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30))), SafeArea(child: RoadScreen())])), '07b_road_full', size: const Size(412, 1500));
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08_sky');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08b_sky_full', size: const Size(412, 1500));
    final clear = fake(k: PrecipKind.none, day: false, t: 6);
    WeatherController.I.debugSet(WeatherSnapshot(place: clear.place, fetchedAt: clear.fetchedAt, temp: 6, feelsLike: 3, humidity: 60, dewPoint: 0, pressure: 1016, windSpeed: 3, windDir: 200, windGust: 5,
        cloudCover: 10, cloudHigh: 0, precip: 0, snowfall: 0, visibilityM: 20000, cape: 0, uv: 0, weatherCode: 0, isDay: false, hourly: clear.hourly, daily: clear.daily), WeatherEngine.analyze(clear));
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: SkyScreen())), '08c_sky_clear');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: Map3DScreen())), '09_map3d');
    await shot(t, const Scaffold(backgroundColor: kIce, body: SafeArea(child: PlaneRadarScreen())), '10_planes');
  });
}
void _noop() {}
