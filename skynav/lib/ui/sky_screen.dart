import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../astro/astro_math.dart';
import '../astro/celestrak_service.dart';
import '../astro/constellations.dart';
import '../astro/space_events.dart';
import '../astro/space_extras.dart';
import '../astro/space_weather_service.dart';
import '../astro/star_catalog.dart';
import '../data/models.dart';
import '../engine/formulas.dart' show windDirName;
import '../game/badges.dart';
import '../l10n/l10n.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import 'bento.dart';
import 'clouds.dart';
import 'sky_bodies.dart';
import 'hero_scene.dart' show moonLitPath;
import 'theme.dart';
import 'widgets.dart';

/// Gökyüzü & Astronomi. Ücretsiz: temel gece gökyüzü (sürükleyerek bak).
/// Pro: sensörle 360° kubbe, Bulutları Kapat (X-Ray), Zaman Makinesi, uydu nişangahı ve uzay laboratuvarı.
class SkyScreen extends StatefulWidget {
  const SkyScreen({super.key});
  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen> {
  double _lat = 41, _lon = 29, _alt = 0;
  double _az = 0, _pitch = 35; // bakış yönü (derece)
  double _fov = 80, _fov0 = 80;
  double _hours = 0; // zaman makinesi (saat)
  bool _xray = false, _sensor = false, _red = false;
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<MagnetometerEvent>? _mag;
  List<double> _g = [0, 0, 9.8], _m = [0, 20, -40];
  Timer? _tick, _issTimer;
  List<Sat> _iss = [], _starlink = [], _debris = [];
  PassInfo? _issPass; bool _aimShown = false; String? _aimText; double _aimAz = 0, _aimAlt = 0;
  SpaceWeather? _sw; String? _swErr;
  int _starlinkUp = 0;

  /// Gündüz açılınca boş mavi kubbe yerine bu gecenin 22:00 gökyüzü gösterilir.
  bool get _tonight => _hours == 0 && sunAltitude(_lat, _lon, DateTime.now().toUtc()) > -6;
  DateTime get _now {
    if (_tonight) { final n = DateTime.now(); return DateTime(n.year, n.month, n.day, 22).toUtc(); }
    return DateTime.now().toUtc().add(Duration(minutes: (_hours * 60).round()));
  }

  @override
  void initState() {
    super.initState();
    final p = WeatherController.I.confirmed?.place ?? LocationService.lastKnown ?? LocationService.fallback;
    _lat = p.lat; _lon = p.lon; _alt = p.elevation ?? 0;
    _tick = Timer.periodic(const Duration(seconds: 2), (_) { if (mounted && _hours == 0) setState(() {}); });
    if (ProService.I.state.isPro) _loadSpace();
  }

  @override
  void dispose() { _acc?.cancel(); _mag?.cancel(); _tick?.cancel(); _issTimer?.cancel(); super.dispose(); }

  Future<void> _loadSpace() async {
    try { _iss = await fetchGroup('stations'); } catch (_) {}
    try { _starlink = (await fetchGroup('starlink')).take(400).toList(); } catch (_) {}
    try { _debris = (await fetchGroup('cosmos-1408-debris')).take(200).toList(); } catch (_) {}
    try { _sw = await fetchSpaceWeather(_lat, _lon); } catch (_) { _swErr = 'Uzay havası şu an alınamadı.'; }
    _issTimer?.cancel();
    _issTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkIss());
    _checkIss();
    if (mounted) setState(() {});
  }

