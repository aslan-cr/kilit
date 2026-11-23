import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../data/models.dart';
import '../services/location_service.dart';
import '../services/weather_repository.dart';
import 'clouds.dart';
import 'hero_scene.dart' show ScenePalette;
import 'map_chrome.dart';
import 'theme.dart';
import 'wx_glyph.dart';

/// 3D Harita: yalnızca bu sekme açıldığında kurulur, kapanınca (dispose) akışlar ve çizim tamamen boşaltılır.
/// Zemin GERÇEK uydu (Esri World Imagery) + gerçek kabartma (Esri Hillshade) karolarıdır; uydurma bina/yazı yoktur.
/// Kamera eğilebilir (perspektif), bulutlar derinlikli katmanlar, yağış rüzgârla eğilir, kar rüzgâr gölgesinde birikir.
class Map3DScreen extends StatefulWidget {
  const Map3DScreen({super.key});
  @override
  State<Map3DScreen> createState() => _Map3DScreenState();
}

class _Map3DScreenState extends State<Map3DScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  StreamSubscription<Position>? _gps;
  LatLng? _me;
  LatLng _center = const LatLng(39.0, 35.0);
  double _tilt = 48; // derece
  double _zoom = 11;
  bool _showWeather = true;
  bool _manual = false;
  String? _gpsNote;

  @override
  void initState() {
    super.initState();
    final p = WeatherController.I.confirmed?.place ?? LocationService.lastKnown;
    if (p != null) { _center = LatLng(p.lat, p.lon); _me = _center; }
    _startGps();
  }

  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { setState(() => _gpsNote = 'Konum izni yok: son bilinen/elle seçilen noktayı gösteriyorum.'); return; }
      _gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25)).listen((p) {
        if (_manual) return;
        final ll = LatLng(p.latitude, p.longitude);
        setState(() { _me = ll; _gpsNote = null; });
        _map.move(ll, _map.camera.zoom);
        // Yeni mahalleye varıldıkça yerel hava/yağış verisi o noktaya geçer.
        WeatherController.I.setPlace(GeoPoint2(p.latitude, p.longitude, elevation: p.altitude != 0 ? p.altitude : null, name: 'Konumum'));
      }, onError: (_) => setState(() => _gpsNote = 'GPS sinyali zayıf: son bilinen noktayı gösteriyorum.'));
    } catch (_) { setState(() => _gpsNote = 'GPS alınamadı: son bilinen noktayı gösteriyorum.'); }
  }

  @override
  void dispose() { _gps?.cancel(); _anim.dispose(); super.dispose(); }

  /// Haritanın üstündeki bulut katmanı (ve gölgesi): gerçek örtü, rüzgâr yönünde süzülür.
  CloudSpec _mapClouds(WeatherSnapshot s, {bool shadow = false}) {
    final to = (s.windDir + 180) * pi / 180, spd = .006 + s.windSpeed.clamp(0, 25) * .0016;
    final wet = s.precip > .1;
    final cover = (s.cloudCover / 100).clamp(0.0, 1.0) * .92;
    if (shadow) {
      return CloudSpec(cover: cover, lit: const Color(0xFF0B1A2A), shade: const Color(0xFF0B1A2A), opacity: .22, weight: 0, scale: 230, horizon: 3, seed: 2.2,
          wind: Offset(-sin(to) * spd, cos(to) * spd * .5));
    }
    return CloudSpec(cover: cover, horizon: 3, scale: 230, seed: 2.2, sun: const Offset(.8, .05), wind: Offset(-sin(to) * spd, cos(to) * spd * .5),
        lit: !s.isDay ? const Color(0xFF6F7A92) : wet ? const Color(0xFFD5DCE5) : Colors.white,
        shade: !s.isDay ? const Color(0xFF262D3D) : wet ? const Color(0xFF56616F) : const Color(0xFFAAB8C8),
        weight: wet ? .85 : .15, opacity: .82);
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I;
    return ListenableBuilder(listenable: w, builder: (_, __) {
      final s = w.confirmed, a = w.analysis;
      final pal = s != null && a != null ? ScenePalette.of(s, wxFromNow(s, a)) : ScenePalette.clearDay;
      return Stack(children: [
        Positioned.fill(child: ClipRect(child: LayoutBuilder(builder: (_, c) {
          return Container(color: const Color(0xFFBFD6E8), child: Stack(children: [
            // Eğik (perspektif) gerçek uydu zemini
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()..setEntry(3, 2, 0.0011)..rotateX(_tilt * pi / 180),
              child: OverflowBox(maxWidth: c.maxWidth * 1.9, maxHeight: c.maxHeight * 1.9, child: SizedBox(width: c.maxWidth * 1.9, height: c.maxHeight * 1.9, child: FlutterMap(
                mapController: _map,
                options: MapOptions(initialCenter: _center, initialZoom: _zoom, minZoom: 3, maxZoom: 15,
                    onPositionChanged: (cam, _) { _zoom = cam.zoom; },
                    onLongPress: (_, ll) { setState(() { _manual = true; _me = ll; }); WeatherController.I.setPlace(GeoPoint2(ll.latitude, ll.longitude, name: 'Seçilen nokta')); }),
                children: [
                  TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.skynav.app', maxNativeZoom: 17),
                  Opacity(opacity: .32, child: TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.skynav.app', maxNativeZoom: 15)),
                  if (_me != null) MarkerLayer(markers: [Marker(point: _me!, width: 30, height: 30, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)])))]),
                ],
              ))),
            ),
            // Gece: gündüz çekilmiş uydu görüntüsünü karart (gerçekçi gece ışığı)
            if (s != null && !s.isDay) const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0x730B1330)))),
            // Gökyüzü + ufuk pusu: havaya ve saate göre (üst sahneyle aynı palet) — derinlik hissi
            Positioned(top: 0, left: 0, right: 0, height: c.maxHeight * (.18 + _tilt / 65 * .2), child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .45, 1],
                colors: [pal.skyTop.withValues(alpha: _tilt / 65), pal.skyBottom.withValues(alpha: .85), pal.haze.withValues(alpha: 0)]))))),
            // Gerçek bulut örtüsü (GPU): önce yere düşen gölgesi, sonra bulutun kendisi
            if (_showWeather && s != null && s.cloudCover > 3 && CloudShader.ready) ...[
              if (s.isDay) Positioned.fill(child: IgnorePointer(child: Transform.translate(offset: const Offset(26, 40),
                  child: CloudLayer(spec: _mapClouds(s, shadow: true))))),
              Positioned.fill(child: IgnorePointer(child: CloudLayer(spec: _mapClouds(s)))),
            ],
            // Rüzgârla akan yağış, vadi sisi, kar birikintisi
            if (_showWeather && s != null && a != null)
              Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _anim, builder: (_, __) => CustomPaint(painter: _WeatherLayerPainter(s, a, _anim.value * 120, _tilt))))),
          ]));
        }))),
        Positioned(left: 14, right: 14, top: 8, child: Column(children: [
          MapHeader(icon: Icons.view_in_ar_rounded, title: '3D Harita', sub: s == null ? 'Gerçek uydu + kabartma' : '${s.place.name.isEmpty ? 'Konumum' : s.place.name} · ${s.temp.round()}° · eğim ${_tilt.round()}°',
              trailing: MapRoundButton(Icons.my_location_rounded, 'Konumuma dön', () { _manual = false; WeatherController.I.useGps(); if (_me != null) _map.move(_me!, _map.camera.zoom); })),
          if (_gpsNote != null) MapNote(Icons.gps_off_rounded, _gpsNote!),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: MapCredit('Uydu: Esri World Imagery · Kabartma: Esri Hillshade · Uzun bas: o noktanın havası')),
        ])),
        // Eğim: sağ kenarda dikey kaydırıcı
        Positioned(right: 14, top: 124, height: 230, child: Glass(radius: 22, padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [
          const Icon(Icons.threed_rotation_rounded, size: 18, color: kInkSoft),
          Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(min: 0, max: 65, value: _tilt, onChanged: (v) => setState(() => _tilt = v)))),
          Text('${_tilt.round()}°', style: T.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: kInk)),
        ]))),
        Positioned(right: 14, bottom: 96, child: LayerToggle(icon: Icons.cloud_rounded, label: 'Hava katmanı', on: _showWeather, onTap: () => setState(() => _showWeather = !_showWeather))),
      ]);
    });
  }
}

