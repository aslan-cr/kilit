import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:sensors_plus/sensors_plus.dart';
import '../data/models.dart';
import '../data/phrases.dart';
import '../game/badges.dart';
import '../l10n/l10n.dart';
import '../pro/pro_service.dart';
import '../road/drift_detector.dart';
import '../road/eta_engine.dart';
import '../road/osrm_service.dart';
import '../road/places_service.dart';
import '../road/road_safety.dart';
import '../services/audio_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import '../widgets/widget_service.dart';
import 'theme.dart';
import 'widgets.dart';

/// Yol Tarifi: ücretsiz = OSRM adım adım yol tarifi + canlı hız göstergesi.
/// Pro = hava/buz/tipiye göre akıllı ETA, geçit uyarıları, G-kuvveti & kayma sensörü, yol güvenliği paketi.
class RoadScreen extends StatefulWidget {
  const RoadScreen({super.key});
  @override
  State<RoadScreen> createState() => _RoadScreenState();
}

class _RoadScreenState extends State<RoadScreen> {
  final _places = PlacesService();
  final _osrm = OsrmService();
  final _map = MapController();
  final _q = TextEditingController();
  final _drift = DriftDetector();

  StreamSubscription<Position>? _gps;
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<GyroscopeEvent>? _gyro;
  GyroscopeEvent? _lastGyro;

  Position? _pos;
  double _speedMs = 0;
  List<Place> _results = [];
  final List<Place> _stops = []; // ara duraklar
  Place? _dest;
  RouteResult? _route;
  int _stepIdx = 0, _spokenStep = -1, _driftCount = 0;
  DriftEvent? _lastDrift; DateTime? _driftShownAt;
  DateTime _lastWarn = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  bool _navigating = false; String? _err; bool _busy = false;

  @override
  void initState() { super.initState(); _startGps(); _startSensors(); }