  /// ISS geçişine 2 dk kala neon nişangah + sesli yönlendirme.
  void _checkIss() {
    final obs = GeoObserver(_lat, _lon, _alt);
    final stationList = _iss.where((s) => s.name.toUpperCase().contains('ISS')).toList();
    if (stationList.isEmpty) return;
    final iss = stationList.first;
    _issPass ??= nextPass(iss, obs, DateTime.now().toUtc(), horizon: const Duration(hours: 12));
    final pass = _issPass;
    if (pass == null) return;
    final until = pass.start.difference(DateTime.now().toUtc());
    if (until.isNegative && DateTime.now().toUtc().isAfter(pass.end)) { _issPass = null; _aimShown = false; return; }
    if (until <= const Duration(minutes: 2)) {
      final la = lookAngles(iss, obs, DateTime.now().toUtc());
      if (la != null) {
        final dir = windDirName(la.azDeg);
        _aimAz = la.azDeg; _aimAlt = la.altDeg;
        _aimText = la.altDeg > 0 ? 'Kanki başını $dir yönüne, ${la.altDeg.round()} derece yukarı kaldır; ISS şu an parlak bir yıldız gibi süzülüyor!' : 'ISS ${until.inSeconds > 0 ? '${until.inMinutes + 1} dk içinde' : 'birazdan'} $dir tarafından yükselecek, hazır ol kanki!';
        if (!_aimShown) { _aimShown = true; Voice.speak(_aimText!); Notify.show('ISS geliyor', _aimText!); }
        if (mounted) setState(() {});
      }
    }
  }

