import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import '../astro/opensky_service.dart';
import '../services/weather_repository.dart';
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
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(initialCenter: _center, initialZoom: 7, minZoom: 3, maxZoom: 11, onMapEvent: (e) { if (e is MapEventMoveEnd) _poll(); }),
        children: [
          TileLayer(
            urlTemplate: _weather
                ? 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_CorrectedReflectance_TrueColor/default/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.skynav.app', maxNativeZoom: 9),
          if (_weather && _radarUrl != null) Opacity(opacity: .75, child: TileLayer(urlTemplate: _radarUrl!, userAgentPackageName: 'com.skynav.app')),
          PolylineLayer(polylines: [
            for (final p in _planes) ...[
              if (_trails.trail(p.icao24).length > 1) Polyline(points: [for (final t in _trails.trail(p.icao24)) LatLng(t.$1, t.$2)], color: (p.militaryHint ? Colors.red : kAccent).withValues(alpha: .6), strokeWidth: 2),
              if (_sel?.icao24 == p.icao24) Polyline(points: [LatLng(p.lat, p.lon), for (final r in projectedRoute(p)) LatLng(r.$1, r.$2)], color: Colors.orange, strokeWidth: 3, pattern: StrokePattern.dashed(segments: const [8, 6])),
            ],
          ]),
          MarkerLayer(markers: [
            for (final p in _planes)
              Marker(point: LatLng(p.lat, p.lon), width: 34, height: 34, child: GestureDetector(
                onTap: () => setState(() => _sel = p),
                // Uçak simgesi kuzeye bakar (Icons.flight 90° sağa); rotasyon = yön - 90
                child: Transform.rotate(angle: ((p.headingDeg ?? 0) - 90) * pi / 180, child: Icon(Icons.flight, size: p.militaryHint ? 30 : 24, color: p.militaryHint ? Colors.red : const Color(0xFF1A2B3C), shadows: const [Shadow(color: Colors.white, blurRadius: 6)])))),
          ]),
        ],
      ),
      Positioned(left: 12, right: 12, top: 8, child: Column(children: [
        Glass(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
          Expanded(child: Text('✈️ ${_planes.length} uçak · tamamen ücretsiz', style: const TextStyle(fontWeight: FontWeight.w800))),
          Pill(severe ? '⚠️ şiddetli hücre' : 'ADS-B'),
        ])),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 6), child: Glass(tint: const Color(0xFFFFF8E1), padding: const EdgeInsets.all(8), child: Text(_err!, style: const TextStyle(fontSize: 12)))),
        if (_sel != null) Padding(padding: const EdgeInsets.only(top: 6), child: Glass(padding: const EdgeInsets.all(10), child: Text(
            '${_sel!.callsign.isEmpty ? _sel!.icao24 : _sel!.callsign} · ${_sel!.originCountry}\nİrtifa ${(_sel!.baroAltM ?? 0).round()} m · hız ${((_sel!.velocityMs ?? 0) * 3.6).round()} km/s · yön ${(_sel!.headingDeg ?? 0).round()}°${_sel!.militaryHint ? '\n🛡️ Askerî olabilir (ADS-B yayını yapıyor)' : ''}\nTurunculu kesikli çizgi: yaklaşık gidiş rotası',
            style: const TextStyle(fontSize: 12)))),
      ])),
      Positioned(right: 12, bottom: 96, child: FilledButton.icon(
        onPressed: () => setState(() => _weather = !_weather),
        icon: Icon(_weather ? Icons.cloud_off : Icons.cloud), label: Text(_weather ? 'Hava Koşullarını Gizle' : 'Hava Koşullarını Göster'))),
      const Positioned(left: 12, bottom: 100, child: Text('Veri: OpenSky ADS-B · Hava: RainViewer + NASA GIBS\nADS-B kapatan uçaklar görünmez', style: TextStyle(fontSize: 10, color: Colors.black87, backgroundColor: Colors.white70))),
    ]);
  }
}
