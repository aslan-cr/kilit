// Büyük sistem yazısında (1,25 kat; uygulamanın üst sınırı) ekranlar taşmıyor mu?
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/engine/weather_engine.dart';
import 'package:skynav/services/store.dart';
import 'package:skynav/services/weather_repository.dart';
import 'package:skynav/ui/app_shell.dart';
import 'package:skynav/ui/best_time_screen.dart';
import 'package:skynav/ui/detail_screens.dart';
import 'package:skynav/ui/places_screen.dart';
import 'package:skynav/ui/ski_screen.dart';
import 'package:skynav/ui/compare_screen.dart';
import 'package:skynav/ui/air_screen.dart';
import 'package:skynav/services/ski_service.dart';
import 'package:skynav/services/air_service.dart';
import 'package:skynav/ui/theme.dart';
import 'package:skynav/ui/weather_screen.dart' show SkyMoonPage, ToolsPage;
import 'shots_test.dart' show fake;

void main() {
  setUpAll(() async {
    Future<void> font(String family, List<String> files) async {
      final l = FontLoader(family);
      for (final f in files) { final b = File(f).readAsBytesSync(); l.addFont(Future.value(ByteData.view(b.buffer))); }
      await l.load();
    }
    const d = '/usr/share/fonts/opentype/inter';
    await font('Inter', ['$d/Inter-Regular.otf', '$d/Inter-Medium.otf', '$d/Inter-SemiBold.otf', '$d/Inter-Bold.otf', '$d/Inter-ExtraBold.otf', '$d/Inter-Black.otf']);
    await font('Roboto', ['$d/Inter-Regular.otf', '$d/Inter-Bold.otf']);
    await font('MaterialIcons', ['/tmp/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await font('InterDisplay', ['$d/InterDisplay-Light.otf', '$d/InterDisplay-Medium.otf']);
    final tmp = Directory.systemTemp.createTempSync('hive');
    await Store.init(testPath: tmp.path);
    await Store.put('onboarding_done', true);
  });

  testWidgets('büyük yazıda taşma yok', (t) async {
    final s = fake();
    final a = WeatherEngine.analyze(s);
    WeatherController.I.debugSet(s, a);
    final errors = <String>[];
    final old = FlutterError.onError;
    var cur = '';
    FlutterError.onError = (d) {
      final m = d.exceptionAsString();
      if (!m.contains('overflowed')) return;
      final loc = RegExp(r'file:///[^\s]*lib/(ui/[^\s:]+:\d+)').firstMatch(d.toString())?.group(1) ?? '?';
      errors.add('[$cur] $loc ${m.split('\n').first.replaceAll('A RenderFlex overflowed by ', '')}');
      if (const bool.fromEnvironment('DUMP') && loc.contains(const String.fromEnvironment('DUMPLOC', defaultValue: '~'))) {
        // ignore: avoid_print
        print('DUMP ${d.toString().split('\n').where((l) => l.contains('constraints') || l.contains('size:') || l.contains('creator')).take(6).join(' | ')}');
      }
    };
    final scale = double.parse(const String.fromEnvironment('SCALE', defaultValue: '1.25'));
    final width = double.parse(const String.fromEnvironment('W', defaultValue: '360'));
    t.platformDispatcher.textScaleFactorTestValue = scale;
    await t.binding.setSurfaceSize(Size(width, 780)); // küçük telefon
    for (final (name, w) in <(String, Widget)>[
      ('ana', const AppShell()),
      ('gün', DayDetailScreen(s: s, day: s.daily[1], index: 1)),
      ('grafik', TrendScreen(s: s)),
      ('ay', MoonDetailScreen(lat: s.place.lat, lon: s.place.lon)),
      ('gök', SkyMoonPage(s: s, a: a)),
      ('araçlar', const ToolsPage()),
      ('en iyi', BestTimeScreen(s: s)),
      ('yerler', PlacesScreen(fetch: (p) async => PlaceNow(place: p, temp: -3, tMax: 0, tMin: -8, wind: 4, precip: .4, cloud: 95, code: 73, isDay: true))),
      ('kayak', SkiScreen(here: s.place, data: [for (final r in skiResorts) SkiNow(r, snowCm: 120, new24: 14, next72: 38, temp: -12, wind: 9, gust: 19, gustNext12: 22, code: 73)])),
      ('kıyas', CompareScreen(a: PlaceNow(place: const GeoPoint2(39.9, 41.27, name: 'Doğubayazıt, Ağrı'), temp: -12, tMax: -8, tMin: -21, wind: 4, precip: 0, cloud: 0, code: 0, isDay: true, days: s.daily),
          b: PlaceNow(place: const GeoPoint2(39.95, 41.1, name: 'Anneannemin köyü'), temp: -15, tMax: -10, tMin: -24, wind: 3, precip: 0, cloud: 0, code: 73, isDay: true, days: s.daily))),
      ('hava', AirScreen(s: s, data: [for (var i = 0; i < 72; i++) AirPoint(DateTime.now().add(Duration(hours: i - 24)), 64.0 + i % 9, 31, 70, 120, 44)])),
    ]) {
      cur = name;
      await t.pumpWidget(MaterialApp(theme: buildTheme(), home: w));
      for (var i = 0; i < 4; i++) { await t.pump(const Duration(milliseconds: 250)); }
      // Uzun sayfaları sona kadar kaydır ki tüm kutular çizilsin
      final sc = find.byType(Scrollable);
      if (sc.evaluate().isNotEmpty) {
        for (var i = 0; i < 12; i++) { await t.drag(sc.first, const Offset(0, -600)); await t.pump(const Duration(milliseconds: 100)); }
      }
    }
    FlutterError.onError = old;
    t.platformDispatcher.clearTextScaleFactorTestValue();
    // ignore: avoid_print
    print('TAŞMALAR:\n${errors.toSet().join('\n')}');
    expect(errors, isEmpty);
  });

  testWidgets('ekran okuyucu: çizimli blokların açıklaması var', (t) async {
    final h = t.ensureSemantics();
    final s = fake();
    WeatherController.I.debugSet(s, WeatherEngine.analyze(s));
    await t.binding.setSurfaceSize(const Size(412, 4900));
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: const AppShell()));
    for (var i = 0; i < 4; i++) { await t.pump(const Duration(milliseconds: 250)); }
    expect(find.bySemanticsLabel(RegExp('^Saatlik sıcaklık: şimdi')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Rüzgâr .* yönünden')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Gün doğumu')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Donma seviyesi')), findsOneWidget);
    h.dispose();
  });
}
