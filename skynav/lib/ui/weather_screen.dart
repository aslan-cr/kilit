import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/phrases.dart';
import '../engine/formulas.dart';
import '../game/badges.dart';
import '../services/audio_service.dart';
import '../services/geocode_service.dart';
import '../services/location_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import 'lab_screen.dart';
import 'radar_map.dart';
import 'bento.dart';
import 'hero_scene.dart';
import 'theme.dart';
import 'tools_screens.dart';
import 'widgets.dart';
import 'wx_glyph.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  static String kindName(PrecipKind k) => switch (k) {
        PrecipKind.none => 'Yağış yok', PrecipKind.rain => 'Yağmur', PrecipKind.sleet => 'Karla karışık yağmur',
        PrecipKind.snow => 'Kar', PrecipKind.lentilSnow => 'Mercimek karı', PrecipKind.blizzard => 'Tipi',
      };

  String _summary(WeatherSnapshot s, Analysis a) {
    final seed = DateTime.now().hour + s.temp.round();
    final l = switch (a.kind) {
      PrecipKind.snow => Kanki.normalKar, PrecipKind.lentilSnow => Kanki.mercimekKari, PrecipKind.blizzard => Kanki.tipi,
      PrecipKind.sleet => Kanki.karlaKarisikYagmur, PrecipKind.rain => Kanki.yagmur,
      PrecipKind.none => s.temp >= 35 ? Kanki.asiriSicak
          : s.temp >= 28 ? Kanki.yazSicak
          : s.temp <= -3 ? Kanki.donmaUyari
          : s.cloudCover > 60 ? Kanki.bulutlu
          : s.isDay ? Kanki.acikGunduz : Kanki.acikGece,
    };
    return Kanki.pick(l, seed);
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I;
    final s = w.confirmed, a = w.analysis;
    if (s == null || a == null) return _Loading(offline: w.offline, onPick: () => _pickPlace(context));

    final now = DateTime.now();
    final hours = s.hourly.where((h) => h.time.isAfter(now.subtract(const Duration(minutes: 59)))).take(24).toList();
    final today = DateTime(now.year, now.month, now.day);
    final days = s.daily.where((d) => !DateTime(d.date.year, d.date.month, d.date.day).isBefore(today)).take(7).toList();
    final todayPt = days.isNotEmpty ? days.first : null;
    final summary = _summary(s, a);
    final nowWx = wxFromNow(s, a);

    final sunrise = todayPt?.sunrise, sunset = todayPt?.sunset;
    const gap = SizedBox(height: 14), gapS = SizedBox(height: 12);
    final m = s.metar;

    return RefreshIndicator(
      onRefresh: () => w.refresh(force: true),
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 120), children: [
        // ── Sahne ──
        HeroScene(s: s, a: a, wx: nowWx, today: todayPt, offline: s.fromCache || w.offline, onPlace: () => _pickPlace(context)),
        gap,
        SpeakerCard(text: summary, onPlay: () { Sfx.tap(); Voice.speak(summary); }),
        if (hours.isNotEmpty) ...[gap, HourlyBlock(hours: hours)],
        if (days.isNotEmpty) ...[gap, DailyBlock(days: days)],

        // ── Bento ──
        gap,
        BentoRow(height: 184,
          left: PrecipRingsBlock(a: a, onTap: () => _infoSheet(context, 'Kar, karla karışık, mercimek karı, tipi', _precipHelp)),
          right: WindBlock(s: s, onTap: () => _windSheet(context, s)),
        ),
        if (a.blizzardProb > 40) ...[gapS, _Note(Icons.air, Kanki.pick(Kanki.tipiUyari, s.temp.round()), kBlizzard)],
        if (sunrise != null && sunset != null) ...[gap, DaylightBlock(sunrise: sunrise, sunset: sunset, now: now)],
        gap,
        BentoRow(height: 170, left: HumidityBlock(s: s), right: UvBlock(uv: s.uv)),
        gap,
        BentoRow(height: 200, left: PressureBlock(hpa: s.pressure, trend: PressureBlock.trendOf(s.hourly, now)), right: MoonBlock(now: now, south: s.place.lat < 0, lat: s.place.lat, lon: s.place.lon)),
        gap,
        BentoRow(height: 244, left: SoilBlock(s: s), right: FreezeBlock(freezeM: s.freezingLevelM, elevation: s.place.elevation)),

        // ── Diğer ölçümler ──
        gap,
        BentoRow(height: 120,
          left: MiniBento('Yaş termometre', s.wetBulb == null ? '–' : deg1(s.wetBulb!), (s.wetBulb ?? 1) <= 0 ? 'Kar için uygun' : 'Kar için sıcak', dot: kSnow),
          right: MiniBento('Görüş', s.visibilityM >= 10000 ? '10+ km' : '${(s.visibilityM / 1000).toStringAsFixed(1)} km', s.visibilityM < 1000 ? 'Sis/pus var, dikkat' : 'Açık', dot: kInkSoft),
        ),
        gapS,
        BentoRow(height: 120,
          left: MiniBento('Hava kalitesi', '${s.aqPm10.round()}', 'PM10 µg/m³ · toz ${s.aqDust.round()}', dot: kGood),
          right: MiniBento('Fırtına enerjisi', '${s.cape.round()}', s.cape > 1000 ? 'CAPE yüksek, gök gürleyebilir' : 'CAPE J/kg · sakin', dot: kWarn),
        ),
        gapS,
        BentoRow(height: 120,
          left: MiniBento('Bulut', '%${s.cloudCover.round()}', 'Yüksek bulut %${s.cloudHigh.round()}', dot: kInkSoft),
          right: MiniBento('Kar örtüsü', s.snowDepthM == null ? '–' : '${(s.snowDepthM! * 100).round()} cm', (s.snowDepthM ?? 0) > .02 ? 'Yerde kar var' : 'Yerde kar yok', dot: kSnow),
        ),
        if (m != null) ...[
          gapS,
          Bento(padding: const EdgeInsets.all(14), child: Row(children: [
            const IconBadge(Icons.flight_land_rounded, size: 40), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Havalimanı ölçümü · ${m.icao}', style: T.body.copyWith(fontWeight: FontWeight.w700)),
              Text('${m.distanceKm.round()} km uzakta, canlı METAR doğrulaması', style: T.small.copyWith(fontSize: 12)),
            ])),
            Text(m.tempC == null ? '–' : deg(m.tempC!), style: T.num),
          ])),
        ],

        // ── Gece gökyüzü ──
        gap,
        Bento(color: kBentoNight, child: Row(children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _RingPainter(s.cloudCover > 75 ? 0 : a.starClarity / 100, const Color(0xFFB7C2F2)),
              child: Center(child: Icon(Icons.auto_awesome, color: s.cloudCover > 75 ? const Color(0xFF6B76A0) : const Color(0xFFF4ECCF))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BlockHead('Gece gökyüzü', dot: Color(0xFFF4ECCF), labelColor: Color(0xFF9DA9CF)),
            const SizedBox(height: 6),
            Text(s.cloudCover > 75 ? 'Yıldız görünümü %0' : 'Yıldız netliği %${a.starClarity.round()}', style: T.h2.copyWith(color: const Color(0xFFF4ECCF))),
            const SizedBox(height: 4),
            Text(s.cloudCover > 75 ? 'Gökyüzü kapalı, bugün yıldız yok kanki.' : Kanki.yildizAcik(a.starClarity), style: T.small.copyWith(color: const Color(0xFF9DA9CF))),
          ])),
        ])),

        const SectionLabel('Pro analiz'),
        ProGate(title: 'Çevre dağlar, sis radarı ve yerel gerçeklik', child: _ProAnalysis(s: s, a: a)),
        const SizedBox(height: 12),
        ProGate(title: 'Süper bilgisayarlar & 50+ senaryo', child: _Models(s: s, a: a)),
        const SizedBox(height: 12),
        ProGate(title: 'Atmosfer kesiti (1000–300 hPa)', child: Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Atmosfer kesiti', style: T.h2), const SizedBox(height: 4),
          const Text('Yükseldikçe sıcaklık. Mavi çizgi 0 °C.', style: T.small), const SizedBox(height: 12),
          SizedBox(height: 180, child: CustomPaint(painter: _ProfilePainter(s), size: Size.infinite)),
        ]))),

        SectionLabel('Gözlem — beni eğit', trailing: Pill('Karne %${w.accuracy.round()}', color: kGood, icon: Icons.verified_outlined)),
        Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dışarıda gerçekte ne var? Dokun, tahminlerimi düzelteyim.', style: T.small),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in const [('Mercimek karı', PrecipKind.lentilSnow, Wx.lentil), ('Kar başladı', PrecipKind.snow, Wx.snow), ('Tipi var', PrecipKind.blizzard, Wx.blizzard), ('Kar tuttu', PrecipKind.snow, Wx.snow)])
              ActionChip(avatar: WxGlyph(e.$3, size: 22), label: Text(e.$1), onPressed: () {
                Sfx.tap(); w.observe(e.$2);
                if (e.$2 == PrecipKind.lentilSnow) Badges.award('first_lentil');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teşekkürler kanki, tahminimi buna göre ayarladım.')));
              }),
          ]),
        ])),

        const SectionLabel('Şimşek'),
        const LightningMeter(),

        const SectionLabel('Radar & uydu'),
        const RadarMapCard(),

        const SectionLabel('Araçlar'),
        GridView.count(
          padding: EdgeInsets.zero, crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35,
          children: [
            _ToolTile(Icons.science_outlined, 'Yaşam Laboratuvarı', '30 hesaplayıcı', kGood, const LabScreen()),
            _ToolTile(Icons.bedtime_outlined, 'Uyku Mikseri', 'Gerçek doğa sesleri', const Color(0xFF5B5BD6), const SleepMixerScreen()),
            _ToolTile(Icons.flashlight_on_outlined, 'SOS Feneri', 'Işıkla yardım çağrısı', kDanger, const SosScreen()),
            _ToolTile(Icons.inventory_2_outlined, 'Zaman Kapsülü', 'Bugünü sakla', kWarn, const TimeCapsuleScreen()),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(height: 92, child: _ToolTile(Icons.videocam_outlined, 'Hava Kanalı', 'Kendi yayınını yap', kPro, const BroadcastScreen(), wide: true)),
      ]),
    );
  }

  static const _precipHelp = 'Kar: sıcaklık ve yaş termometre donma altındayken. Karla karışık: 0–2,5 °C bandı. Mercimek karı: kar tanesi yerine küçük beyaz boncuklar; kararsız, konvektif havada olur. Tipi: güçlü rüzgâr karı savurur; bulunduğun yerde yağış olmasa bile dağdaki kar savrulup gelebilir.';

  static Future<void> _infoSheet(BuildContext context, String title, String body) {
    Sfx.tap();
    return showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: T.h2), const SizedBox(height: 10), Text(body, style: T.body), const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => Voice.speak(body), icon: const Icon(Icons.volume_up_rounded), label: const Text('Sesli oku')),
    ])));
  }

  static Future<void> _windSheet(BuildContext context, WeatherSnapshot s) {
    Sfx.tap();
    return showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: Row(children: [
      SizedBox(width: 132, height: 132, child: CustomPaint(painter: _RosePainter(s.windDir, s.windSpeed))),
      const SizedBox(width: 18),
      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s.windSpeed.toStringAsFixed(1)} m/s', style: T.num.copyWith(fontSize: 28)),
        Text('${windDirName(s.windDir)} yönünden · ${(s.windSpeed * 3.6).round()} km/s', style: T.small),
        const SizedBox(height: 10),
        Pill('Hamle ${s.windGust.round()} m/s · ${(s.windGust * 3.6).round()} km/s', color: s.windGust > 17 ? kDanger : kAccent, icon: Icons.air),
      ])),
    ])));
  }

  static Future<void> _pickPlace(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PlaceSheet());
}

