import 'dart:math';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../astro/astro_math.dart' show sunAltitude, sunRaDec, moonRaDec, raDecToAltAz;
import '../engine/formulas.dart';
import 'clouds.dart';
import 'scene_shaders.dart';
import 'sky_bodies.dart';
import 'sky_stars.dart';
import 'wx_glyph.dart';

/// Ana ekranın üst sahnesi (Figma "Sahne", 376×380): kodla çizilmiş manzara.
/// Gök (saat + hava), güneş/ay, yıldızlar, sivri zirveli üç katman dağ, zirve karı, pus,
/// kayan bulutlar ve rüzgârla eğilen yağış. Üstünde konum hapı, sıcaklık ve durum yazıları.
class HeroScene extends StatefulWidget {
  final WeatherSnapshot s; final Analysis a; final Wx wx; final DayPoint? today;
  final bool offline; final VoidCallback? onPlace;
  final double height;
  /// Köşe yuvarlaklığı (canlı pencerede 0), [live]: tam ekran canlı pencere, [onOpen]: sahneye dokununca.
  final double radius; final bool live; final VoidCallback? onOpen;
  /// Canlı pencerede telefon eğimi (−1…1): katmanlar derinliklerine göre kayar (paralaks).
  final ValueListenable<Offset>? tilt;
  const HeroScene({super.key, required this.s, required this.a, required this.wx, this.today, this.offline = false, this.onPlace, this.height = 380,
      this.radius = 34, this.live = false, this.onOpen, this.tilt});
  @override
  State<HeroScene> createState() => _HeroSceneState();
}

class _HeroSceneState extends State<HeroScene> with SingleTickerProviderStateMixin {
  // Uzun süre: bulut kayması sarma anında zıplamasın.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(hours: 1))..repeat();
  final _parts = _Particles(Random(7));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final name = s.place.name.isEmpty ? 'Konumum' : s.place.name;
    final H = widget.height;
    final pad = widget.live ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    return Semantics(
      label: '$name, ${deg(s.temp)}, ${wxLabel(widget.wx, day: s.isDay)}',
      button: widget.onOpen != null,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          height: H,
          child: Stack(fit: StackFit.expand, children: [
            // Katmanlar: gök + güneş/ay → GPU bulutları → sabit dağ resmi → yağış ve okunurluk perdesi
            LayoutBuilder(builder: (_, box) {
              final W = box.maxWidth;
              final sl = skyLight(s, W, H);
              final look = SceneLook.of(s, widget.wx, sun: Offset(sl.pos.dx / W, sl.pos.dy / H));
              final night = starsOn(s, DateTime.now());
              final fog = fogAmount(s, widget.a, widget.wx);
              Widget layer(_Part part, {bool anim = true}) => RepaintBoundary(child: still || !anim
                  ? CustomPaint(size: Size.infinite, painter: _ScenePainter(s, widget.a, widget.wx, 12, _parts, part))
                  : AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ScenePainter(s, widget.a, widget.wx, _c.value * 3600, _parts, part))));
              // Paralaks: uzak gök az, bulutlar orta, dağlar çok kayar; kenar görünmesin diye hafif büyütülür.
              final tilt = widget.tilt;
              Widget par(double px, Widget child) => tilt == null ? child : ValueListenableBuilder<Offset>(
                  valueListenable: tilt, child: child,
                  builder: (_, o, c) => Transform.translate(offset: o * px, child: Transform.scale(scale: 1.08, child: c)));
              return Stack(fit: StackFit.expand, children: [
                par(5, layer(_Part.back, anim: night)),
                par(9, CloudLayer(spec: look.clouds, animate: !still)),
                par(15, MountainLayer(spec: look.mountains)),
                // Vadide süzülen sis: aynı bulut programı, ters çevrilmiş (yoğun taraf aşağıda, uzakta yassı)
                if (fog > .08) Positioned(left: 0, right: 0, top: H * .36, bottom: 0, child: IgnorePointer(child: par(15, Transform.flip(flipY: true,
                    child: CloudLayer(spec: fogSpec(s, widget.wx, fog, H / 380), animate: !still, resolution: .35))))),
                layer(_Part.front),
              ]);
            }),
            // Konum hapı
            if (!widget.live) Positioned(left: 18, top: 18, child: _PlacePill(name: name, elevation: s.place.elevation, onTap: widget.onPlace)),
            if (widget.offline && !widget.live) const Positioned(right: 16, top: 22, child: _OfflineDot()),
            // Canlı pencereye geçiş ipucu
            if (widget.onOpen != null) Positioned(right: 14, bottom: 16, child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .3))),
              child: const Icon(Icons.open_in_full_rounded, size: 17, color: Colors.white),
            )),
            // Sıcaklık
            Positioned(left: 14, top: 56 + pad.top, child: Text(deg(s.temp), style: const TextStyle(
              fontFamily: 'InterDisplay', fontSize: 104, fontWeight: FontWeight.w300, height: 1, letterSpacing: -5.2, color: Colors.white,
              shadows: [Shadow(color: Color(0x2E0D1F38), offset: Offset(0, 4), blurRadius: 24)],
            ))),
            // Durum ve hissedilen
            Positioned(left: 20, right: widget.onOpen != null ? 60 : 20, top: H - 78 - pad.bottom - (widget.live ? 40 : 0), child: Text(wxLabel(widget.wx, day: s.isDay), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.24, color: Colors.white, height: 1.2))),
            Positioned(left: 20, right: widget.onOpen != null ? 60 : 20, top: H - 46 - pad.bottom - (widget.live ? 40 : 0), child: Text(
              ['Hissedilen ${deg(s.feelsLike)}', if (widget.today != null) '↑ ${deg(widget.today!.tMax)}   ↓ ${deg(widget.today!.tMin)}'].join('   '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: .85), height: 1.3),
            )),
          ]),
        ),
      ),
      ),
    );
  }
}

