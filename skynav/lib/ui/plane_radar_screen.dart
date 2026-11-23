import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import '../astro/opensky_service.dart';
import '../services/weather_repository.dart';
import 'map_chrome.dart';
import 'theme.dart';

/// Uçak Radarı (tamamen ücretsiz): OpenSky ADS-B anonim verisi. Yalnızca ADS-B yayını yapan uçaklar görünür;
/// yayın kapatan askerî uçaklar (F-16 dahil) görünmez, yayın yapanlar kırmızı "askerî olabilir" işaretiyle gösterilir.
class PlaneRadarScreen extends StatefulWidget {
  const PlaneRadarScreen({super.key});
  @override
  State<PlaneRadarScreen> createState() => _PlaneRadarScreenState();
}

class _PlaneRadarScreenState extends State<PlaneRadarScreen> {
  final _map = MapController();
  final _trails = TrailStore();
  Timer? _timer;
  List<Plane> _planes = [];
  String? _err; bool _busy = false;
  bool _weather = true; Plane? _sel;
  String? _radarUrl;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    final p = WeatherController.I.confirmed?.place;
    _center = LatLng(p?.lat ?? 39.0, p?.lon ?? 35.0);
    _loadRadar();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _loadRadar() async {
    try {
      final r = await http.get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json')).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      setState(() => _radarUrl = '${j['host']}${(j['radar']['past'] as List).last['path']}/256/{z}/{x}/{y}/2/1_1.png');
    } catch (_) {}
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final c = _map.camera.center;
      final box = Bbox(lamin: c.latitude - 2, lomin: c.longitude - 3, lamax: c.latitude + 2, lomax: c.longitude + 3);
      final l = await fetch(box);
      _trails.addAll(l);
      if (mounted) setState(() { _planes = l.where((p) => !p.onGround).toList(); _err = null; });
    } catch (e) { if (mounted) setState(() => _err = 'Uçak verisi şu an alınamadı (ücretsiz servis sınırı olabilir); biraz sonra yenilenecek.'); }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I;
    final s = w.confirmed;
    final severe = s != null && s.cape > 1500 && s.windGust > 18;
    final sel = _sel;
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(initialCenter: _center, initialZoom: 7, minZoom: 3, maxZoom: 11,
            onTap: (_, __) { if (_sel != null) setState(() => _sel = null); },
            onMapEvent: (e) { if (e is MapEventMoveEnd) _poll(); }),
        children: [
          TileLayer(
            urlTemplate: _weather
                ? 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_CorrectedReflectance_TrueColor/default/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.skynav.app', maxNativeZoom: 9),
          if (_weather && _radarUrl != null) Opacity(opacity: .75, child: TileLayer(urlTemplate: _radarUrl!, userAgentPackageName: 'com.skynav.app')),
          PolylineLayer(polylines: [
            for (final p in _planes) ...[
              if (_trails.trail(p.icao24).length > 1) Polyline(points: [for (final t in _trails.trail(p.icao24)) LatLng(t.$1, t.$2)], color: (p.militaryHint ? kDanger : kAccent).withValues(alpha: .6), strokeWidth: 2),
              if (sel?.icao24 == p.icao24) Polyline(points: [LatLng(p.lat, p.lon), for (final r in projectedRoute(p)) LatLng(r.$1, r.$2)], color: kSun, strokeWidth: 3, pattern: StrokePattern.dashed(segments: const [8, 6])),
            ],
          ]),
          MarkerLayer(markers: [
            for (final p in _planes)
              Marker(point: LatLng(p.lat, p.lon), width: 36, height: 36, child: GestureDetector(
                onTap: () => setState(() => _sel = p),
                child: Transform.rotate(angle: (p.headingDeg ?? 0) * pi / 180,
                    child: CustomPaint(painter: _PlanePainter(p.militaryHint ? kDanger : sel?.icao24 == p.icao24 ? kAccent : kInk, big: p.militaryHint || sel?.icao24 == p.icao24))))),
          ]),
        ],
      ),
      Positioned(left: 14, right: 14, top: 8, child: Column(children: [
        MapHeader(icon: Icons.flight_rounded, title: 'Uçak Radarı', sub: '${_planes.length} uçak · ADS-B · tamamen ücretsiz',
            trailing: Pill(severe ? 'Şiddetli hücre' : 'Canlı', color: severe ? kDanger : kGood, icon: severe ? Icons.warning_amber_rounded : Icons.sensors_rounded)),
        if (_err != null) MapNote(Icons.cloud_off_rounded, _err!),
        const SizedBox(height: 6),
        const Align(alignment: Alignment.centerLeft, child: MapCredit('Veri: OpenSky ADS-B · Hava: RainViewer + NASA GIBS · ADS-B kapatan uçaklar görünmez')),
      ])),
      if (sel != null) Positioned(left: 14, right: 14, bottom: 96, child: Glass(radius: 24, padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(Icons.flight_rounded, color: sel.militaryHint ? kDanger : kAccent, size: 40), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sel.callsign.isEmpty ? sel.icao24.toUpperCase() : sel.callsign, style: T.h2),
            Text(sel.originCountry, style: T.small.copyWith(fontSize: 12)),
          ])),
          IconButton(tooltip: 'Kapat', onPressed: () => setState(() => _sel = null), icon: const Icon(Icons.close_rounded, color: kInkSoft)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: MapStat('İrtifa', '${(sel.baroAltM ?? 0).round()} m')),
          Expanded(child: MapStat('Hız', '${((sel.velocityMs ?? 0) * 3.6).round()} km/s')),
          Expanded(child: MapStat('Yön', '${(sel.headingDeg ?? 0).round()}°')),
        ]),
        const SizedBox(height: 10),
        if (sel.militaryHint) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
          const Icon(Icons.shield_outlined, size: 16, color: kDanger), const SizedBox(width: 6),
          Expanded(child: Text('Askerî olabilir (ADS-B yayını yapıyor)', style: T.small.copyWith(color: kDanger, fontWeight: FontWeight.w700, fontSize: 12))),
        ])),
        Row(children: [
          Container(width: 18, height: 3, decoration: BoxDecoration(color: kSun, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8),
          Expanded(child: Text('Turuncu kesikli çizgi: yaklaşık gidiş rotası', style: T.small.copyWith(fontSize: 12))),
        ]),
      ]))),
      if (sel == null) Positioned(right: 14, bottom: 96, child: LayerToggle(icon: Icons.cloud_rounded, label: 'Hava katmanı', on: _weather, onTap: () => setState(() => _weather = !_weather))),
    ]);
  }
}