// ── Halka göstergeler ──────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double v; final Color color;
  _RingPainter(this.v, this.color);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(4, 4, s.width - 8, s.height - 8);
    c.drawArc(r, 0, 2 * pi, false, Paint()..color = color.withValues(alpha: .13)..style = PaintingStyle.stroke..strokeWidth = 7);
    if (v > 0) c.drawArc(r, -pi / 2, 2 * pi * v.clamp(0.0, 1.0), false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _RingPainter o) => o.v != v || o.color != color;
}

// ── Pro bölümleri ──────────────────────────────────────────────────────────
class _ProAnalysis extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a;
  const _ProAnalysis({required this.s, required this.a});
  @override
  Widget build(BuildContext context) => Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.landscape_rounded, color: kBlizzard),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('+Dağ Desteği: +%${a.mountainBonusPct.round()}', style: T.h2.copyWith(color: kBlizzard)),
            Text(Kanki.dagDestegi(a.mountainBonusPct), style: T.small),
          ])),
        ]),
        const SizedBox(height: 12),
        for (final m in s.mountains) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          const Icon(Icons.filter_hdr_rounded, size: 18, color: kInkSoft), const SizedBox(width: 8),
          Expanded(child: Text('${m.elevation.round()} m · ${m.distanceKm.round()} km ${windDirName(m.bearingDeg)}', style: T.body.copyWith(fontSize: 14))),
          if (m.snowDepthM != null) Pill('${(m.snowDepthM! * 100).round()} cm kar', color: kSnow),
          if (m.tempC != null) Padding(padding: const EdgeInsets.only(left: 6), child: Text('${m.tempC!.round()}°', style: T.body.copyWith(fontWeight: FontWeight.w700))),
        ])),
        const Divider(),
        Row(children: [
          Expanded(child: _MiniStat('Sis ihtimali', '%${a.fogProb.round()}')),
          Expanded(child: _MiniStat('Sis yoğunluğu', '%${a.fogDensity.round()}')),
          Expanded(child: _MiniStat('Yerel sapma', '${a.localityNote >= 0 ? '+' : ''}${a.localityNote.toStringAsFixed(1)}°')),
        ]),
        const SizedBox(height: 10),
        _Note(Icons.cloud_queue, Kanki.sisKademeli(a.fogDensity, s.temp.round()), kInkSoft),
        const SizedBox(height: 8),
        _Note(Icons.scatter_plot_outlined, 'Her yere yağmaz: ${a.unevenSnowText}', kSnow),
      ]));
}