/// Gökteki ışık kaynağı: gündüz güneş, gece ay (ufkun altındaysa yok). Konum gerçek yükseklik ve yöne göre:
/// alçaldıkça ufka (dağlara) iner; doğudan (solda) batıya (sağda) ilerler ama sıcaklık yazısını kapatmaz.
({Offset pos, bool visible}) skyLight(WeatherSnapshot s, double W, double H, [DateTime? at]) {
  final t = (at ?? DateTime.now()).toUtc();
  final rd = s.isDay ? sunRaDec(t) : moonRaDec(t);
  final aa = raDecToAltAz(rd.raDeg, rd.decDeg, s.place.lat, s.place.lon, t);
  final k = H / 380;
  final along = SceneSky.along(aa.az, s.place.lat); // kuzeyde güneye, güneyde kuzeye bakış
  final x = W * (.60 + .26 * along.clamp(0.0, 1.0));
  final y = H * .40 - (H * .40 - 76 * k) * (aa.alt / 35).clamp(0.0, 1.0); // en yüksekte bile konum hapının altında
  return (pos: Offset(x, y), visible: aa.alt > -1.5);
}

/// Sis yoğunluğu 0..1 (motorun sis olasılığı × yoğunluğu; "Sisli" durumda en az 0,6).
double fogAmount(WeatherSnapshot s, Analysis a, Wx wx) =>
    max((a.fogProb * a.fogDensity / 10000).clamp(0.0, 1.0), wx == Wx.fog ? .6 : 0.0);

/// Vadi sisi için bulut ayarı: pus renginde, alçak, rüzgârla yavaşça süzülen.
CloudSpec fogSpec(WeatherSnapshot s, Wx wx, double fog, double k) {
  final pal = ScenePalette.of(s, wx);
  final to = (s.windDir + 180) * pi / 180;
  final spd = .004 + s.windSpeed.clamp(0, 10) * .0012;
  final lit = Color.lerp(pal.haze, Colors.white, s.isDay ? .35 : 0)!;
  return CloudSpec(cover: (.42 + .45 * fog).clamp(0.0, 1.0), lit: lit, shade: Color.lerp(pal.haze, pal.mid2, .45)!, opacity: (.5 + .4 * fog).clamp(0.0, .92),
      weight: .08, sun: const Offset(.5, -2), wind: Offset(-sin(to) * spd - .003, 0), scale: 110 * k, horizon: .98, seed: 9.1);
}

/// Gece göğünde en az en parlak yıldızlar/gezegenler görünüyor mu (alacakaranlık, Ay, bulut).
bool starsOn(WeatherSnapshot s, DateTime t) =>
    s.cloudCover < 95 && SceneSky.limitAt(s.place.lat, s.place.lon, t, cloud: s.cloudCover) > -1.2;

/// Sıcaklığı gerçek eksi işaretiyle yazar: −2°.
String deg(double v) { final r = v.round(); return '${r < 0 ? '−' : ''}${r.abs()}°'; }

/// Bir ondalıklı sıcaklık, gerçek eksi işaretiyle: −2.6°.
String deg1(double v) { final r = (v * 10).round() / 10; return '${r < 0 ? '−' : ''}${r.abs().toStringAsFixed(1)}°'; }

class _PlacePill extends StatelessWidget {
  final String name; final double? elevation; final VoidCallback? onTap;
  const _PlacePill({required this.name, this.elevation, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
              if (elevation != null) ...[
                const SizedBox(width: 6),
                Text('· ${elevation!.round()} m', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: .8))),
              ],
              Icon(Icons.expand_more_rounded, size: 18, color: Colors.white.withValues(alpha: .8)),
            ]),
          ),
        ),
      );
}

class _OfflineDot extends StatelessWidget {
  const _OfflineDot();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .28), borderRadius: BorderRadius.circular(14)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 14, color: Colors.white), SizedBox(width: 5),
          Text('Çevrimdışı', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      );
}

/// Sahne paleti: gök, üç dağ katmanı (üst/alt renk), pus.
class ScenePalette {
  final Color skyTop, skyBottom, far1, far2, mid1, mid2, near1, near2, haze, sun;
  final double skyStop;
  const ScenePalette({required this.skyTop, required this.skyBottom, this.skyStop = .62, required this.far1, required this.far2,
      required this.mid1, required this.mid2, required this.near1, required this.near2, required this.haze, this.sun = const Color(0xFFFFF6D8)});