  void _toggleSensor(bool v) {
    _sensor = v;
    _acc?.cancel(); _mag?.cancel();
    if (v) {
      _acc = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) => _g = [e.x, e.y, e.z]);
      _mag = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        _m = [e.x, e.y, e.z];
        _updateOrientation();
      });
    }
    setState(() {});
  }

  /// Telefonun arka kamera ekseninin gökyüzünde baktığı yön (azimut/yükseklik).
  void _updateOrientation() {
    final gx = _g[0], gy = _g[1], gz = _g[2];
    final gn = sqrt(gx * gx + gy * gy + gz * gz); if (gn < 1) return;
    // Telefon dikey tutulduğunda arka kamera = -Z. Yükseklik: yerçekimine göre.
    final pitch = asin((-gz / gn).clamp(-1.0, 1.0)) * 180 / pi * -1; // dik tutunca ~0, yukarı kaldırınca +
    final up = [gx / gn, gy / gn, gz / gn];
    // Doğu = m × up ; Kuzey = up × doğu
    List<double> cross(List<double> a, List<double> b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
    final east = cross(_m, up); final en = sqrt(east[0] * east[0] + east[1] * east[1] + east[2] * east[2]); if (en < 1e-6) return;
    final e = [east[0] / en, east[1] / en, east[2] / en]; final n = cross(up, e);
    final fwd = [0.0, 0.0, -1.0]; // arka kamera yönü
    final fe = fwd[0] * e[0] + fwd[1] * e[1] + fwd[2] * e[2], fn = fwd[0] * n[0] + fwd[1] * n[1] + fwd[2] * n[2];
    var az = atan2(fe, fn) * 180 / pi; if (az < 0) az += 360;
    final fu = fwd[0] * up[0] + fwd[1] * up[1] + fwd[2] * up[2];
    final alt = asin(fu.clamp(-1.0, 1.0)) * 180 / pi;
    if (mounted) setState(() { _az = _lerpAngle(_az, az, .25); _pitch = _pitch + (alt - _pitch) * .25; });
    if (pitch.isNaN) return;
  }

  double _lerpAngle(double a, double b, double t) { var d = ((b - a + 540) % 360) - 180; return (a + d * t + 360) % 360; }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I; final s = w.confirmed, a = w.analysis;
    final cloud = (s?.cloudCover ?? 0) / 100;
    final cloudy = (s?.cloudCover ?? 0) > 75;
    final t = _now;
    final moon = moonPhaseInfo(t);
    final nextShower = nextMeteorShower(t); final eclipse = nextEclipse(t);
    final stars = a == null ? 0 : a.starClarity;
    const dark = Color(0xFF0B1330);
    final mainCol = ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 120), children: [
      // Kubbe
      ClipRRect(borderRadius: BorderRadius.circular(34), child: SizedBox(height: 380, child: Stack(children: [
        Positioned.fill(child: LayoutBuilder(builder: (_, c) => GestureDetector(
          onScaleStart: (_) => _fov0 = _fov,
          onScaleUpdate: (d) {
            if (_sensor) return;
            setState(() {
              if (d.pointerCount > 1) { _fov = (_fov0 / d.scale).clamp(40.0, 120.0); return; }
              _az = (_az - d.focalPointDelta.dx * _fov / 360 + 360) % 360;
              _pitch = (_pitch + d.focalPointDelta.dy * .2).clamp(-10, 90);
            });
          },
          onTapUp: (d) => _tapSky(d.localPosition, Size(c.maxWidth, c.maxHeight)),
          child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _DomePainter(lat: _lat, lon: _lon, t: t, az: _az, pitch: _pitch, fov: _fov, cloud: _xray || CloudShader.ready ? 0 : cloud, iss: _aimShown ? (_aimAz, _aimAlt) : null, sats: _satPoints(t), planetsOn: true)),
        ))),
        if (!_xray && cloud > .03) Positioned.fill(child: IgnorePointer(child: LayoutBuilder(builder: (_, c) => CloudLayer(spec: _domeClouds(cloud, t, c.biggest))))),
        Positioned(left: 16, top: 16, right: 16, child: Wrap(spacing: 6, runSpacing: 6, children: [
          if (_tonight) const _DarkPill(Icons.schedule_rounded, 'Bu gece 22:00'),
          _DarkPill(cloudy && !_xray ? Icons.cloud_rounded : Icons.auto_awesome, cloudy && !_xray ? 'Gökyüzü kapalı' : 'Netlik %${stars.round()}'),
        ])),
        Positioned(left: 16, bottom: 16, child: _DarkPill(Icons.explore_outlined, '${windDirName(_az)} ${_az.round()}° · yükseklik ${_pitch.round()}°')),
        Positioned(right: 12, bottom: 12, child: Column(children: [
          _RoundDark(Icons.add_rounded, 'Yakınlaş', () => setState(() => _fov = (_fov - 15).clamp(40, 120))),
          const SizedBox(height: 8),
          _RoundDark(Icons.remove_rounded, 'Uzaklaş', () => setState(() => _fov = (_fov + 15).clamp(40, 120))),
        ])),
        if (_aimShown && _aimText != null) Positioned(left: 12, right: 64, bottom: 56, child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: dark.withValues(alpha: .9), borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.gps_fixed_rounded, color: Color(0xFF7DF9FF), size: 18), const SizedBox(width: 8),
            Expanded(child: Text(_aimText!, style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF7DF9FF), fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
        )),
      ]))),
      const SizedBox(height: 14),
      BentoRow(height: 200, left: MoonBlock(now: t, south: _lat < 0, lat: _lat, lon: _lon), right: _ClarityBlock(clarity: cloudy ? 0.0 : stars.toDouble(), cloudy: cloudy)),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: ProGate(title: 'Sensörlü 360° Kubbe, Bulutları Kapat & Zaman Makinesi', child: Section('Pro gökyüzü araçları', dot: kPro, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SwitchRow(Icons.screen_rotation_alt_rounded, kAccent, '360° sensör modu', 'Telefonu gökyüzüne tut, harita seninle döner', _sensor, _toggleSensor),
        _SwitchRow(Icons.cloud_off_rounded, kSnow, '${L10n.t('x_ray_sky')} (X-Ray)', 'Bulutlar silinir, arkadaki yıldız/gezegen/uydular görünür', _xray, (v) => setState(() => _xray = v)),
        _SwitchRow(Icons.visibility_rounded, kDanger, L10n.t('red_mode'), 'Gece görüşünü koruyan kırmızı ekran', _red, (v) => setState(() => _red = v)),
        const Divider(),
        Row(children: [
          const IconBadge(Icons.history_toggle_off_rounded, color: kPro, size: 34), const SizedBox(width: 12),
          Expanded(child: Text('${L10n.t('time_machine')}: ${_hours == 0 ? 'şimdi' : '${_hours > 0 ? '+' : ''}${_hours.round()} saat'}', style: T.body.copyWith(fontWeight: FontWeight.w700))),
          if (_hours != 0) TextButton(onPressed: () => setState(() => _hours = 0), child: const Text('Şimdiye dön')),
        ]),
        Slider(min: -720, max: 720, divisions: 288, value: _hours, onChanged: (v) => setState(() => _hours = v)),
        Text('Ay: ${moon.nameTr} · aydınlanma %${(moon.illumination * 100).round()} · yaş ${moon.ageDays.toStringAsFixed(1)} gün', style: T.small),
        Text(_snowSim(s), style: T.small),
      ])))),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: ProGate(title: 'Uzay Laboratuvarı', child: Section('Uzay laboratuvarı', dot: const Color(0xFF00B8D9), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InfoRow(Icons.satellite_alt_rounded, _issPass == null ? 'ISS: geçiş hesaplanıyor…' : 'ISS sonraki geçiş ${_issPass!.start.toLocal().toString().substring(5, 16)} · tepe ${_issPass!.peakAltDeg.round()}°',
            sub: _issPass == null ? null : (_issPass!.visibleToEye ? 'Çıplak gözle görünür' : 'Görünmeyebilir'), color: const Color(0xFF00B8D9)),
        InfoRow(Icons.blur_on_rounded, 'Starlink (ilk 400 uydudan) şu an ufuk üstünde: $_starlinkUp', color: kInkSoft),
        InfoRow(Icons.scatter_plot_rounded, 'Uzay çöpü takibi: ${_debris.length} parça listede', color: kInkSoft),
        const Divider(),
        InfoRow(Icons.wb_sunny_rounded, _sw == null ? (_swErr ?? 'Güneş fırtınası verisi alınıyor…') : 'Kp ${_sw!.kp.toStringAsFixed(1)} · ${_sw!.stormLevelTr}',
            sub: _sw == null ? null : 'Burada aurora ihtimali %${_sw!.auroraProbAtLat.round()}', color: kSun),
        InfoRow(Icons.auto_awesome_rounded, 'Sıradaki meteor yağmuru: ${nextShower.shower.name}', sub: '${nextShower.peakUtc.toLocal().toString().substring(0, 10)} · saatte ~${nextShower.shower.zhr}', color: kPro),
        if (eclipse != null) InfoRow(Icons.brightness_3_rounded, 'Sıradaki tutulma: ${eclipse.kind} (${eclipse.type}) · ${eclipse.utcDay.toString().substring(0, 10)}', sub: '${countdownText(eclipse.utcDay.difference(DateTime.now().toUtc()))} · ${eclipse.visibleIn}', color: kInk),
        for (final c in comets) InfoRow(Icons.flare_rounded, '${c.name}: ${c.noteTr}', color: kSnow),
        const Divider(),
        for (final l in moonVsMars()) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l, style: T.small)),
        const Divider(),
        InfoRow(Icons.wifi_tethering_rounded, starlinkSignalQuality(cloudCover: s?.cloudCover ?? 0, precipMm: s?.precip ?? 0, windMs: s?.windSpeed ?? 0, horizonObstructionPct: 10).noteTr, color: kGood),
        InfoRow(Icons.public_rounded, 'Dünya\'nın dönüş hızı burada ${earthRotationSpeedMs(_lat).toStringAsFixed(0)} m/sn', sub: 'Gölge boyu: ${_shadow()}', color: kAccent),
        InfoRow(Icons.explore_rounded, polarisAltitudeNote(_lat), color: kWarn),
        Text(compassCalibrationNote, style: T.small.copyWith(fontSize: 12)),
      ])))),
      Section('${constellations.length} takımyıldız', trailing: const Text('dokun, anlatsın', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: kInkSoft)),
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final c in constellations) Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(label: Text(c.nameTr), onPressed: () => _tell(c))),
      ]))),
    ]);
    if (!_red) return mainCol;
    return ColorFiltered(colorFilter: const ColorFilter.matrix([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]), child: mainCol);
  }

  /// Kubbedeki bulutlar: gerçek örtü; gündüz beyaz, gece ay ışığında gri-mavi. Bakış yönüyle birlikte kayar.
  CloudSpec _domeClouds(double cover, DateTime t, Size size) {
    final day = sunAltitude(_lat, _lon, t) > 0;
    final s = WeatherController.I.confirmed;
    final wet = s != null && (s.precip > .1);
    return CloudSpec(
      cover: cover, horizon: 1.0, scale: 120 * 80 / _fov, sun: const Offset(.5, .1), seed: 5.1,
      offset: Offset(_az * size.width / _fov, -_pitch * size.height / _fov),
      lit: day ? (wet ? const Color(0xFFD5DCE5) : Colors.white) : const Color(0xFF5E6884),
      shade: day ? (wet ? const Color(0xFF56616F) : const Color(0xFFA9B8CA)) : const Color(0xFF1E2438),
      weight: wet ? .9 : (day ? .2 : .55), opacity: day ? .96 : .9,
      wind: Offset(-.01 - (s?.windSpeed ?? 3) * .001, 0),
    );
  }

  String _shadow() {
    final alt = sunAltitude(_lat, _lon, _now);
    if (alt <= 1) return 'güneş ufukta/altında';
    return '1 m boy için ${shadowLengthRatio(alt).toStringAsFixed(1)} m';
  }

  String _snowSim(WeatherSnapshot? s) {
    if (s == null) return '';
    final days = (_hours / 24).round();
    if (days < 0) return 'Geçmiş kar örtüsü için kayıt tutulmuyor; yalnızca gökyüzü ve Ay oynatılır.';
    if (days == 0) return 'Kar örtüsü şimdi: ${((s.snowDepthM ?? 0) * 100).round()} cm.';
    if (days >= s.daily.length) return 'Kar simülasyonu 7 güne kadar (tahmini).';
    final d = s.daily[days];
    return 'Kar simülasyonu (+$days gün): ~${d.snowSum.toStringAsFixed(1)} cm yeni kar, ${d.tMin.round()}…${d.tMax.round()}°';
  }

  List<(double, double, String)> _satPoints(DateTime t) {
    final pts = <(double, double, String)>[];
    if (!ProService.I.state.isPro) return pts;
    final obs = GeoObserver(_lat, _lon, _alt);
    for (final sat in _iss) { final la = lookAngles(sat, obs, t); if (la != null && la.altDeg > 0) pts.add((la.azDeg, la.altDeg, sat.name)); }
    var up = 0;
    for (final sat in _starlink) { final la = lookAngles(sat, obs, t); if (la != null && la.altDeg > 0) { up++; if (pts.length < 60) pts.add((la.azDeg, la.altDeg, '')); } }
    _starlinkUp = up;
    return pts;
  }

  void _tapSky(Offset p, Size size) {
    if (size.width == 0) return;
    // Dokunulan yöne en yakın takımyıldız merkezi
    Constellation? best; double bd = 1e9;
    for (final c in constellations) {
      final aa = raDecToAltAz(c.raDeg, c.decDeg, _lat, _lon, _now);
      final o = _project(aa.az, aa.alt, size, _az, _pitch, _fov);
      if (o == null) continue;
      final d = (o - p).distance; if (d < bd) { bd = d; best = c; }
    }
    if (best != null && bd < 60) _tell(best);
  }

  void _tell(Constellation c) {
    Sfx.tap();
    final txt = '${c.nameTr}. ${c.story}';
    Voice.speak(txt);
    final night = !(sunAltitude(_lat, _lon, DateTime.now().toUtc()) > -6);
    final clar = WeatherController.I.analysis?.starClarity ?? 0;
    if (night && clar >= 60) Badges.award('star_hunter');
    showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const IconBadge(Icons.auto_awesome_rounded, color: kPro, size: 40), const SizedBox(width: 12),
        Expanded(child: Text('${c.nameTr} (${c.latin})', style: T.h2)),
      ]),
      const SizedBox(height: 12), Text(c.story, style: T.body),
      const SizedBox(height: 14), FilledButton.icon(onPressed: () => Voice.speak(txt), icon: const Icon(Icons.volume_up_rounded), label: const Text('Tekrar anlat')),
    ])));
  }
}