class _Models extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a;
  const _Models({required this.s, required this.a});
  @override
  Widget build(BuildContext context) => Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.memory_rounded, color: kPro),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.ensembleMembers} senaryo', style: T.h2),
            Text('Kar %${s.ensembleSnowProb.round()} · Yağmur %${s.ensembleRainProb.round()}', style: T.small),
          ])),
          Pill('Güven %${a.confidence.round()}', color: kGood),
        ]),
        const SizedBox(height: 12),
        for (final e in s.modelTemp24h.entries) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          SizedBox(width: 64, child: Text(e.key.toUpperCase(), style: T.label.copyWith(color: kInk))),
          Expanded(child: Text('${e.value.toStringAsFixed(1)}° ortalama', style: T.body.copyWith(fontSize: 14))),
          Text('${(s.modelPrecip24h[e.key] ?? 0).toStringAsFixed(1)} mm', style: T.body.copyWith(fontSize: 14, color: kSnow, fontWeight: FontWeight.w700)),
        ])),
      ]));
}

class _MiniStat extends StatelessWidget {
  final String l, v;
  const _MiniStat(this.l, this.v);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: T.num.copyWith(fontSize: 19)), Text(l, style: T.small.copyWith(fontSize: 12)),
      ]);
}

class _Note extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _Note(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color), const SizedBox(width: 10),
          Expanded(child: Text(text, style: T.small.copyWith(color: kInk))),
        ]),
      );
}