  // Figma'daki karlı gündüz paleti.
  static const snowyDay = ScenePalette(skyTop: Color(0xFF6685AB), skyBottom: Color(0xFFC7D6E8), far1: Color(0xFFC5D2DF), far2: Color(0xFFAAB9C9),
      mid1: Color(0xFF8DA2B8), mid2: Color(0xFF73899F), near1: Color(0xFF40566E), near2: Color(0xFF2C3E52), haze: Color(0xFFE3EDF5));
  static const clearDay = ScenePalette(skyTop: Color(0xFF3F8EE6), skyBottom: Color(0xFFC4E2FB), far1: Color(0xFFAECBE3), far2: Color(0xFF93B3CE),
      mid1: Color(0xFF7097B7), mid2: Color(0xFF5A80A0), near1: Color(0xFF2F5872), near2: Color(0xFF21445A), haze: Color(0xFFE4F1FC), sun: Color(0xFFFFF1C2));
  static const hotDay = ScenePalette(skyTop: Color(0xFFF2925A), skyBottom: Color(0xFFFFE2B8), far1: Color(0xFFEBB892), far2: Color(0xFFD99E78),
      mid1: Color(0xFFC4825E), mid2: Color(0xFFAA6A4B), near1: Color(0xFF6B3F2E), near2: Color(0xFF55301F), haze: Color(0xFFFFE9CF), sun: Color(0xFFFFC46B));
  static const greyDay = ScenePalette(skyTop: Color(0xFF8A9DB2), skyBottom: Color(0xFFDCE4EC), far1: Color(0xFFBAC7D4), far2: Color(0xFFA4B3C2),
      mid1: Color(0xFF8397AC), mid2: Color(0xFF6E8297), near1: Color(0xFF3F5167), near2: Color(0xFF2E3D50), haze: Color(0xFFE6ECF2));
  static const wetDay = ScenePalette(skyTop: Color(0xFF6A7D92), skyBottom: Color(0xFFBFCAD6), far1: Color(0xFFA2B0BF), far2: Color(0xFF8E9DAD),
      mid1: Color(0xFF6C7F93), mid2: Color(0xFF5A6C80), near1: Color(0xFF33455A), near2: Color(0xFF243446), haze: Color(0xFFD5DEE7));
  static const clearNight = ScenePalette(skyTop: Color(0xFF0B1330), skyBottom: Color(0xFF2C3C78), skyStop: .8, far1: Color(0xFF3A4B82), far2: Color(0xFF2E3D6E),
      mid1: Color(0xFF26345F), mid2: Color(0xFF1D2950), near1: Color(0xFF141C3D), near2: Color(0xFF0E1530), haze: Color(0xFF34457E), sun: Color(0xFFF4ECCF));
  static const greyNight = ScenePalette(skyTop: Color(0xFF1C2434), skyBottom: Color(0xFF3E4A60), skyStop: .8, far1: Color(0xFF4C586E), far2: Color(0xFF414C60),
      mid1: Color(0xFF343E52), mid2: Color(0xFF2A3344), near1: Color(0xFF1C2333), near2: Color(0xFF141A27), haze: Color(0xFF465268), sun: Color(0xFFF4ECCF));

  // Gün doğumu/batımı (güneş ufkun 0–7° üstünde) ve mavi saat (ufkun 0–6° altında): yalnızca açık/parçalı havada.
  static const goldenHour = ScenePalette(skyTop: Color(0xFF3E5C9E), skyBottom: Color(0xFFF7AE84), skyStop: .78, far1: Color(0xFFBC9DB0), far2: Color(0xFFA0849B),
      mid1: Color(0xFF806C89), mid2: Color(0xFF695872), near1: Color(0xFF3B324A), near2: Color(0xFF2A2337), haze: Color(0xFFF4C0A2), sun: Color(0xFFFFC27E));
  static const blueHour = ScenePalette(skyTop: Color(0xFF1C2A5E), skyBottom: Color(0xFFD99488), skyStop: .85, far1: Color(0xFF6E6A92), far2: Color(0xFF5C587E),
      mid1: Color(0xFF47456C), mid2: Color(0xFF3A3859), near1: Color(0xFF1F1D36), near2: Color(0xFF16142A), haze: Color(0xFF8C7E9E), sun: Color(0xFFF4ECCF));

  /// Güneşin ufuktan yüksekliği (°), gerçek konum ve saatten.
  static double sunAlt(WeatherSnapshot s, [DateTime? at]) => sunAltitude(s.place.lat, s.place.lon, (at ?? DateTime.now()).toUtc());

  static ScenePalette of(WeatherSnapshot s, Wx wx) {
    final snowy = {Wx.snow, Wx.lentil, Wx.blizzard, Wx.sleet}.contains(wx);
    final wet = {Wx.rain, Wx.thunder, Wx.drizzle}.contains(wx);
    if (s.cloudCover < 70 && !snowy && !wet && wx != Wx.fog) {
      final alt = sunAlt(s);
      if (s.isDay && alt < 7 && alt > -2) return goldenHour;
      if (!s.isDay && alt > -6 && alt <= 0) return blueHour;
    }
    if (!s.isDay) return s.cloudCover < 60 && !snowy && !wet ? clearNight : greyNight;
    if (snowy) return snowyDay;
    if (wet) return wetDay;
    if (wx == Wx.overcast || wx == Wx.cloudy || wx == Wx.fog) return greyDay;
    if (s.temp >= 30) return hotDay;
    return clearDay;
  }
}

/// Her karede yeniden üretilmesin diye sabit parçacık tohumları.
class _Particles {
  final List<(double, double, double, double)> drops; // x, y, derinlik, faz (0-1)
  _Particles(Random r)
      : drops = [for (var i = 0; i < 170; i++) (r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble())];
}

