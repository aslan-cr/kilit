// Play öne çıkan görseli için sahne (1024×500): flutter test test/shots/feature_graphic_test.dart → /tmp/store/feature_*.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/ui/clouds.dart';
import 'package:skynav/ui/hero_scene.dart';
import 'package:skynav/ui/scene_shaders.dart';
import 'package:skynav/ui/sky_bodies.dart';

Future<void> _render(WidgetTester t, Widget w, String name) async {
  await t.binding.setSurfaceSize(const Size(1024, 500));
  t.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await t.pumpWidget(RepaintBoundary(key: key, child: Directionality(textDirection: TextDirection.ltr, child: w)));
  for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 250)); }
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('/tmp/store').createSync(recursive: true);
    File('/tmp/store/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('öne çıkan görsel sahneleri', (t) async {
    await t.runAsync(() => Future.wait([CloudShader.load(), MountainShader.load(), MoonRenderer.load()]));
    await _render(t, const DecorScene(pal: ScenePalette.clearNight, night: true, height: 500, cover: .22, light: .45, sun: Offset(.78, .3)), 'feature_night');
    await _render(t, const DecorScene(pal: ScenePalette.snowyDay, height: 500, cover: .3, sun: Offset(.8, .25)), 'feature_day');
  });
}