class _ToolTile extends StatelessWidget {
  final IconData icon; final String title, sub; final Color color; final Widget page; final bool wide;
  const _ToolTile(this.icon, this.title, this.sub, this.color, this.page, {this.wide = false});
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.all(14), radius: 22,
        onTap: () { Sfx.tap(); Navigator.push(context, MaterialPageRoute(builder: (_) => page)); },
        child: wide
            ? Row(children: [
                IconBadge(icon, color: color, size: 42), const SizedBox(width: 14),
                Expanded(child: _texts()),
                const Icon(Icons.chevron_right_rounded, color: kInkFaint),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconBadge(icon, color: color, size: 42),
                _texts(),
              ]),
      );

  Widget _texts() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(sub, style: T.small.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]);
}

class _Loading extends StatelessWidget {
  final bool offline; final VoidCallback onPick;
  const _Loading({required this.offline, required this.onPick});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const WxGlyph(Wx.partly, size: 120),
        const SizedBox(height: 16),
        Text(offline ? Kanki.offlineNotu : 'Gökyüzüne bakıyorum kanki…', textAlign: TextAlign.center, style: T.h2),
        const SizedBox(height: 8),
        const Text('Konumun alınıp hava verisi doğrulanıyor.', textAlign: TextAlign.center, style: T.small),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.search), label: const Text('Elle konum seç')),
      ])));
}

