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
import 'package:skynav/services/weather_repository.dart';
import 'package:skynav/ui/app_shell.dart';
import 'package:skynav/ui/lab_screen.dart';
import 'package:skynav/ui/onboarding.dart';
import 'package:skynav/ui/paywall.dart';
import 'package:skynav/ui/settings_screen.dart';
import 'package:skynav/ui/road_screen.dart';
import 'package:skynav/ui/sky_screen.dart';
import 'package:skynav/ui/sky_background.dart';
import 'package:skynav/ui/theme.dart';

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
    hourly: [for (var i = 0; i < 24; i++) HourPoint(time: now.add(Duration(hours: i)), temp: t + (i % 8) * .6 - 2, precip: i % 5 == 0 ? .8 : 0, snowfall: i % 4 == 0 ? .5 : 0, windSpeed: 5, windDir: 300, cloud: 70, humidity: 85, dewPoint: t - 3, weatherCode: i % 3 == 0 ? 73 : 3)],
    daily: [for (var i = 0; i < 7; i++) DayPoint(date: now.add(Duration(days: i)), tMax: t + 3 + i, tMin: t - 5 + i * .5, precipSum: i.isEven ? 3 : 0, snowSum: i.isEven ? 4 : 0, windMax: 9, weatherCode: i.isEven ? 73 : 2)],
    ensembleMembers: 82, ensembleSnowProb: 74, ensembleRainProb: 12, modelTemp24h: const {'ecmwf': -2.4, 'gfs': -1.8, 'icon': -2.9, 'gem': -2.1}, modelPrecip24h: const {'ecmwf': 4.1, 'gfs': 3.2, 'icon': 5.0, 'gem': 3.6},
    aqPm10: 18, mountains: const [Mountain(lat: 40, lon: 41.1, elevation: 3140, distanceKm: 25, bearingDeg: 300, snowDepthM: .8, tempC: -12)],
  );
}

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
    final tmp = Directory.systemTemp.createTempSync('hive');
    await Store.init(testPath: tmp.path);
    await Store.put('onboarding_done', true);
  });

  testWidgets('ekranlar', (t) async {
    final s = fake();
    WeatherController.I.debugSet(s, WeatherEngine.analyze(s));
    await shot(t, const Onboarding(onDone: _noop), '01_onboarding');
    await shot(t, const AppShell(), '02_weather');
    await shot(t, const AppShell(), '02b_weather_full', size: const Size(412, 4200));
    await shot(t, const LabScreen(), '03_lab');
    await shot(t, const Paywall(), '04_paywall');
    await shot(t, const SettingsScreen(), '05_settings');
    final n = fake(k: PrecipKind.none, day: false, t: 6);
    WeatherController.I.debugSet(n, WeatherEngine.analyze(n));
    await shot(t, const AppShell(), '06_weather_night');
    await shot(t, const Scaffold(body: Stack(children: [Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30))), SafeArea(child: RoadScreen())])), '07_road');
    await shot(t, const Scaffold(body: Stack(children: [Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30, isDay: false))), SafeArea(child: SkyScreen())])), '08_sky');
  });
}
void _noop() {}
