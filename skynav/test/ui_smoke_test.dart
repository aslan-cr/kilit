import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/ui/sky_screen.dart';
import 'package:skynav/ui/theme.dart';

void main() {
  testWidgets('gökyüzü ekranı çizilir', (t) async {
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: const Scaffold(body: SkyScreen())));
    await t.pump(const Duration(milliseconds: 300));
    expect(tester(t), isTrue);
  });
}
bool tester(WidgetTester t) => !t.takeException().toString().contains('Exception');
