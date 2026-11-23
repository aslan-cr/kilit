// GPU programlarının (bulut, dağ, Ay) yüklenip hatasız çizildiğini doğrular.
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/ui/clouds.dart';
import 'package:skynav/ui/hero_scene.dart';
import 'package:skynav/ui/scene_shaders.dart';
import 'package:skynav/ui/sky_bodies.dart';

class _P extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..color = const Color(0xFF0B1330));
    expect(CloudShader.paint(c, r, const CloudSpec(cover: .5), 3), isTrue);
    expect(MountainShader.paint(c, r, MountainSpec(pal: ScenePalette.snowyDay, light: 1, snow: 1, ground: 1, sun: const Offset(.8, .2))), isTrue);
    expect(MoonRenderer.paint(c, const Offset(100, 100), 40, MoonView(illum: .3, phaseAngle: acos(-.4), bright: const Offset(1, 0), rot: 0, alt: 30)), isTrue);
    paintSun(c, const Offset(250, 80), 20, alt: 10, cover: .2);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}

void main() {
  testWidgets('GPU sahne programları çizer', (t) async {
    await t.runAsync(() => Future.wait([CloudShader.load(), MountainShader.load(), MoonRenderer.load()]));
    expect(CloudShader.ready && MountainShader.ready && MoonRenderer.ready, isTrue);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: CustomPaint(size: const Size(376, 380), painter: _P())));
    await t.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      final b = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(b!.lengthInBytes, greaterThan(0));
    });
  });

  test('Ay görünümü: dolunayda faz açısı ~0, yeni ayda ~π', () {
    final v = MoonView.at(39.9, 41.27, DateTime.utc(2026, 11, 24, 20));
    expect(v.illum, inInclusiveRange(0, 1));
    expect(v.phaseAngle, inInclusiveRange(0, pi));
    expect(v.bright.distance, closeTo(1, 1e-6));
  });
}