/// Ana ekran widget'ı gibi küçük yüzeyler için hareketsiz sahne.
class SceneStill extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a;
  const SceneStill({super.key, required this.s, required this.a});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _ScenePainter(s, a, wxFromNow(s, a), 12, _Particles(Random(7)), _Part.all));
}

enum _Part { back, front, all }

class _ScenePainter extends CustomPainter {
  final WeatherSnapshot s; final Analysis a; final Wx wx; final double t; final _Particles p; final _Part part;
  _ScenePainter(this.s, this.a, this.wx, this.t, this.p, this.part);

  static const _fw = 376.0; // Figma sahne genişliği

  /// Sivri zirveler: |sin| tabanlı tepe + ikincil tepe + ince doku (Figma'daki formül).
  static double _ridge(double u, List<double> k) {
    final peaks = pow(1 - sin(u * k[0] + k[1]).abs(), k[2]).toDouble();
    final second = pow(1 - sin(u * k[3] + k[4]).abs(), 2).toDouble() * k[5];
    return min(1.0, peaks * .85 + second + .04 * sin(u * 61 + k[1]));
  }

  @override
  void paint(Canvas c, Size sz) {
    final W = sz.width, H = sz.height, sx = W / _fw, k = H / 380; // k: yükseklik ölçeği (sahne 380 px)
    final pal = ScenePalette.of(s, wx);
    final night = !s.isDay;
    final rect = Offset.zero & sz;
    if (part != _Part.front) _back(c, sz, pal, W, H, sx, k, night, rect);
    if (part == _Part.front) { _front(c, sz, pal, W, H, k); return; }
    if (part == _Part.all) {
      // Tek seferlik çizim (widget görüntüsü): bulut ve dağ shader'ları doğrudan çizilir.
      final sl = skyLight(s, W, H);
      final look = SceneLook.of(s, wx, sun: Offset(sl.pos.dx / W, sl.pos.dy / H), cloudScale: 150 * k);
      if (!CloudShader.paint(c, rect, look.clouds, t)) _canvasClouds(c, W, k, sx, night, (s.cloudCover / 100).clamp(0.0, 1.0));
      if (!MountainShader.paint(c, rect, look.mountains)) _canvasMountains(c, pal, W, H, sx, k, night);
      _front(c, sz, pal, W, H, k);
    }
  }