// ── Konum seçici ───────────────────────────────────────────────────────────
class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet();
  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _q = TextEditingController();
  List<GeoPoint2> _res = [];
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final saved = LocationService.places();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Konum', style: T.h1),
        const SizedBox(height: 14),
        TextField(
          controller: _q, textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Şehir, ilçe, mahalle, köy ara…', prefixIcon: const Icon(Icons.search),
            filled: true, fillColor: kIce, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
          ),
          onSubmitted: (v) async { setState(() => _busy = true); try { final r = await GeocodeService().search(v); setState(() => _res = r); } catch (_) {} setState(() => _busy = false); },
        ),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(Icons.my_location_rounded, size: 38), title: const Text('Konumumu kullan (GPS)', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { WeatherController.I.useGps(); Navigator.pop(context); }),
        for (final p in saved) ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(Icons.bookmark_rounded, color: kWarn, size: 38), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kInkSoft), onPressed: () async { await LocationService.deletePlace(p.name); setState(() {}); }),
            onTap: () { WeatherController.I.setPlace(p); Navigator.pop(context); }),
        for (final p in _res) ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(Icons.place_outlined, color: kInkSoft, size: 38), title: Text(p.name),
            trailing: IconButton(icon: const Icon(Icons.bookmark_add_outlined, color: kAccent), tooltip: 'Kaydet (Evim, Anneannem…)', onPressed: () async { await LocationService.savePlace(p); setState(() {}); }),
            onTap: () { WeatherController.I.setPlace(p); Navigator.pop(context); }),
      ]),
    );
  }
}