  @override
  void dispose() { _gps?.cancel(); _acc?.cancel(); _gyro?.cancel(); _places.close(); _osrm.close(); super.dispose(); }

  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { setState(() => _err = 'Konum izni yok: canlı hız ve yol tarifi çalışmaz, yine de yer arayabilirsin.'); return; }
      _gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0)).listen(_onPos, onError: (_) {});
    } catch (_) { setState(() => _err = 'GPS alınamadı.'); }
  }

  void _startSensors() {
    // Kayma sensörü (Pro): ivmeölçer + jiroskop
    _gyro = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) => _lastGyro = e, onError: (_) {});
    _acc = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
      if (!ProService.I.state.isPro) return;
      final g = _lastGyro;
      final s = WeatherController.I.confirmed, a = WeatherController.I.analysis;
      double ice = 0;
      if (s != null && a != null) { ice = (s.temp <= 1 ? .5 : 0) + (a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.blizzard || a.kind == PrecipKind.sleet ? .4 : 0) + ((s.soil0 ?? 5) <= 0 ? .2 : 0); }
      final ev = _drift.addSample(ax: e.x, ay: e.y, az: e.z, gx: g?.x ?? 0, gy: g?.y ?? 0, gz: g?.z ?? 0, speedMs: _speedMs, icyRisk: ice.clamp(0, 1));
      if (ev != null) _onDrift(ev);
    }, onError: (_) {});
  }

  void _onDrift(DriftEvent ev) {
    _driftCount++;
    Sfx.alert();
    Voice.speak(ev.message);
    WidgetService.updateSpeed(_speedMs, gText: 'G ${_drift.gForce.toStringAsFixed(1)}', driftLevel: ev.severity);
    if (mounted) setState(() { _lastDrift = ev; _driftShownAt = DateTime.now(); });
  }

  void _onPos(Position p) {
    _pos = p; _speedMs = p.speed < 0 ? 0 : p.speed;
    final s = WeatherController.I.confirmed, a = WeatherController.I.analysis;
    // Esprili yol uyarıları (hava kaygansa, hızlıyken, 90 sn'de bir)
    if (s != null && a != null && _speedMs * 3.6 > 50 && DateTime.now().difference(_lastWarn) > const Duration(seconds: 90)) {
      final slippery = s.temp <= 1 && (a.kind != PrecipKind.none || (s.soil0 ?? 5) <= 0);
      if (slippery) { _lastWarn = DateTime.now(); Voice.speak(Kanki.pick(Kanki.kayganYolUyari, DateTime.now().minute)); }
    }
    final r = _route;
    if (_navigating && r != null) {
      final prev = _stepIdx;
      _stepIdx = nextStepIndex(p.latitude, p.longitude, r.steps, fromIndex: _stepIdx);
      if (_stepIdx != _spokenStep || prev != _stepIdx) { _spokenStep = _stepIdx; Voice.speak(r.steps[_stepIdx].instructionTr); }
      // Rota dışı: 80 m'den uzaksa yeniden hesapla
      if (distanceToRouteM(p.latitude, p.longitude, r.geometry) > 80 && DateTime.now().difference(_lastReroute) > const Duration(seconds: 20)) { _lastReroute = DateTime.now(); _startRoute(silent: true); }
      // Varış
      if (_dest != null && haversineM(p.latitude, p.longitude, _dest!.lat, _dest!.lon) < 40) _arrived();
      _map.move(LatLng(p.latitude, p.longitude), max(_map.camera.zoom, 15));
    }
    if (mounted) setState(() {});
  }

  void _arrived() {
    if (!_navigating) return;
    _navigating = false;
    Voice.speak('Varış noktasına ulaştın kanki, eline sağlık.');
    final a = WeatherController.I.analysis, s = WeatherController.I.confirmed;
    if (a != null && a.blizzardProb > 40) Badges.award('blizzard_nav');
    if (s != null && s.temp <= 1 && _driftCount == 0 && (_route?.distanceM ?? 0) > 5000) Badges.award('calm_driver');
    setState(() { _route = null; _dest = null; _driftCount = 0; });
  }

  Future<void> _search([String? q]) async {
    final text = (q ?? _q.text).trim();
    if (text.length < 2) return;
    setState(() { _busy = true; _err = null; });
    try { final l = await _places.search(text, lat: _pos?.latitude ?? WeatherController.I.confirmed?.place.lat, lon: _pos?.longitude ?? WeatherController.I.confirmed?.place.lon); setState(() => _results = l); }
    catch (_) { setState(() => _err = 'Arama şu an çalışmadı, internetini kontrol et.'); }
    setState(() => _busy = false);
  }

  Future<void> _chip(NearbyQuery c) async {
    final lat = _pos?.latitude ?? WeatherController.I.confirmed?.place.lat, lon = _pos?.longitude ?? WeatherController.I.confirmed?.place.lon;
    if (lat == null || lon == null) return;
    setState(() { _busy = true; _err = null; });
    try { final l = await _places.nearby(lat, lon, chain: c.chain, category: c.category); setState(() { _results = l; if (l.isEmpty) _err = 'Yakında bulamadım kanki.'; }); }
    catch (_) { setState(() => _err = 'Yakındaki yerler şu an alınamadı.'); }
    setState(() => _busy = false);
  }

  Future<void> _startRoute({bool silent = false}) async {
    final d = _dest; final p = _pos ?? await Geolocator.getLastKnownPosition();
    final from = p != null ? (p.latitude, p.longitude) : (WeatherController.I.confirmed?.place.lat, WeatherController.I.confirmed?.place.lon);
    if (d == null || from.$1 == null) { setState(() => _err = 'Başlangıç konumun yok; konum iznini aç.'); return; }
    if (!silent) setState(() { _busy = true; _err = null; });
    try {
      final r = await _osrm.route([(from.$1!, from.$2!), for (final s in _stops) (s.lat, s.lon), (d.lat, d.lon)]);
      setState(() { _route = r; _stepIdx = 0; _spokenStep = -1; _navigating = true; _results = []; });
      if (!silent) Voice.speak('Rota hazır. Toplam ${(r.distanceM / 1000).toStringAsFixed(0)} kilometre.');
      final pts = r.geometry.map((e) => LatLng(e.$1, e.$2)).toList();
      _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(40)));
    } catch (_) { setState(() => _err = 'Rota hesaplanamadı (internet ya da yol bağlantısı yok).'); }
    if (mounted) setState(() => _busy = false);
  }

  static const _chipIcons = <String, IconData>{
    'Fırın': Icons.bakery_dining_outlined, 'Bakkal': Icons.storefront_outlined, 'Eczane': Icons.local_pharmacy_outlined,
    'Kafe': Icons.local_cafe_outlined, 'Benzinlik': Icons.local_gas_station_outlined, 'Hastane': Icons.local_hospital_outlined,
    'Market': Icons.shopping_cart_outlined,
  };

  /// Ücretsiz yol durumu: hava verisinden zemin tahmini.
  (String, String, Color, IconData) _road(WeatherSnapshot? s, Analysis? a) {
    if (s == null || a == null) return ('Bilinmiyor', 'Hava verisi gelince yol durumunu söylerim.', kInkSoft, Icons.help_outline_rounded);
    final ice = s.temp <= 1 && (a.kind != PrecipKind.none || (s.soil0 ?? 5) <= 0);
    if (a.kind == PrecipKind.blizzard) return ('Tipi', 'Tipi var kanki, mümkünse yola çıkma; çıkarsan çok yavaş git.', kDanger, Icons.air_rounded);
    if (ice) return ('Buzlanma riski', Kanki.pick(Kanki.yolBuzlu, s.temp.round()), kDanger, Icons.ac_unit_rounded);
    if (a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.sleet) return ('Karlı', 'Yol kaygan, yavaş git kanki, takip mesafesini iki katına çıkar.', kWarn, Icons.cloudy_snowing);
    if (a.kind == PrecipKind.rain) return ('Islak', 'Yol ıslak, ani fren yapma kanki.', kWarn, Icons.water_drop_outlined);
    if (a.fogDensity > 60) return ('Sisli', 'Görüş düştü, kısa farlarını yak kanki.', kWarn, Icons.foggy);
    return ('Kuru', 'Yol temiz kanki, keyifli sürüşler.', kGood, Icons.check_circle_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I; final s = w.confirmed, a = w.analysis;
    final pro = ProService.I.state.isPro;
    final road = _road(s, a);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 110), children: [
      _speedo(pro, road),
      if (_driftShownAt != null && DateTime.now().difference(_driftShownAt!) < const Duration(seconds: 8) && _lastDrift != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Glass(tint: const Color(0xFFFFE3E3), child: Row(children: [
          const IconBadge(Icons.warning_amber_rounded, color: kDanger, size: 42), const SizedBox(width: 12),
          Expanded(child: Text(_lastDrift!.message, style: T.body.copyWith(fontWeight: FontWeight.w800, color: kDanger))),
        ]))),
      const SectionLabel('Nereye gidiyoruz?'),
      Glass(padding: const EdgeInsets.fromLTRB(14, 14, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _q, onSubmitted: _search, textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: L10n.t('search_hint'), filled: true, fillColor: kIce,
            prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: kAccent), onPressed: _search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in PlacesService.quickChips) Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(
            avatar: Icon(_chipIcons[c.labelTr] ?? Icons.shopping_bag_outlined, size: 18, color: kAccent),
            label: Text(c.labelTr), onPressed: () { Sfx.tap(); _chip(c); })),
        ])),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 3)),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: T.small.copyWith(color: kWarn))),
        for (final r in _results) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const IconBadge(Icons.place_outlined, size: 38, color: kInkSoft),
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_dest != null) IconButton(tooltip: L10n.t('add_stop'), icon: const Icon(Icons.add_location_alt_outlined), onPressed: () => setState(() { _stops.add(r); _results = []; })),
            IconButton.filled(icon: const Icon(Icons.directions_rounded), onPressed: () { setState(() { _dest = r; _results = []; }); _startRoute(); }),
          ]),
        ),
        if (_stops.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final st in _stops) InputChip(avatar: const Icon(Icons.flag_outlined, size: 16), label: Text(st.name), onDeleted: () { setState(() => _stops.remove(st)); if (_dest != null) _startRoute(silent: true); }),
        ])),
      ])),
      if (_route != null) ...[const SectionLabel('Rota'), _routeCard(pro, s, a), const SizedBox(height: 12),
        SizedBox(height: 240, child: ClipRRect(borderRadius: BorderRadius.circular(24), child: FlutterMap(
          mapController: _map, options: MapOptions(initialCenter: LatLng(_pos?.latitude ?? 39, _pos?.longitude ?? 35), initialZoom: 10),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.skynav.app'),
            PolylineLayer(polylines: [Polyline(points: [for (final g in _route!.geometry) LatLng(g.$1, g.$2)], color: kAccent, strokeWidth: 6, borderColor: Colors.white, borderStrokeWidth: 2)]),
            MarkerLayer(markers: [
              if (_pos != null) Marker(point: LatLng(_pos!.latitude, _pos!.longitude), width: 28, height: 28, child: const Icon(Icons.navigation_rounded, color: kAccent)),
              if (_dest != null) Marker(point: LatLng(_dest!.lat, _dest!.lon), width: 32, height: 32, child: const Icon(Icons.flag_rounded, color: kDanger)),
            ]),
          ],
        )))],
      const SectionLabel('Yol güvenliği'),
      ProGate(title: 'Yol Güvenliği Süper Paketi', child: s == null || a == null ? const SizedBox() : Glass(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [
        for (final it in computeRoad(s, a, headingDeg: _pos?.heading ?? 0)) ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: Container(width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: [kGood, kWarn, kHeat, kDanger][it.level0to3.clamp(0, 3)].withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
              child: Text(it.emoji, style: const TextStyle(fontSize: 20))),
          title: Text(it.title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14.5, color: kInk)),
          subtitle: Text(it.kanki, style: T.small.copyWith(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(it.valueText, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, color: [kGood, kWarn, kHeat, kDanger][it.level0to3.clamp(0, 3)])),
          onTap: () => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.title, style: T.h1), const SizedBox(height: 10), Text(it.explain, style: T.body), const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => Voice.speak(it.explain), icon: const Icon(Icons.volume_up_rounded), label: const Text('Sesli oku')),
          ]))),
        ),
      ]))),
    ]);
  }

  Widget _speedo(bool pro, (String, String, Color, IconData) road) {
    final kmh = (_speedMs * 3.6);
    return Glass(child: Column(children: [
      Row(children: [
        SizedBox(width: 150, height: 120, child: CustomPaint(painter: _GaugePainter(kmh / 160, road.$3), child: Padding(padding: const EdgeInsets.only(top: 34), child: Column(children: [
          Text(kmh.round().toString(), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 46, fontWeight: FontWeight.w500, height: 1, color: kInk)),
          Text(L10n.t('speed_kmh'), style: T.small.copyWith(fontWeight: FontWeight.w700)),
        ])))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOL DURUMU', style: T.label),
          const SizedBox(height: 4),
          Row(children: [Icon(road.$4, color: road.$3, size: 20), const SizedBox(width: 6), Flexible(child: Text(road.$1, style: T.h2.copyWith(color: road.$3)))]),
          const SizedBox(height: 4),
          Text(road.$2, style: T.small, maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
      ]),
      const Divider(height: 22),
      Row(children: [
        const Icon(Icons.sensors_rounded, size: 18, color: kInkSoft), const SizedBox(width: 8),
        Expanded(child: Text(pro ? 'Kayma sensörü açık · G ${_drift.gForce.toStringAsFixed(2)} · yan ${_drift.lateralG.toStringAsFixed(2)}' : 'G-kuvveti & kayma sensörü', style: T.small.copyWith(color: kInk, fontWeight: FontWeight.w600))),
        pro ? const Pill('Açık', color: kGood) : const Pill('Pro', color: kPro, icon: Icons.lock_outline),
      ]),
    ]));
  }

  Widget _routeCard(bool pro, WeatherSnapshot? s, Analysis? a) {
    final r = _route!; final step = r.steps[min(_stepIdx, r.steps.length - 1)];
    EtaResult? eta; List<String> closures = [];
    if (pro && s != null && a != null) { eta = adjustedEta(baseSeconds: r.durationS, s: s, a: a); closures = closureWarnings(s: s, a: a); }
    String fmt(Duration d) => d.inHours > 0 ? '${d.inHours} sa ${d.inMinutes % 60} dk' : '${d.inMinutes} dk';
    return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const IconBadge(Icons.turn_right_rounded, size: 48), const SizedBox(width: 12),
        Expanded(child: Text(step.instructionTr, style: T.h2)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _kv('Mesafe', '${(r.distanceM / 1000).toStringAsFixed(1)} km')),
        Expanded(child: _kv('Normal süre', fmt(Duration(seconds: r.durationS.round())))),
        Expanded(child: _kv('Hava dahil', eta == null ? 'Pro' : fmt(eta.eta), color: eta == null ? kPro : kAccent)),
      ]),
      if (eta != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(eta.reasonTr, style: T.small)),
      for (final c in closures) Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.landscape_outlined, size: 16, color: kWarn), const SizedBox(width: 6), Expanded(child: Text(c, style: T.small.copyWith(color: kInk))),
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => setState(() { _navigating = !_navigating; }),
            icon: Icon(_navigating ? Icons.pause_rounded : Icons.navigation_rounded), label: Text(_navigating ? L10n.t('stop_route') : L10n.t('start_route')))),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: () => setState(() { _route = null; _dest = null; _navigating = false; _stops.clear(); }), child: const Text('İptal')),
      ]),
    ]));
  }

  Widget _kv(String k, String v, {Color color = kInk}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trUpper(k), style: T.label.copyWith(fontSize: 10.5)), const SizedBox(height: 2), Text(v, style: T.num.copyWith(fontSize: 17, color: color)),
      ]);
}

class _GaugePainter extends CustomPainter {
  final double v; final Color color;
  _GaugePainter(this.v, this.color);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromCircle(center: Offset(s.width / 2, s.height * .62), radius: s.width / 2 - 8);
    const start = pi * .8, sweep = pi * 1.4;
    c.drawArc(r, start, sweep, false, Paint()..color = kLine..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
    if (v > 0) c.drawArc(r, start, sweep * v.clamp(0.0, 1.0), false, Paint()..shader = SweepGradient(startAngle: start, endAngle: start + sweep, colors: [kAccent, color], transform: const GradientRotation(0)).createShader(r)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.v != v || o.color != color;
}