/// Kuzeye bakan uçak silueti (Figma alt menü ikonu), beyaz haleli.
class _PlanePainter extends CustomPainter {
  final Color color; final bool big;
  _PlanePainter(this.color, {this.big = false});
  @override
  void paint(Canvas c, Size s) {
    final k = (big ? 30 : 24) / 24;
    c.translate(s.width / 2 - 11.5 * k, s.height / 2 - 12.5 * k); c.scale(k);
    final p = Path()..moveTo(21, 16)..lineTo(21, 14)..lineTo(13, 9)..lineTo(13, 3.5)
      ..arcToPoint(const Offset(10, 3.5), radius: const Radius.circular(1.5), clockwise: false)
      ..lineTo(10, 9)..lineTo(2, 14)..lineTo(2, 16)..lineTo(10, 13.5)..lineTo(10, 19)..lineTo(8, 20.5)..lineTo(8, 22)
      ..lineTo(11.5, 21)..lineTo(15, 22)..lineTo(15, 20.5)..lineTo(13, 19)..lineTo(13, 13.5)..close();
    c.drawPath(p, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeJoin = StrokeJoin.round);
    c.drawPath(p, Paint()..color = color);
  }
  @override
  bool shouldRepaint(covariant _PlanePainter o) => o.color != color || o.big != big;
}