  void _back(Canvas c, Size sz, ScenePalette pal, double W, double H, double sx, double k, bool night, Rect rect) {
    // Gök
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [pal.skyTop, pal.skyBottom], stops: [0, pal.skyStop]).createShader(rect));

    // Gerçek gece göğü: o an görünen parlak yıldızlar ve gezegenler (alacakaranlık, Ay ışığı ve buluta göre sönük olanlar kaybolur)
    if (s.cloudCover < 95) {
      final now = DateTime.now();
      final lim = SceneSky.limitAt(s.place.lat, s.place.lon, now, cloud: s.cloudCover);
      if (lim > -4.5) {
        SceneSky.paint(c, sz, SceneSky.at(s.place.lat, s.place.lon, now),
            horizonY: H * .64, t: t, lim: lim, fade: 1 - s.cloudCover / 100 * .55, scale: (k * .5 + .5).clamp(.6, 1.2));
      }
    }

    // Güneş / ay (Figma: merkez 310,70; ışıltı yarıçapı 110)
    final sl = skyLight(s, W, H);
    final disc = sl.pos;
    final cover = (s.cloudCover / 100).clamp(0.0, 1.0);
    if (!sl.visible) {
      // Ay ufkun altında: çizilmez (uydurma ay yok).
    } else if (!night) {
      // Gerçekçi güneş: yüksekliğe göre renk, ufukta basık disk, çok katmanlı parlama
      paintSun(c, disc, 22 * k, alt: ScenePalette.sunAlt(s), cover: cover);
    } else {
      // Gerçek Ay: NASA LRO haritası, gözlemciye göre evre ve eğim
      final mv = MoonView.at(s.place.lat, s.place.lon, DateTime.now());
      if (!MoonRenderer.paint(c, disc, 24 * k, mv, alpha: (1 - cover * .75).clamp(.25, 1.0))) _moon(c, disc, k);
    }

    // Yedek: GPU programları yüklenemezse eski kodla çizilmiş bulut ve dağlar.
    if (part == _Part.back && !CloudShader.ready) _canvasClouds(c, W, k, sx, night, cover);
    if (part == _Part.back && !MountainShader.ready) _canvasMountains(c, pal, W, H, sx, k, night);
  }

  void _canvasClouds(Canvas c, double W, double k, double sx, bool night, double cover) {
    // Bulutlar: Figma'daki üç küme, örtüye göre sayı ve saydamlık; rüzgâr yönünde süzülür.
    final dir = sin((s.windDir + 180) * pi / 180) >= 0 ? 1.0 : -1.0;
    final drift = t * (2 + s.windSpeed.clamp(0, 20) * .6) * dir;
    final clouds = <(double, double, double, double)>[
      (14, 98, 150, .55), (210, 120, 120, .6), (120, 30, 90, .5), (-40, 150, 110, .45), (270, 20, 100, .45),
    ];
    final n = cover < .12 ? 0 : cover < .35 ? 1 : cover < .6 ? 3 : 5;
    final cloudCol = night ? const Color(0xFF9AA6C2) : Colors.white;
    for (var i = 0; i < n; i++) {
      final (x0, y0, w, op) = clouds[i];
      final span = W + w * k + 40;
      var x = (x0 * sx + drift * (1 + i * .25)) % span;
      if (x < 0) x += span;
      x -= w * k * .5 + 20;
      _cloud(c, x, y0 * k, w * k, op * (night ? .45 : 1) * (.7 + .3 * cover), cloudCol);
    }
  }

  void _canvasMountains(Canvas c, ScenePalette pal, double W, double H, double sx, double k, bool night) {
    // Dağlar (uzak → yakın), Figma katman değerleri
    final snowCap = (s.snowDepthM ?? 0) > .02 || {Wx.snow, Wx.lentil, Wx.blizzard, Wx.sleet}.contains(wx) || s.temp <= 1;
    final layers = <(Color, Color, double, double, List<double>, double, double)>[
      (pal.far1, pal.far2, H * .70, 120 * k, [7.3, .6, 1.6, 17, 1.1, .12], .86, .45),
      (pal.mid1, pal.mid2, H * .80, 96 * k, [5.1, 2.2, 1.4, 13, .4, .14], .8, .5),
      (pal.near1, pal.near2, H * .96, 70 * k, [3.4, 1.3, 1.1, 9, 2.0, .18], 0, 0),
    ];
    for (final (c1, c2, base, amp, kk, snow, thr) in layers) {
      final pts = <Offset>[];
      final path = Path()..moveTo(0, H);
      for (var x = 0.0; x <= W + 3; x += 3) {
        final y = base - amp * _ridge(x / W, kk);
        pts.add(Offset(x, y)); path.lineTo(x, y);
      }
      path..lineTo(W, H)..close();
      c.drawPath(path, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c1, c2])
          .createShader(Rect.fromLTRB(0, base - amp, W, H)));
      if (snow > 0 && snowCap) {
        // Sırtı izleyen kar şapkası; alt kenar tırtıklı.
        final thrY = base - amp * thr;
        double edge(double x) { final fx = x / sx; return thrY + (4 * sin(fx / 5 + kk[1]) + 3 * sin(fx / 13)) * k; }
        final capPaint = Paint()..color = Colors.white.withValues(alpha: night ? snow * .55 : snow);
        var seg = <Offset>[];
        void flush() {
          if (seg.length >= 2) {
            final cp = Path()..moveTo(seg.first.dx, seg.first.dy);
            for (final o in seg.skip(1)) { cp.lineTo(o.dx, o.dy); }
            for (final o in seg.reversed) { cp.lineTo(o.dx, edge(o.dx)); }
            c.drawPath(cp..close(), capPaint);
          }
          seg = [];
        }
        for (final o in pts) { if (o.dy < edge(o.dx)) { seg.add(o); } else { flush(); } }
        flush();
      }
      if (snow > 0) {
        // Katman arası pus
        final hz = Rect.fromLTWH(0, base - 45 * k, W, 90 * k);
        c.drawRect(hz, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [pal.haze.withValues(alpha: 0), pal.haze.withValues(alpha: .5), pal.haze.withValues(alpha: 0)], stops: const [0, .55, 1]).createShader(hz));
      }
    }

    // Ön plan kar örtüsü
    if ((s.snowDepthM ?? 0) > .02 || {Wx.snow, Wx.blizzard, Wx.lentil}.contains(wx)) {
      final g = Path()..moveTo(0, H);
      for (var x = 0.0; x <= W + 4; x += 4) { final fx = x / sx; g.lineTo(x, H - (14 + 5 * sin(fx / 37) + 3 * sin(fx / 11)) * k); }
      g..lineTo(W, H)..close();
      c.drawPath(g, Paint()..color = (night ? const Color(0xFFC9D3E6) : Colors.white).withValues(alpha: .95));
    }
  }

  void _front(Canvas c, Size sz, ScenePalette pal, double W, double H, double k) {
    // İnce bulutların arkasından sızan güneş parıltısı (bulutların üstüne)
    if (s.isDay) {
      final sl = skyLight(s, W, H);
      if (sl.visible) paintSunBloom(c, sl.pos, 22 * k, alt: ScenePalette.sunAlt(s), cover: (s.cloudCover / 100).clamp(0.0, 1.0));
    }
    // Sis bandı (süzülen sis bulutlarının altında yoğunluk tabanı)
    final f = fogAmount(s, a, wx);
    if (f > .05) {
      final r = Rect.fromLTWH(0, H * .42, W, H * .58);
      c.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [pal.haze.withValues(alpha: .7 * f), pal.haze.withValues(alpha: 0)]).createShader(r));
    }

    _precip(c, W, H);

    // Şimşek: bulut tabanından çakan dallanan yıldırım; tüm gök, bulutlar ve dağlar bir an aydınlanır
    if (wx == Wx.thunder && part != _Part.all) {
      final st = Lightning.at(t);
      if (st != null) {
        if (st.$2 > .12) Lightning.paintBolt(c, sz, st.$1, st.$2);
        Lightning.paintFlash(c, sz, st.$1, st.$2);
      }
    }

    // Üst okunurluk gölgesi: açık renkli gökte beyaz sıcaklık yazısı net kalsın
    if (s.isDay) {
      final tr = Rect.fromLTWH(0, 0, W * .75, H * .5);
      c.drawRect(tr, Paint()..shader = RadialGradient(center: Alignment.topLeft, radius: 1.1,
          colors: [const Color(0xFF0B1A2E).withValues(alpha: .16 + .10 * (s.cloudCover / 100)), const Color(0x000B1A2E)]).createShader(tr));
    }
    // Okunurluk perdesi (alt 120 px)
    final sr = Rect.fromLTWH(0, H - 120 * k, W, 120 * k);
    c.drawRect(sr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0x61050F1F)]).createShader(sr));
  }

  void _cloud(Canvas c, double x, double y, double w, double op, Color col) {
    final paint = Paint()..color = col.withValues(alpha: op.clamp(0.0, 1.0))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final parts = [(0.0, 10.0, w, w * .32), (w * .12, -w * .06, w * .42, w * .42), (w * .42, -w * .14, w * .46, w * .46)];
    // Üst üste binen elipsleri tek katmanda topla: kenarlar koyulaşmasın.
    c.saveLayer(Rect.fromLTWH(x - 20, y - w * .3, w + 40, w * .8), Paint()..color = Colors.white.withValues(alpha: op.clamp(0.0, 1.0)));
    for (final (dx, dy, ww, hh) in parts) {
      c.drawOval(Rect.fromLTWH(x + dx, y + dy, ww, hh), paint..color = col);
    }
    c.restore();
  }

  /// Gerçek evresiyle ay: aydınlık kısım, terminatör elipsi, kraterler.
  void _moon(Canvas c, Offset ctr, double k) {
    final m = moonPhase(DateTime.now());
    final r = 24.0 * k;
    c.drawCircle(ctr, 64 * k, Paint()..shader = RadialGradient(colors: [const Color(0xFFDDE6FF).withValues(alpha: .22 * (1 - s.cloudCover / 140)), const Color(0x00DDE6FF)]).createShader(Rect.fromCircle(center: ctr, radius: 64 * k)));
    c.drawCircle(ctr, r, Paint()..color = const Color(0xFF2B3866).withValues(alpha: .9));
    final lit = moonLitPath(ctr, r, m.fraction, south: s.place.lat < 0);
    c.drawPath(lit, Paint()..color = const Color(0xFFF4ECCF).withValues(alpha: s.cloudCover > 85 ? .45 : 1));
    c.save(); c.clipPath(lit);
    for (final (dx, dy, cr) in const [(5.0, -6.0, 3.5), (-6.0, 5.0, 4.5), (7.0, 7.0, 2.6), (-1.0, -12.0, 2.0)]) {
      c.drawCircle(ctr + Offset(dx, dy) * k, cr * k, Paint()..color = const Color(0xFFD8CDA8).withValues(alpha: .55));
    }
    c.restore();
  }

  void _precip(Canvas c, double W, double H) {
    final kinds = {Wx.rain, Wx.drizzle, Wx.thunder, Wx.sleet, Wx.snow, Wx.lentil, Wx.blizzard};
    if (!kinds.contains(wx)) return;
    final wind = sin((s.windDir + 180) * pi / 180) * s.windSpeed.clamp(0, 25); // + sağa
    final q = .55 + .45 * (H / 380).clamp(0.0, 1.0); // küçük yüzeyde (widget) taneler de küçülür
    switch (wx) {
      case Wx.snow || Wx.blizzard:
        _snow(c, W, H, wind, q, wx == Wx.blizzard ? 170 : 110, wx == Wx.blizzard);
      case Wx.lentil:
        _pellets(c, W, H, wind, q);
      case Wx.sleet:
        _snow(c, W, H, wind, q, 60, false);
        _rain(c, W, H, wind, q, 70, false);
        _splashes(c, W, H, q, 12);
      default:
        final drizzle = wx == Wx.drizzle;
        _rain(c, W, H, wind, q, drizzle ? 90 : (wx == Wx.thunder ? 150 : 130), drizzle);
        _splashes(c, W, H, q, drizzle ? 10 : 30);
    }
  }

  /// Kar: derinlik bulanıklığı. Uzak taneler küçük ve keskin, yakınlar büyük ve yumuşak; birkaç tane
  /// objektifin hemen önünden geçer (iri, flu). Her tane kendi salınımıyla süzülür.
  void _snow(Canvas c, double W, double H, double wind, double q, int n, bool blizzard) {
    final far = Paint();
    final mid = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, .7);
    final near = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    final bokeh = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.6);
    const flake = Color(0xFFFFFFFF);
    for (var i = 0; i < n; i++) {
      final (rx, ry, d0, ph) = p.drops[i];
      final lens = i % 23 == 0; // objektife çok yakın tane
      final depth = lens ? 1.0 : d0 * d0; // çoğu tane uzakta
      final speed = (lens ? 70.0 : 16 + 40 * depth) * (blizzard ? 2.6 : 1);
      final span = H + 60;
      final y = (ry * span + t * speed) % span - 30;
      final sway = sin(t * (.5 + ph * .8) + ph * 6.28) * (3 + 11 * depth);
      var x = rx * W + (y / H) * wind * (2 + 6 * depth) + t * wind * (1 + 2.4 * depth) * (blizzard ? 2 : 1) + sway;
      x %= W + 20; if (x < -10) x += W + 20; x -= 10;
      final Paint pt; final double r, a;
      if (lens) { pt = bokeh; r = (6 + 4 * ph) * q; a = .26; }
      else if (depth > .62) { pt = near; r = (2.2 + 2.4 * depth) * q; a = .7; }
      else if (depth > .25) { pt = mid; r = (1.2 + 1.6 * depth) * q; a = .8; }
      else { pt = far; r = (.6 + 1.6 * depth) * q; a = .55 + depth; }
      c.drawCircle(Offset(x, y), r, pt..color = flake.withValues(alpha: a.clamp(0.0, 1.0)));
    }
  }

  void _pellets(Canvas c, double W, double H, double wind, double q) {
    final pt = Paint();
    for (var i = 0; i < 90; i++) {
      final (rx, ry, depth, _) = p.drops[i];
      final speed = 120 + 120 * depth;
      final y = (ry * (H + 20) + t * speed) % (H + 20) - 10;
      var x = rx * W + (y / H) * wind * 3 + t * wind * .8;
      x %= W; if (x < 0) x += W;
      c.drawCircle(Offset(x, y), (1.2 + depth * 1.6) * q, pt..color = Colors.white.withValues(alpha: .7 + .3 * depth));
    }
  }

  /// Yağmur: hıza göre uzayan ince çizgiler; yakın damlalar kalın ve hafif flu, rüzgârla eğik.
  void _rain(Canvas c, double W, double H, double wind, double q, int n, bool drizzle) {
    final thin = Paint()..strokeCap = StrokeCap.round;
    final soft = Paint()..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);
    const col = Color(0xFFE4ECF6);
    for (var i = 0; i < n; i++) {
      final (rx, ry, depth, _) = p.drops[i];
      final speed = (drizzle ? 240.0 : 560.0) * (.55 + .8 * depth);
      final span = H + 40;
      final y = (ry * span + t * speed) % span - 20;
      final slope = wind * (drizzle ? .045 : .03); // yatay kayma / düşey
      var x = rx * W + y * slope + t * speed * slope * .02;
      x %= W + 20; if (x < -10) x += W + 20; x -= 10;
      final len = (drizzle ? 4 + 6 * depth : 10 + 26 * depth) * q;
      final near = depth > .88 && !drizzle;
      final pt = near ? soft : thin;
      pt
        ..color = col.withValues(alpha: near ? .3 : (drizzle ? .28 : .16) + .3 * depth)
        ..strokeWidth = (near ? 2.0 : .55 + .9 * depth) * q;
      c.drawLine(Offset(x, y), Offset(x + len * slope, y + len), pt);
    }
  }

  /// Yere düşen damlaların sıçraması: ön planda genişleyen halka ve havalanan iki-üç damlacık.
  void _splashes(Canvas c, double W, double H, double q, int n) {
    final ring = Paint()..style = PaintingStyle.stroke;
    final dot = Paint();
    final k = H / 380;
    for (var j = 0; j < n; j++) {
      final (rx, ry, d, ph) = p.drops[(j * 7 + 3) % p.drops.length];
      final period = .45 + ry * .8;
      const life = .26;
      final tt = t + ph * period;
      final u = tt % period;
      if (u > life) continue;
      final pr = u / life;
      final cycle = (tt / period).floor();
      final near = d; // 0 uzak (yukarıda, küçük) … 1 yakın (aşağıda, büyük)
      final y = H - (30 - 26 * near) * k;
      final x = (rx * W + cycle * 97.3 + j * 41.7) % W;
      final sc = (.5 + .9 * near) * q;
      final fade = (1 - pr);
      ring
        ..strokeWidth = .7 * sc
        ..color = const Color(0xFFE8F0FA).withValues(alpha: .5 * fade);
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: (2 + 11 * pr) * sc, height: (.8 + 3.2 * pr) * sc), ring);
      dot.color = const Color(0xFFF2F7FD).withValues(alpha: .6 * fade);
      for (final side in const [-1.0, 1.0, .35]) {
        final dx = side * (2.5 + 7 * pr) * sc;
        final dy = -(4 * pr * (1 - pr)) * 7 * sc * (side == .35 ? 1.4 : 1);
        c.drawCircle(Offset(x + dx, y + dy), .65 * sc, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) => o.t != t || o.s != s || o.wx != wx || o.part != part;
}