/// Üç derinlik katmanlı bulut, rüzgâra eğilen yağış, vadilerde sis, rüzgâr gölgesinde kar birikintisi.
class _WeatherLayerPainter extends CustomPainter {
  final WeatherSnapshot s; final Analysis a; final double t, tilt;
  _WeatherLayerPainter(this.s, this.a, this.t, this.tilt);

  @override
  void paint(Canvas c, Size size) {
    final rnd = Random(11);
    final wd = (s.windDir + 180) * pi / 180; // rüzgârın gittiği yön
    final wx = sin(wd);
    final speed = s.windSpeed.clamp(0, 25).toDouble();
    final cover = (s.cloudCover / 100).clamp(0.0, 1.0);
    final horizon = size.height * .16;

    // Bulutlar: uzak katman küçük/soluk, yakın katman büyük/belirgin (perspektif)
    if (cover > .08 && !CloudShader.ready) {
      final n = (10 + cover * 22).round();
      for (var layer = 0; layer < 3; layer++) {
        for (var i = 0; i < n ~/ 3 + 2; i++) {
          final depth = (layer + rnd.nextDouble()) / 3; // 0 uzak, 1 yakın
          final baseX = rnd.nextDouble() * 1.4 - .2;
          final dx = (t * (.0012 + speed * .00035) * (.5 + depth)) * (wx >= 0 ? 1 : -1);
          final x = ((baseX + dx) % 1.4 - .2) * size.width;
          final y = horizon + (size.height * .42) * depth * depth + rnd.nextDouble() * 20;
          final r = (26 + 70 * depth) * (.7 + rnd.nextDouble() * .6);
          final alpha = (.28 + .5 * depth) * cover;
          final dark = a.kind == PrecipKind.rain || s.cloudCover > 85;
          final col = dark ? const Color(0xFFB4BFCB) : Colors.white;
          // Gündüz bulut gölgesi: bulutun altında, yerde, yakın katmanda daha belirgin
          if (s.isDay && cover < .9) {
            final so = Offset(x + r * .35, y + 30 + 70 * depth);
            c.drawOval(Rect.fromCenter(center: so, width: r * 2.6, height: r * (.7 + .5 * depth)),
                Paint()..color = const Color(0xFF0B1A2A).withValues(alpha: .10 * cover * (.5 + depth))..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 10 * depth));
          }
          for (var k = 0; k < 4; k++) {
            final o = Offset(x + (k - 1.5) * r * .55, y + (k.isOdd ? -r * .12 : r * .1));
            c.drawCircle(o, r * (.55 + (k % 2) * .18), Paint()..shader = RadialGradient(colors: [col.withValues(alpha: alpha), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r)));
          }
        }
      }
    }

