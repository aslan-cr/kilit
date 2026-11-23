import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// GPU programlarını her cihazda aynı biçimde çalıştırır.
///
/// Skia'da FlutterFragCoord yerel (mantıksal) koordinat verir; Impeller'da ise çizim hedefinin
/// fiziksel pikselini. Doğrudan ekrana çizilen bir program bu yüzden telefonda kayar, büyür
/// ya da kırpılır. Çözüm: programlar her zaman dönüşümsüz, (0,0)'dan başlayan ekran dışı bir
/// görüntüye çizilir (iki motorda da koordinat = görüntü pikseli); mantıksal birime dönüş
/// shader içinde [px] (görüntü pikseli / mantıksal px) ile yapılır. Sonra görüntü yerine çizilir.
///
/// Açılışta küçük bir ölçüm programı koordinatları okur: y ekseni bu GPU'da tersse [flip] açılır,
/// beklenmedik bir şey varsa [broken] olur ve tüm sahne eski (kanvas) çizime döner.
class Gpu {
  static bool flip = false;
  static bool broken = false;
  static final List<String> failed = [];
  static Future<void>? _cal;

  static double get dpr => ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2;

  /// [sh]'yi w×h piksellik ekran dışı görüntüye çizer.
  static ui.Image render(ui.FragmentShader sh, int w, int h) {
    w = max(1, w); h = max(1, h);
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..shader = sh);
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return img;
  }

  /// Görüntüyü [dst] dikdörtgenine çizer.
  static void draw(Canvas c, ui.Image img, Rect dst, {double opacity = 1}) => c.drawImageRect(
      img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
      Paint()..filterQuality = FilterQuality.medium..color = Color.fromRGBO(0, 0, 0, opacity));

  /// Önceden çarpılmış RGBA pikseller (doğrulama için).
  static Future<Uint8List?> pixels(ui.Image img) async =>
      (await img.toByteData(format: ui.ImageByteFormat.rawRgba))?.buffer.asUint8List();

  /// (x, y) pikselinin [r, g, b, a] değeri (0..255, önceden çarpılmış).
  static List<int> at(Uint8List px, int w, int x, int y) { final i = (y * w + x) * 4; return [px[i], px[i + 1], px[i + 2], px[i + 3]]; }

  /// Koordinat ölçümü (bir kez).
  static Future<void> calibrate() => _cal ??= () async {
        try {
          final p = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
          final sh = p.fragmentShader()..setFloat(0, 64);
          final img = render(sh, 64, 64);
          sh.dispose();
          final px = await pixels(img);
          img.dispose();
          if (px == null) { broken = true; failed.add('ölçüm okunamadı'); return; }
          // Pikselin merkezi: (8.5, 48.5) → r ≈ 34, g ≈ 194 (ters y'de g ≈ 62)
          final v = at(px, 64, 8, 48);
          final xOk = (v[0] - 34).abs() <= 3;
          if (xOk && (v[1] - 194).abs() <= 3) { flip = false; return; }
          if (xOk && (v[1] - 62).abs() <= 3) { flip = true; return; }
          broken = true;
          failed.add('koordinat ${v.take(2).join(',')}');
        } catch (_) {
          // Ölçüm programı yoksa (eski kurulum) mevcut davranışla devam.
        }
      }();

  /// Programın açılış testini çalıştırır; başarısızsa false ve Tanılama'ya not düşer.
  static Future<bool> verify(String name, Future<bool> Function() test) async {
    if (broken) return false;
    try {
      if (await test()) return true;
    } catch (_) {}
    failed.add(name);
    return false;
  }

  /// Tanılama satırı: GPU çiziminin bu cihazdaki durumu.
  static String get summary => broken
      ? 'GPU çizimi: doğrulanamadı, yedek çizim (${failed.join(', ')})'
      : 'GPU çizimi: ${flip ? 'y ters (düzeltildi)' : 'normal'}${failed.isEmpty ? ' · tüm programlar doğrulandı' : ' · yedek çizim: ${failed.join(', ')}'}';

  /// Önceden çarpılmış pikselden "yeşil baskın mı" (test renkleri yeşil seçilir).
  static bool greenish(List<int> v) {
    if (v[3] < 40) return false;
    final r = v[0] * 255 / v[3], g = v[1] * 255 / v[3], b = v[2] * 255 / v[3];
    return g > r + 35 && g > b + 35;
  }
}