/// Azimutal (stereografik) izdüşüm: bakış yönü merkezde.
Offset? _project(double azDeg, double altDeg, Size size, double viewAz, double viewAlt, double fov) {
  final az = azDeg * pi / 180, alt = altDeg * pi / 180, va = viewAz * pi / 180, vh = viewAlt * pi / 180;
  // birim vektör (x doğu, y kuzey, z yukarı)
  final x = cos(alt) * sin(az), y = cos(alt) * cos(az), z = sin(alt);
  // yönü merkeze döndür
  final x1 = x * cos(va) - y * sin(va), y1 = x * sin(va) + y * cos(va);
  final y2 = y1 * cos(vh) + z * sin(vh), z2 = -y1 * sin(vh) + z * cos(vh);
  if (y2 <= -0.2) return null;
  final k = 2 / (1 + y2 + 1e-9); // stereografik
  final scale = size.shortestSide / (2 * tan(fov * pi / 360)) * .5;
  return Offset(size.width / 2 + x1 * k * scale, size.height / 2 - z2 * k * scale);
}

class _DomePainter extends CustomPainter {
  final double lat, lon, az, pitch, fov, cloud; final DateTime t; final (double, double)? iss; final List<(double, double, String)> sats; final bool planetsOn;
  _DomePainter({required this.lat, required this.lon, required this.t, required this.az, required this.pitch, required this.fov, required this.cloud, this.iss, required this.sats, required this.planetsOn});