// ── Çizimler ───────────────────────────────────────────────────────────────
class _RosePainter extends CustomPainter {
  final double dir, speed; _RosePainter(this.dir, this.speed);
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero); final r = min(s.width, s.height) / 2 - 12;
    c.drawCircle(ctr, r, Paint()..color = kAccent.withValues(alpha: .06));
    c.drawCircle(ctr, r, Paint()..color = kLine..style = PaintingStyle.stroke..strokeWidth = 1.5);
    for (var i = 0; i < 36; i++) {
      final a = i * pi / 18; final len = i % 9 == 0 ? 8.0 : 4.0;
      c.drawLine(ctr + Offset(sin(a), -cos(a)) * r, ctr + Offset(sin(a), -cos(a)) * (r - len), Paint()..color = kInkFaint..strokeWidth = i % 9 == 0 ? 2 : 1);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in [('K', 0.0), ('D', 90.0), ('G', 180.0), ('B', 270.0)]) {
      tp.text = TextSpan(text: e.$1, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: e.$1 == 'K' ? kDanger : kInkSoft, fontWeight: FontWeight.w800)); tp.layout();
      final a = e.$2 * pi / 180; tp.paint(c, ctr + Offset(sin(a), -cos(a)) * (r - 18) - Offset(tp.width / 2, tp.height / 2));
    }
    final to = (dir + 180) * pi / 180; // rüzgârın gittiği yön
    final tip = ctr + Offset(sin(to), -cos(to)) * (r - 6);
    final tail = ctr - Offset(sin(to), -cos(to)) * (r - 26);
    c.drawLine(tail, tip, Paint()..color = kAccent..strokeWidth = 4..strokeCap = StrokeCap.round);
    final head = Path()..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 9 * sin(to) + 6 * cos(to), tip.dy + 9 * cos(to) + 6 * sin(to))
      ..lineTo(tip.dx - 9 * sin(to) - 6 * cos(to), tip.dy + 9 * cos(to) - 6 * sin(to))..close();
    c.drawPath(head, Paint()..color = kAccent);
    c.drawCircle(ctr, 5, Paint()..color = Colors.white); c.drawCircle(ctr, 5, Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _RosePainter o) => o.dir != dir || o.speed != speed;
}

class _ProfilePainter extends CustomPainter {
  final WeatherSnapshot s; _ProfilePainter(this.s);
  @override
  void paint(Canvas c, Size size) {
    final lv = s.pressureLevels.keys.toList()..sort((a, b) => b.compareTo(a));
    if (lv.length < 2) return;
    final temps = lv.map((l) => s.pressureLevels[l]!['temp'] ?? 0).toList();
    final tMin = temps.reduce(min) - 3, tMax = max(temps.reduce(max) + 3, 2.0);
    const left = 58.0;
    final w = size.width - left - 8;
    double x(double t) => left + w * (t - tMin) / (tMax - tMin);
    double y(int i) => size.height - 8 - (size.height - 16) * i / (lv.length - 1);
    final grid = Paint()..color = kLine..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < lv.length; i++) {
      c.drawLine(Offset(left, y(i)), Offset(size.width - 8, y(i)), grid);
      tp.text = TextSpan(text: '${lv[i]} hPa', style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: kInkSoft, fontWeight: FontWeight.w600)); tp.layout();
      tp.paint(c, Offset(0, y(i) - tp.height / 2));
    }
    final zx = x(0);
    if (zx > left && zx < size.width) {
      c.drawLine(Offset(zx, 0), Offset(zx, size.height), Paint()..color = kSnow..strokeWidth = 1.5);
    }
    final path = Path();
    for (var i = 0; i < lv.length; i++) { i == 0 ? path.moveTo(x(temps[i]), y(i)) : path.lineTo(x(temps[i]), y(i)); }
    c.drawPath(path, Paint()..color = kHeat..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < lv.length; i++) {
      final o = Offset(x(temps[i]), y(i));
      c.drawCircle(o, 4.5, Paint()..color = Colors.white); c.drawCircle(o, 4.5, Paint()..color = kHeat..style = PaintingStyle.stroke..strokeWidth = 2.5);
      tp.text = TextSpan(text: '${temps[i].round()}°', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: kInk, fontWeight: FontWeight.w700)); tp.layout();
      tp.paint(c, o + const Offset(8, -16));
    }
  }
  @override
  bool shouldRepaint(covariant _ProfilePainter o) => o.s != s;
}