/// Ayın aydınlık kısmı. [fraction] 0 yeni ay, 0.5 dolunay. Kuzey yarımkürede büyüyen ay sağdan aydınlanır.
Path moonLitPath(Offset c, double r, double fraction, {bool south = false}) {
  final f = fraction % 1;
  final illum = (1 - cos(2 * pi * f)) / 2;
  final waxing = f < .5;
  final rightLit = waxing != south;
  final k = (1 - 2 * illum).abs() * r; // terminatör yarı ekseni
  final top = c - Offset(0, r), bottom = c + Offset(0, r);
  final p = Path()..moveTo(top.dx, top.dy);
  // Aydınlık kenar: sağ ya da sol yarım daire
  p.arcToPoint(bottom, radius: Radius.circular(r), clockwise: rightLit);
  // Terminatör: şişkin evrede karşı tarafa, hilalde aynı tarafa bombeli
  final gibbous = illum > .5;
  p.arcToPoint(top, radius: Radius.elliptical(max(k, .01), r), clockwise: rightLit == gibbous);
  return p..close();
}

/// Fırtınada yıldırım: zamanlaması ve biçimi saatten türetilir (her çakış farklı, çakış boyunca sabit).
/// Ortalama 8 sn'de bir; ana boşalmadan ~0,12 sn sonra ikinci bir parlama (geri dönüş vuruşu).
class Lightning {
  static double _h(double n) { final v = sin(n * 12.9898 + 78.233) * 43758.5453; return v - v.floorToDouble(); }

