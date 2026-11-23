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
import '../services/location_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import '../widgets/widget_service.dart';
import 'app_icons.dart';
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

  /// Ücretsiz yol durumu: hava verisinden zemin tahmini. (etiket, kanki cümlesi, renk, ikon, seviye 0-2)
  (String, String, Color, IconData, int) _road(WeatherSnapshot? s, Analysis? a) {
    if (s == null || a == null) return ('Bilinmiyor', 'Hava verisi gelince yol durumunu söylerim.', kInkSoft, Icons.help_outline_rounded, 0);
    final ice = s.temp <= 1 && (a.kind != PrecipKind.none || (s.soil0 ?? 5) <= 0);
    if (a.kind == PrecipKind.blizzard) return ('Tipi', 'Tipi var kanki, mümkünse yola çıkma; çıkarsan çok yavaş git.', kDanger, Icons.air_rounded, 2);
    if (ice) return ('Buzlanma', Kanki.pick(Kanki.yolBuzlu, s.temp.round()), kDanger, Icons.ac_unit_rounded, 2);
    if (a.kind == PrecipKind.snow || a.kind == PrecipKind.lentilSnow || a.kind == PrecipKind.sleet) return ('Karlı', 'Yol kaygan, yavaş git kanki, takip mesafesini iki katına çıkar.', kWarn, Icons.cloudy_snowing, 1);
    if (a.kind == PrecipKind.rain) return ('Islak', 'Yol ıslak, ani fren yapma kanki.', kWarn, Icons.water_drop_outlined, 1);
    if (a.fogDensity > 60) return ('Sisli', 'Görüş düştü, kısa farlarını yak kanki.', kWarn, Icons.foggy, 1);
    return ('Kuru', 'Yol temiz kanki, keyifli sürüşler.', kGood, Icons.check_circle_outline_rounded, 0);
  }

  void _goSaved(GeoPoint2 p) {
    Sfx.tap();
    setState(() { _dest = Place(name: p.name, lat: p.lat, lon: p.lon, subtitle: 'Kayıtlı konum'); _results = []; });
    _startRoute();
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I; final s = w.confirmed, a = w.analysis;
    final pro = ProService.I.state.isPro;
    final road = _road(s, a);
    final saved = LocationService.places();
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 110), children: [
      _mapHero(road),
      if (_driftShownAt != null && DateTime.now().difference(_driftShownAt!) < const Duration(seconds: 8) && _lastDrift != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Glass(tint: const Color(0xFFFFE3E3), child: Row(children: [
          const IconBadge(Icons.warning_amber_rounded, color: kDanger, size: 42), const SizedBox(width: 12),
          Expanded(child: Text(_lastDrift!.message, style: T.body.copyWith(fontWeight: FontWeight.w800, color: kDanger))),
        ]))),
      if (_results.isNotEmpty || _busy || _err != null) ...[const SizedBox(height: 12), _resultsCard()],
      if (_route != null) ...[const SizedBox(height: 12), _tripCard(pro, s, a), const SizedBox(height: 12), _stepsCard()],
      if (_route == null) ...[
        const SectionLabel('Hızlı gidiş'),
        SizedBox(height: 86, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final p in saved) _QuickDest(icon: p.name.toLowerCase().contains('ev') ? Icons.home_rounded : Icons.bookmark_rounded, title: p.name, sub: 'Kayıtlı', color: kAccent, onTap: () => _goSaved(p)),
          if (saved.isEmpty) const _QuickDest(icon: Icons.add_location_alt_rounded, title: 'Ev ekle', sub: 'Hava ekranı › Konum', color: kInkSoft),
          for (final c in PlacesService.quickChips.take(7)) _QuickDest(icon: _chipIcons[c.labelTr] ?? Icons.shopping_bag_outlined, title: c.labelTr, sub: 'Yakınında', color: kGood, onTap: () { Sfx.tap(); _chip(c); }),
        ])),
      ],
      const SectionLabel('Sürüş'),
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _speedBlock(pro)),
        const SizedBox(width: 12),
        Expanded(child: _roadBlock(road, s)),
      ])),
      if (_route == null) ...[
        const SectionLabel('Marketler'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in PlacesService.quickChips.skip(7)) ActionChip(avatar: const Icon(Icons.shopping_basket_outlined, size: 18, color: kAccent), label: Text(c.labelTr), onPressed: () { Sfx.tap(); _chip(c); }),
        ]),
      ],
      const SectionLabel('Yol güvenliği'),
      ProGate(title: 'Yol Güvenliği Süper Paketi', child: s == null || a == null ? const SizedBox() : Glass(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [
        for (final it in computeRoad(s, a, headingDeg: _pos?.heading ?? 0)) ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: Container(width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: [kGood, kWarn, kHeat, kDanger][it.level0to3.clamp(0, 3)].withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
              child: Icon(roadIcon(it.id), size: 20, color: [kGood, kWarn, kHeat, kDanger][it.level0to3.clamp(0, 3)])),
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

  // ── Harita kahramanı: canlı konum, rota çizgisi, üstte arama, rota varken manevra bandı ──
  Widget _mapHero((String, String, Color, IconData, int) road) {
    final here = LatLng(_pos?.latitude ?? WeatherController.I.confirmed?.place.lat ?? 39, _pos?.longitude ?? WeatherController.I.confirmed?.place.lon ?? 35);
    final r = _route;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(height: r == null ? 300 : 340, child: Stack(children: [
        Positioned.fill(child: FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: here, initialZoom: r == null ? 14 : 11, interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom)),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.skynav.app'),
            if (r != null) PolylineLayer(polylines: [
              Polyline(points: [for (final g in r.geometry) LatLng(g.$1, g.$2)], color: Colors.white, strokeWidth: 10),
              Polyline(points: [for (final g in r.geometry) LatLng(g.$1, g.$2)], color: kAccent, strokeWidth: 6),
            ]),
            MarkerLayer(markers: [
              Marker(point: here, width: 44, height: 44, child: const _LiveDot()),
              if (_dest != null) Marker(point: LatLng(_dest!.lat, _dest!.lon), width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(Icons.location_on_rounded, color: kDanger, size: 40)),
            ]),
          ],
        )),
        // Üst kenar yumuşatma (arama çubuğu okunsun)
        Positioned(left: 0, right: 0, top: 0, height: 90, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)]))))),
        Positioned(left: 12, right: 12, top: 12, child: r == null ? _searchBar() : _maneuverBanner()),
        Positioned(right: 12, bottom: 12, child: Glass(radius: 16, padding: const EdgeInsets.all(10), onTap: () { if (_pos != null) _map.move(LatLng(_pos!.latitude, _pos!.longitude), 15); }, child: const Icon(Icons.my_location_rounded, color: kAccent, size: 22))),
        Positioned(left: 12, bottom: 12, child: _Chip(icon: road.$4, text: 'Yol: ${road.$1}', color: road.$3)),
      ])),
    );
  }

  Widget _searchBar() => Glass(
        radius: 20, padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: kInkSoft),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _q, onSubmitted: _search, textInputAction: TextInputAction.search,
            style: T.body,
            decoration: InputDecoration(hintText: 'Nereye gidiyoruz kanki?', hintStyle: T.body.copyWith(color: kInkFaint), border: InputBorder.none),
          )),
          IconButton.filled(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
        ]),
      );

  Widget _maneuverBanner() {
    final r = _route!; final i = min(_stepIdx, r.steps.length - 1); final st = r.steps[i];
    final toNext = _pos == null ? st.distanceM : haversineM(_pos!.latitude, _pos!.longitude, st.lat, st.lon);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: const Color(0xFF14233A), borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)]),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(16)),
            child: Icon(_maneuverIcon(st), color: Colors.white, size: 32)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtDist(toNext), style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -.6)),
          Text(st.phraseTr.isEmpty ? st.instructionTr : st.phraseTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC9D6E6))),
          if (st.streetName.isNotEmpty) Text(st.streetName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8FA3BC))),
        ])),
      ]),
    );
  }

  IconData _maneuverIcon(RouteStep st) {
    if (st.maneuverType == 'arrive') return Icons.flag_rounded;
    if (st.maneuverType.contains('roundabout') || st.maneuverType == 'rotary') return Icons.roundabout_right_rounded;
    switch (st.modifier) {
      case 'left': return Icons.turn_left_rounded;
      case 'right': return Icons.turn_right_rounded;
      case 'slight left': return Icons.turn_slight_left_rounded;
      case 'slight right': return Icons.turn_slight_right_rounded;
      case 'sharp left': return Icons.turn_sharp_left_rounded;
      case 'sharp right': return Icons.turn_sharp_right_rounded;
      case 'uturn': return Icons.u_turn_left_rounded;
      default: return Icons.straight_rounded;
    }
  }

  String _fmtDist(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km' : '${(m / 10).round() * 10} m';
  String _fmtDur(Duration d) => d.inHours > 0 ? '${d.inHours} sa ${d.inMinutes % 60} dk' : '${d.inMinutes} dk';

  Widget _resultsCard() => Glass(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 3)),
        if (_err != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_err!, style: T.small.copyWith(color: kWarn))),
        for (final r in _results) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const IconBadge(Icons.place_outlined, size: 38, color: kInkSoft),
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(r.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_dest != null) IconButton(tooltip: L10n.t('add_stop'), icon: const Icon(Icons.add_location_alt_outlined), onPressed: () => setState(() { _stops.add(r); _results = []; })),
            IconButton.filled(icon: const Icon(Icons.directions_rounded), onPressed: () { setState(() { _dest = r; _results = []; }); _startRoute(); }),
          ]),
        ),
      ]));

  // ── Yolculuk kartı: kalan mesafe, süre, hava dahil varış, varış saati, ilerleme ──
  Widget _tripCard(bool pro, WeatherSnapshot? s, Analysis? a) {
    final r = _route!;
    final i = min(_stepIdx, r.steps.length - 1);
    var remaining = 0.0; for (var k = i; k < r.steps.length; k++) { remaining += r.steps[k].distanceM; }
    final progress = r.distanceM <= 0 ? 0.0 : (1 - remaining / r.distanceM).clamp(0.0, 1.0);
    EtaResult? eta; List<String> closures = [];
    if (pro && s != null && a != null) { eta = adjustedEta(baseSeconds: r.durationS * (remaining / max(1, r.distanceM)), s: s, a: a); closures = closureWarnings(s: s, a: a); }
    final base = Duration(seconds: (r.durationS * (remaining / max(1, r.distanceM))).round());
    final arrive = DateTime.now().add(eta?.eta ?? base);
    return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_dest?.name ?? 'Varış', style: T.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Varış ${arrive.hour.toString().padLeft(2, '0')}:${arrive.minute.toString().padLeft(2, '0')}${_stops.isEmpty ? '' : ' · ${_stops.length} ara durak'}', style: T.small),
        ])),
        _Chip(icon: _navigating ? Icons.navigation_rounded : Icons.pause_rounded, text: _navigating ? 'Yolda' : 'Hazır', color: _navigating ? kGood : kInkSoft),
      ]),
      const SizedBox(height: 14),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 8, color: kAccent, backgroundColor: kAccent.withValues(alpha: .12))),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _kv('Kalan', _fmtDist(remaining))),
        Expanded(child: _kv('Normal', _fmtDur(base))),
        Expanded(child: _kv('Hava dahil', eta == null ? 'Pro' : _fmtDur(eta.eta), color: eta == null ? kPro : (eta.factor < .9 ? kWarn : kGood))),
      ]),
      if (eta != null && eta.factor < .98) Padding(padding: const EdgeInsets.only(top: 10), child: _Note(Icons.schedule_rounded, eta.reasonTr, kWarn)),
      for (final c in closures) Padding(padding: const EdgeInsets.only(top: 8), child: _Note(Icons.landscape_outlined, c, kDanger)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () { Sfx.tap(); setState(() { _navigating = !_navigating; }); },
            icon: Icon(_navigating ? Icons.pause_rounded : Icons.navigation_rounded), label: Text(_navigating ? L10n.t('stop_route') : L10n.t('start_route')))),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: () => setState(() { _route = null; _dest = null; _navigating = false; _stops.clear(); }), child: const Text('Bitir')),
      ]),
    ]));
  }

  Widget _stepsCard() {
    final r = _route!; final i = min(_stepIdx, r.steps.length - 1);
    final next = r.steps.skip(i + 1).take(4).toList();
    if (next.isEmpty) return const SizedBox.shrink();
    return Glass(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SONRAKİ ADIMLAR', style: T.label),
      const SizedBox(height: 6),
      for (final st in next) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: kAccent.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(_maneuverIcon(st), color: kAccent, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(st.phraseTr.isEmpty ? st.instructionTr : '${st.phraseTr}${st.streetName.isEmpty ? '' : ' · ${st.streetName}'}', style: T.body.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
        Text(_fmtDist(st.distanceM), style: T.small.copyWith(fontWeight: FontWeight.w700)),
      ])),
    ]));
  }

  // ── Hız bloğu (kadran) ──
  Widget _speedBlock(bool pro) {
    final kmh = _speedMs * 3.6;
    return Glass(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [const Text('HIZ', style: T.label), const Spacer(), pro ? const _Chip(icon: Icons.sensors_rounded, text: 'Kayma', color: kGood) : const _Chip(icon: Icons.lock_outline, text: 'G', color: kPro)]),
      SizedBox(height: 118, width: double.infinity, child: CustomPaint(painter: _GaugePainter(kmh / 160, kmh > 110 ? kDanger : kmh > 80 ? kWarn : kAccent), child: Padding(padding: const EdgeInsets.only(top: 38), child: Column(children: [
        Text(kmh.round().toString(), style: const TextStyle(fontFamily: 'InterDisplay', fontSize: 40, fontWeight: FontWeight.w500, height: 1, color: kInk)),
        Text(L10n.t('speed_kmh'), style: T.small.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
      ])))),
      if (pro) Text('G ${_drift.gForce.toStringAsFixed(2)} · yan ${_drift.lateralG.toStringAsFixed(2)}', style: T.small.copyWith(fontSize: 11.5)),
    ]));
  }

  // ── Yol durumu bloğu: çizilmiş asfalt şeridi ──
  Widget _roadBlock((String, String, Color, IconData, int) road, WeatherSnapshot? s) => Glass(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOL DURUMU', style: T.label),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(height: 62, width: double.infinity, child: CustomPaint(painter: _AsphaltPainter(road.$1)))),
          const SizedBox(height: 10),
          Row(children: [Icon(road.$4, color: road.$3, size: 18), const SizedBox(width: 6), Flexible(child: Text(road.$1, style: T.h2.copyWith(color: road.$3, fontSize: 17)))]),
          const SizedBox(height: 2),
          Text(s?.soil0 == null ? road.$2 : 'Yüzey ${s!.soil0!.toStringAsFixed(1)}° · ${road.$2}', style: T.small.copyWith(fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _kv(String k, String v, {Color color = kInk}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trUpper(k), style: T.label.copyWith(fontSize: 10.5)), const SizedBox(height: 2), Text(v, style: T.num.copyWith(fontSize: 17, color: color)),
      ]);
}

