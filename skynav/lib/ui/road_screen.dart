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

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I; final s = w.confirmed, a = w.analysis;
    final pro = ProService.I.state.isPro;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
      _speedo(pro),
      if (_driftShownAt != null && DateTime.now().difference(_driftShownAt!) < const Duration(seconds: 8) && _lastDrift != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Glass(tint: const Color(0xFFFFE0E0), child: Text('🚨 ${_lastDrift!.message}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC62828))))),
      Glass(child: Column(children: [
        TextField(controller: _q, onSubmitted: _search, decoration: InputDecoration(hintText: L10n.t('search_hint'), prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search))),
        const SizedBox(height: 8),
        SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in PlacesService.quickChips) Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(label: Text('${c.emoji} ${c.labelTr}'), onPressed: () { Sfx.tap(); _chip(c); })),
        ])),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Color(0xFFB26A00), fontSize: 13))),
        for (final r in _results) ListTile(dense: true, title: Text(r.name), subtitle: Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_dest != null) IconButton(tooltip: L10n.t('add_stop'), icon: const Icon(Icons.add_location_alt_outlined), onPressed: () => setState(() { _stops.add(r); _results = []; })),
            IconButton(icon: const Icon(Icons.directions, color: kAccent), onPressed: () { setState(() { _dest = r; _results = []; }); _startRoute(); }),
          ])),
        if (_stops.isNotEmpty) Wrap(spacing: 6, children: [for (final s in _stops) InputChip(label: Text('📍 ${s.name}'), onDeleted: () { setState(() => _stops.remove(s)); if (_dest != null) _startRoute(silent: true); })]),
      ])),
      const SizedBox(height: 12),
      if (_route != null) _routeCard(pro, s, a),
      const SizedBox(height: 12),
      if (_route != null) SizedBox(height: 220, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: FlutterMap(
        mapController: _map, options: MapOptions(initialCenter: LatLng(_pos?.latitude ?? 39, _pos?.longitude ?? 35), initialZoom: 10),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.skynav.app'),
          PolylineLayer(polylines: [Polyline(points: [for (final g in _route!.geometry) LatLng(g.$1, g.$2)], color: kAccent, strokeWidth: 5)]),
          MarkerLayer(markers: [
            if (_pos != null) Marker(point: LatLng(_pos!.latitude, _pos!.longitude), width: 24, height: 24, child: const Icon(Icons.navigation, color: kAccent)),
            if (_dest != null) Marker(point: LatLng(_dest!.lat, _dest!.lon), width: 30, height: 30, child: const Icon(Icons.flag, color: Colors.red)),
          ]),
        ],
      ))),
      const SizedBox(height: 14),
      ProGate(title: 'Yol Güvenliği Süper Paketi', child: s == null || a == null ? const SizedBox() : Section('🛡️ Yol Güvenliği Paketi', Column(children: [
        for (final it in computeRoad(s, a, headingDeg: _pos?.heading ?? 0)) ListTile(
          dense: true, contentPadding: EdgeInsets.zero,
          leading: Text(it.emoji, style: const TextStyle(fontSize: 22)),
          title: Text('${it.title} · ${it.valueText}', style: TextStyle(fontWeight: FontWeight.w800, color: [kInk, const Color(0xFF8A6D00), const Color(0xFFD35400), const Color(0xFFC62828)][it.level0to3.clamp(0, 3)])),
          subtitle: Text(it.kanki, style: const TextStyle(fontSize: 12)),
          onTap: () => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${it.emoji} ${it.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(it.explain), const SizedBox(height: 8), FilledButton.tonal(onPressed: () => Voice.speak(it.explain), child: const Text('🔊'))]))),
        ),
      ]))),
    ]);
  }

  Widget _speedo(bool pro) {
    final kmh = (_speedMs * 3.6);
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Glass(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(kmh.round().toString(), style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, height: 1)),
      const SizedBox(width: 8),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(L10n.t('speed_kmh'), style: const TextStyle(fontSize: 18, color: kInkSoft, fontWeight: FontWeight.w700))),
      const Spacer(),
      if (pro) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('G ${_drift.gForce.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        Text('yan ${_drift.lateralG.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: kInkSoft)),
        const Pill('kayma sensörü açık', color: Color(0xFF2E9E5B)),
      ]) else const Pill('G/kayma: Pro'),
    ])));
  }

  Widget _routeCard(bool pro, WeatherSnapshot? s, Analysis? a) {
    final r = _route!; final step = r.steps[min(_stepIdx, r.steps.length - 1)];
    EtaResult? eta; List<String> closures = [];
    if (pro && s != null && a != null) { eta = adjustedEta(baseSeconds: r.durationS, s: s, a: a); closures = closureWarnings(s: s, a: a); }
    String fmt(Duration d) => d.inHours > 0 ? '${d.inHours} sa ${d.inMinutes % 60} dk' : '${d.inMinutes} dk';
    return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('➡️ ${step.instructionTr}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('${(r.distanceM / 1000).toStringAsFixed(1)} km · normal ${fmt(Duration(seconds: r.durationS.round()))}'),
      if (eta != null) ...[
        Text('⏱️ Hava dahil varış: ${fmt(eta.eta)}', style: const TextStyle(fontWeight: FontWeight.w900, color: kAccent)),
        Text(eta.reasonTr, style: const TextStyle(fontSize: 12, color: kInkSoft)),
        for (final c in closures) Padding(padding: const EdgeInsets.only(top: 4), child: Text('⛰️ $c', style: const TextStyle(fontSize: 12))),
      ] else const Padding(padding: EdgeInsets.only(top: 4), child: Text('Akıllı varış süresi (kar/buz/tipi) Pro ile açılır.', style: TextStyle(fontSize: 12, color: kInkSoft))),
      const SizedBox(height: 8),
      Row(children: [
        FilledButton(onPressed: () => setState(() { _navigating = !_navigating; }), child: Text(_navigating ? L10n.t('stop_route') : L10n.t('start_route'))),
        const SizedBox(width: 8),
        TextButton(onPressed: () => setState(() { _route = null; _dest = null; _navigating = false; _stops.clear(); }), child: const Text('İptal')),
      ]),
    ]));
  }
}