  /// [t] anında süren bir çakış varsa (tohum, parlaklık 0..1).
  static (int, double)? at(double t) {
    for (var back = 0; back < 2; back++) {
      final slot = (t / 1.0).floor() - back;
      if (_h(slot * 1.0) > .13) continue;
      final start = slot + _h(slot + .5) * .6;
      final tau = t - start;
      if (tau < 0 || tau > 1.1) continue;
      var e = exp(-tau * 9);
      if (tau > .12) e += .75 * exp(-(tau - .12) * 7);
      if (tau > .3 && _h(slot + .7) > .5) e += .4 * exp(-(tau - .3) * 10);
      return (slot, e.clamp(0.0, 1.0));
    }
    return null;
  }

  static final Map<int, (List<Offset>, List<List<Offset>>)> _shapes = {};

  /// Bölüm bölüm kırılan ana kanal ve birkaç dal (birim koordinat: x 0..1, y 0..1).
  static (List<Offset>, List<List<Offset>>) shape(int seed) => _shapes[seed] ??= () {
        if (_shapes.length > 12) _shapes.clear();
        final r = Random(seed);
        List<Offset> zig(Offset a, Offset b, double rough, int depth) {
          var pts = [a, b];
          var amp = rough;
          for (var d = 0; d < depth; d++) {
            final next = <Offset>[pts.first];
            for (var i = 0; i < pts.length - 1; i++) {
              final p0 = pts[i], p1 = pts[i + 1];
              final m = (p0 + p1) / 2;
              final dir = p1 - p0;
              final nrm = Offset(-dir.dy, dir.dx) / max(dir.distance, 1e-6);
              next..add(m + nrm * (r.nextDouble() - .5) * amp)..add(p1);
            }
            pts = next; amp *= .52;
          }
          return pts;
        }
        final x0 = .18 + .64 * r.nextDouble();
        final main = zig(Offset(x0, 0), Offset(x0 + (r.nextDouble() - .5) * .22, 1), .16, 6);
        final branches = <List<Offset>>[];
        final nb = 2 + r.nextInt(3);
        for (var b = 0; b < nb; b++) {
          final i = (main.length * (.15 + .55 * r.nextDouble())).floor();
          final a = main[i];
          final side = r.nextBool() ? 1.0 : -1.0;
          final len = .18 + .25 * r.nextDouble();
          branches.add(zig(a, a + Offset(side * len * .55, len), .08, 4));
        }
        return (main, branches);
      }();