class _QuickDest extends StatelessWidget {
  final IconData icon; final String title, sub; final Color color; final VoidCallback? onTap;
  const _QuickDest({required this.icon, required this.title, required this.sub, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10, bottom: 6),
        child: Glass(radius: 22, padding: const EdgeInsets.fromLTRB(12, 12, 16, 12), onTap: onTap, child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icon, color: color, size: 42),
          const SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(sub, style: T.small.copyWith(fontSize: 11.5)),
          ]),
        ])),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _Chip({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color), const SizedBox(width: 5),
          Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _Note extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _Note(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: color), const SizedBox(width: 10),
          Expanded(child: Text(text, style: T.small.copyWith(color: kInk))),
        ]),
      );
}

/// Canlı konum: nabız gibi atan halka.
class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) => Stack(alignment: Alignment.center, children: [
        Container(width: 16 + 28 * _c.value, height: 16 + 28 * _c.value, decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withValues(alpha: .35 * (1 - _c.value)))),
        Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent, border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 6)])),
      ]));
}

class _GaugePainter extends CustomPainter {
  final double v; final Color color;
  _GaugePainter(this.v, this.color);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromCircle(center: Offset(s.width / 2, s.height * .62), radius: min(s.width, s.height * 1.3) / 2 - 8);
    const start = pi * .8, sweep = pi * 1.4;
    c.drawArc(r, start, sweep, false, Paint()..color = kLine..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
    for (var i = 0; i <= 8; i++) {
      final a = start + sweep * i / 8;
      final o = r.center + Offset(cos(a), sin(a)) * (r.width / 2 - 14);
      c.drawCircle(o, 1.6, Paint()..color = kInkFaint);
    }
    if (v > 0) c.drawArc(r, start, sweep * v.clamp(0.0, 1.0), false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.v != v || o.color != color;
}

/// Asfalt şeridi: koşula göre kar lekeleri, buz parlaması, ıslak yansıma ya da sis.
class _AsphaltPainter extends CustomPainter {
  final String cond;
  _AsphaltPainter(this.cond);
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A5566), Color(0xFF353E4C)]).createShader(rect));
    final edge = Paint()..color = Colors.white.withValues(alpha: .85)..strokeWidth = 2;
    c.drawLine(Offset(0, 8), Offset(s.width, 8), edge);
    c.drawLine(Offset(0, s.height - 8), Offset(s.width, s.height - 8), edge);
    final dash = Paint()..color = const Color(0xFFF2C94C)..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (var x = 6.0; x < s.width; x += 26) { c.drawLine(Offset(x, s.height / 2), Offset(x + 13, s.height / 2), dash); }
    final rnd = Random(3);
    switch (cond) {
      case 'Karlı':
      case 'Tipi':
        for (var i = 0; i < 16; i++) {
          final o = Offset(rnd.nextDouble() * s.width, 6 + rnd.nextDouble() * (s.height - 12));
          c.drawOval(Rect.fromCenter(center: o, width: 14 + rnd.nextDouble() * 26, height: 5 + rnd.nextDouble() * 6), Paint()..color = Colors.white.withValues(alpha: .85)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        }
        if (cond == 'Tipi') { for (var i = 0; i < 5; i++) { final y = 10 + i * 10.0; c.drawLine(Offset(0, y), Offset(s.width, y - 6), Paint()..color = Colors.white.withValues(alpha: .35)..strokeWidth = 2); } }
        break;
      case 'Buzlanma':
        c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFFBFE3FF).withValues(alpha: .05), const Color(0xFFBFE3FF).withValues(alpha: .45), const Color(0xFFBFE3FF).withValues(alpha: .05)], stops: const [.2, .5, .8]).createShader(rect));
        for (var i = 0; i < 4; i++) { final x = 20 + i * s.width / 4; c.drawLine(Offset(x, 14), Offset(x + 18, s.height - 14), Paint()..color = Colors.white.withValues(alpha: .55)..strokeWidth = 1.4); }
        break;
      case 'Islak':
        for (var i = 0; i < 7; i++) {
          final o = Offset(rnd.nextDouble() * s.width, 12 + rnd.nextDouble() * (s.height - 24));
          c.drawOval(Rect.fromCenter(center: o, width: 24 + rnd.nextDouble() * 30, height: 4), Paint()..color = const Color(0xFF9CC7F0).withValues(alpha: .45));
        }
        break;
      case 'Sisli':
        c.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: .45));
        break;
    }
  }
  @override
  bool shouldRepaint(covariant _AsphaltPainter o) => o.cond != cond;
}