    // Vadilerde/yamaçlarda sis: nem + çiy farkı + soğuk hava alçalması → alt kısımlarda yarıya kadar saran örtü
    final fog = (a.fogProb * a.fogDensity / 100).clamp(0, 100) / 100;
    if (fog > .05) {
      final h = size.height * (.25 + .35 * fog);
      c.drawRect(Rect.fromLTWH(0, size.height - h, size.width, h), Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.white.withValues(alpha: .85 * fog), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, size.height - h, size.width, h)));
    }

    // Yağış: yoğunluk bulunulan noktadaki yağışa göre; rüzgâr arttıkça yatıklık ve hız artar. Uzak (üst) bölgede daha seyrek/küçük (LOD).
    if (a.kind != PrecipKind.none) {
      final intensity = ((s.precip + s.snowfall) / 3).clamp(.15, 1.0);
      final n = (220 * intensity).round();
      final lean = wx * speed * 1.6;
      for (var i = 0; i < n; i++) {
        final p = Random(i * 7 + 1);
        final depth = p.nextDouble(); // 0 uzak, 1 yakın
        if (depth < .25 && i % 2 == 0) continue; // uzakta yarı yoğunluk
        final fall = a.kind == PrecipKind.rain ? 700.0 : 70.0;
        final sp = fall * (.5 + depth) * (1 + speed / 30);
        var y = (p.nextDouble() * size.height + t * sp) % (size.height + 30);
        var x = p.nextDouble() * size.width + (y / size.height) * lean * 40 + t * wx * speed * 4;
        x = x % size.width; if (x < 0) x += size.width;
        if (y < horizon * (1 - depth * .3)) continue;
        final sz = .6 + depth * 2.4;
        if (a.kind == PrecipKind.rain) {
          c.drawLine(Offset(x, y), Offset(x + lean * .6, y + 8 + 10 * depth), Paint()..color = const Color(0xFFDCEBFA).withValues(alpha: .35 + .4 * depth)..strokeWidth = .8 + depth);
        } else if (a.kind == PrecipKind.lentilSnow) {
          c.drawCircle(Offset(x, y), sz * 1.4, Paint()..color = Colors.white.withValues(alpha: .9));
        } else {
          c.drawCircle(Offset(x, y), sz, Paint()..color = Colors.white.withValues(alpha: .55 + .4 * depth));
        }
      }
    }

    // Kar/tipi birikintisi: rüzgârın kesildiği yer (rüzgâr GÖLGESİ = rüzgâr yönünün tersi taraf, alt kenar) — kuytu/çukur birikimi
    final snowy = a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.blizzard || (s.snowDepthM ?? 0) > .05;
    if (snowy) {
      final lee = wx >= 0 ? 1.0 : 0.0; // rüzgâr sağa gidiyorsa birikinti sağda (gittiği yerde, engel arkasında)
      final amount = ((s.snowDepthM ?? .05) * 3 + a.blizzardProb / 120).clamp(.1, 1.0);
      final path = Path()..moveTo(size.width * lee, size.height);
      for (var i = 0; i <= 12; i++) {
        final u = i / 12; final x = size.width * (lee == 1 ? 1 - u * .6 : u * .6);
        final y = size.height - size.height * .12 * amount * (1 - u) * (.6 + .4 * sin(u * 6 + 1));
        path.lineTo(x, y);
      }
      path.lineTo(size.width * (lee == 1 ? .4 : .6), size.height); path.close();
      c.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .8));
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherLayerPainter o) => true;
}