  /// Yıldırım kanalı: bulut tabanından (gök %9) uzak dağların üstündeki pusa (%46) iner ve orada
  /// söner (bulut-hava boşalması gibi; dağların önüne geçmez). Parlak çekirdek + mavi hale.
  static void paintBolt(Canvas c, Size sz, int seed, double e) {
    final (main, branches) = shape(seed);
    final top = sz.height * .09, bot = sz.height * .46;
    Path path(List<Offset> pts) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = Offset(pts[i].dx * sz.width, top + pts[i].dy * (bot - top));
        if (i == 0) { p.moveTo(o.dx, o.dy); } else { p.lineTo(o.dx, o.dy); }
      }
      return p;
    }
    final k = sz.height / 380;
    // Alt uçta pusun içinde yavaşça kaybolur
    Shader fade(Color col, double a) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [col.withValues(alpha: a), col.withValues(alpha: a), col.withValues(alpha: 0)], stops: const [0, .72, 1])
        .createShader(Rect.fromLTRB(0, top, sz.width, bot));
    final glow = Paint()..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..shader = fade(const Color(0xFFB8C6FF), .6 * e)
      ..strokeWidth = 7 * k..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k);
    final core = Paint()..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..shader = fade(Colors.white, e);
    final mp = path(main);
    c.drawPath(mp, glow);
    for (final b in branches) {
      final bp = path(b);
      c.drawPath(bp, glow..strokeWidth = 4 * k);
      c.drawPath(bp, core..strokeWidth = .9 * k);
    }
    c.drawPath(mp, core..strokeWidth = 1.8 * k);
  }

  /// Çakış ışığı: gök, bulutlar ve dağlar bir an soğuk beyaz aydınlanır; en çok kanalın üstünde.
  static void paintFlash(Canvas c, Size sz, int seed, double e) {
    final r = Offset.zero & sz;
    final x = shape(seed).$1.first.dx * sz.width;
    c.drawRect(r, Paint()..blendMode = BlendMode.screen..color = const Color(0xFFDCE4FF).withValues(alpha: .28 * e));
    c.drawRect(r, Paint()..blendMode = BlendMode.screen..shader = RadialGradient(
        center: Alignment(x / sz.width * 2 - 1, -.75), radius: .9,
        colors: [const Color(0xFFEFF3FF).withValues(alpha: .55 * e), const Color(0x00EFF3FF)]).createShader(r));
  }
}