  @override
  void paint(Canvas c, Size size) {
    final sunAlt = sunAltitude(lat, lon, t);
    final day = sunAlt > 0;
    final bgTop = day ? const Color(0xFF87C4FF) : sunAlt > -12 ? const Color(0xFF2A3F7A) : const Color(0xFF0B1330);
    c.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, day ? const Color(0xFFDFF1FF) : const Color(0xFF16224A)]).createShader(Offset.zero & size));
    Offset? P(double ra, double dec) { final a = raDecToAltAz(ra, dec, lat, lon, t); if (a.alt < -2) return null; return _project(a.az, a.alt, size, az, pitch, fov); }
    final starVis = day ? 0.0 : (sunAlt > -12 ? .5 : 1.0);
    // Samanyolu: galaktik düzlem (b=0) noktaları
    if (starVis > 0) {
      // Samanyolu: galaktik düzlem boyunca yumuşak, bulanık bir ışık bandı
      final band = Path(); var open = false;
      for (var l = 0; l <= 360; l += 3) {
        final eq = _galToEq(l.toDouble(), 0); final o = P(eq.$1, eq.$2);
        if (o == null) { open = false; continue; }
        if (!open) { band.moveTo(o.dx, o.dy); open = true; } else { band.lineTo(o.dx, o.dy); }
      }
      c.drawPath(band, Paint()..color = Colors.white.withValues(alpha: .10 * starVis)..style = PaintingStyle.stroke..strokeWidth = 46..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      c.drawPath(band, Paint()..color = Colors.white.withValues(alpha: .08 * starVis)..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    // Takımyıldız çizgileri
    final byName = {for (final s in brightStars) s.name: s};
    final linePaint = Paint()..color = const Color(0xFF7DB2FF).withValues(alpha: .35 * starVis)..strokeWidth = 1;
    if (starVis > 0) {
      for (final k in constellations) {
        for (final l in k.lines) { if (l.length < 2) continue; final a = byName[l[0]], b = byName[l[1]]; if (a == null || b == null) continue; final pa = P(a.raDeg, a.decDeg), pb = P(b.raDeg, b.decDeg); if (pa != null && pb != null) c.drawLine(pa, pb, linePaint); }
      }
      for (final s in brightStars) { final o = P(s.raDeg, s.decDeg); if (o != null) c.drawCircle(o, max(1.0, 3.6 - s.mag * .8), Paint()..color = Colors.white.withValues(alpha: starVis)); }
    }
    // Güneş, Ay, gezegenler
    final sun = sunRaDec(t); final so = P(sun.raDeg, sun.decDeg); if (so != null) paintSun(c, so, 13, alt: sunAltitude(lat, lon, t), cover: cloud);
    final mn = moonRaDec(t); final mo = P(mn.raDeg, mn.decDeg);
    if (mo != null) {
      final ph = moonPhaseInfo(t);
      if (!MoonRenderer.paint(c, mo, 13, MoonView.at(lat, lon, t), alpha: day ? .85 : 1)) {
        c.drawCircle(mo, 24, Paint()..shader = RadialGradient(colors: [const Color(0xFFF4ECCF).withValues(alpha: day ? 0 : .25), const Color(0x00F4ECCF)]).createShader(Rect.fromCircle(center: mo, radius: 24)));
        c.drawCircle(mo, 12, Paint()..color = (day ? Colors.white : const Color(0xFF2B3866)).withValues(alpha: day ? .25 : .9));
        c.drawPath(moonLitPath(mo, 12, ph.ageDays / 29.530588853, south: lat < 0), Paint()..color = const Color(0xFFF4ECCF));
      }
    }
    if (planetsOn) {
      for (final name in const ['Merkür', 'Venüs', 'Mars', 'Jüpiter', 'Satürn']) {
        try { final r = planetRaDec(name, t); final o = P(r.raDeg, r.decDeg); if (o != null) { c.drawCircle(o, 4.5, Paint()..color = const Color(0xFFFFB74D)); _label(c, name, o + const Offset(6, -4), const Color(0xFFFFE0B2)); } } catch (_) {}
      }
    }
    // Uydular
    for (final s in sats) { final o = _project(s.$1, s.$2, size, az, pitch, fov); if (o != null) { c.drawCircle(o, s.$3.isEmpty ? 1.6 : 3.5, Paint()..color = s.$3.isEmpty ? const Color(0xFFB3E5FC) : const Color(0xFF7DF9FF)); if (s.$3.isNotEmpty) _label(c, s.$3, o + const Offset(6, -4), const Color(0xFF7DF9FF)); } }
    // Nişangah
    if (iss != null) {
      final o = _project(iss!.$1, iss!.$2, size, az, pitch, fov);
      final ring = Paint()..color = const Color(0xFF00E5FF)..style = PaintingStyle.stroke..strokeWidth = 2;
      if (o != null) { c.drawCircle(o, 22, ring); c.drawLine(o + const Offset(-32, 0), o + const Offset(-14, 0), ring); c.drawLine(o + const Offset(14, 0), o + const Offset(32, 0), ring); c.drawLine(o + const Offset(0, -32), o + const Offset(0, -14), ring); c.drawLine(o + const Offset(0, 14), o + const Offset(0, 32), ring); }
      else { // ekran dışı: pusula oku
        var d = ((iss!.$1 - az + 540) % 360) - 180; final left = d < 0;
        final y = size.height / 2; final x = left ? 24.0 : size.width - 24;
        final path = Path()..moveTo(x, y)..lineTo(x + (left ? 16 : -16), y - 12)..lineTo(x + (left ? 16 : -16), y + 12)..close();
        c.drawPath(path, Paint()..color = const Color(0xFF00E5FF));
      }
    }
    // Ufuk çizgisi + yön harfleri
    final horizon = Path(); var first = true;
    for (var a = 0; a <= 360; a += 5) { final o = _project(a.toDouble(), 0, size, az, pitch, fov); if (o == null) { first = true; continue; } if (first) { horizon.moveTo(o.dx, o.dy); first = false; } else { horizon.lineTo(o.dx, o.dy); } }
    c.drawPath(horizon, Paint()..color = Colors.white.withValues(alpha: .7)..style = PaintingStyle.stroke..strokeWidth = 2);
    for (final e in const [('K', 0.0), ('D', 90.0), ('G', 180.0), ('B', 270.0)]) { final o = _project(e.$2, 0, size, az, pitch, fov); if (o != null) _label(c, e.$1, o + const Offset(-4, 4), Colors.white, bold: true); }
    // Bulut örtüsü (X-Ray kapalıyken)
    if (cloud > .05) {
      final hi = day ? Colors.white : const Color(0xFF5A6684), lo = day ? const Color(0xFFCFD8E3) : const Color(0xFF2E3852);
      c.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [hi.withValues(alpha: .2 + .65 * cloud), lo.withValues(alpha: .2 + .7 * cloud)]).createShader(Offset.zero & size));
      final r = Random(5);
      for (var i = 0; i < 16; i++) {
        final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height); final rad = 50 + r.nextDouble() * 70;
        c.drawCircle(o, rad, Paint()..shader = RadialGradient(colors: [hi.withValues(alpha: .55 * cloud), hi.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: rad)));
      }
    }
  }

  void _label(Canvas c, String s, Offset o, Color col, {bool bold = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: col, fontWeight: bold ? FontWeight.w900 : FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o);
  }

  /// Galaktik (l,b) → ekvatoral (RA,Dec) [J2000]
  (double, double) _galToEq(double lDeg, double bDeg) {
    const ngpRa = 192.85948 * pi / 180, ngpDec = 27.12825 * pi / 180, lNcp = 122.93192 * pi / 180;
    final l = lDeg * pi / 180, b = bDeg * pi / 180;
    final sinDec = sin(b) * sin(ngpDec) + cos(b) * cos(ngpDec) * cos(lNcp - l);
    final dec = asin(sinDec);
    final y = cos(b) * sin(lNcp - l), x = sin(b) * cos(ngpDec) - cos(b) * sin(ngpDec) * cos(lNcp - l);
    var ra = ngpRa + atan2(y, x); ra = (ra * 180 / pi) % 360; if (ra < 0) ra += 360;
    return (ra, dec * 180 / pi);
  }

  @override
  bool shouldRepaint(covariant _DomePainter o) => true;
}


