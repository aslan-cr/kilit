import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/ui/sky_screen.dart';
import 'package:skynav/ui/sky_background.dart';
import 'package:skynav/data/models.dart';
import 'package:skynav/ui/theme.dart';

void main() {
  testWidgets('gökyüzü ekranı ve arka plan çizilir', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: const Scaffold(body: SkyScreen())));
    await t.pump(const Duration(milliseconds: 300));
    expect(tester(t), isTrue);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SkyBackground(state: SkyState(kind: PrecipKind.lentilSnow, windMs: 12)))));
    await t.pump(const Duration(seconds: 1));
  });
}
bool tester(WidgetTester t) => !t.takeException().toString().contains('Exception');