class _RoundDark extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const _RoundDark(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(message: tip, child: Material(
        color: const Color(0xFF0B1330).withValues(alpha: .55), shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 40, height: 40, child: Icon(icon, color: Colors.white, size: 22))),
      ));
}

class _SwitchRow extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub; final bool value; final ValueChanged<bool> onChanged;
  const _SwitchRow(this.icon, this.color, this.title, this.sub, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          IconBadge(icon, color: color, size: 34), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(sub, style: T.small.copyWith(fontSize: 12)),
          ])),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

/// Yıldız netliği: koyu bento, halka gösterge.
class _ClarityBlock extends StatelessWidget {
  final double clarity; final bool cloudy;
  const _ClarityBlock({required this.clarity, required this.cloudy});
  @override
  Widget build(BuildContext context) => Bento(
        color: kBentoNight,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('Yıldız netliği', dot: Color(0xFFB7C2F2), labelColor: Color(0xFF9DA9CF)),
          const Spacer(),
          SizedBox(width: 92, height: 92, child: CustomPaint(painter: _ClarityRing(clarity / 100), child: Center(child: Text('%${clarity.round()}',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF4ECCF)))))),
          const Spacer(),
          Text(cloudy ? 'Gökyüzü kapalı' : clarity >= 70 ? 'Yıldız avı için harika' : clarity >= 40 ? 'Parlak yıldızlar görünür' : 'Puslu, az yıldız',
              maxLines: 2, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF4ECCF))),
        ]),
      );
}

class _ClarityRing extends CustomPainter {
  final double v;
  _ClarityRing(this.v);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(5, 5, s.width - 10, s.height - 10);
    c.drawArc(r, 0, 2 * pi, false, Paint()..color = const Color(0xFFB7C2F2).withValues(alpha: .16)..style = PaintingStyle.stroke..strokeWidth = 8);
    if (v > 0) c.drawArc(r, -pi / 2, 2 * pi * v.clamp(0.0, 1.0), false, Paint()..color = const Color(0xFFB7C2F2)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _ClarityRing o) => o.v != v;
}

class _DarkPill extends StatelessWidget {
  final IconData icon; final String text;
  const _DarkPill(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF0B1330).withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}
