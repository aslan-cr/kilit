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
import 'theme.dart';
import 'tools_screens.dart';
import 'widgets.dart';
import 'wx_glyph.dart';

const _trDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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

    return RefreshIndicator(
      onRefresh: () => w.refresh(force: true),
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
        // ── Kahraman bölüm ──
        _Hero(s: s, a: a, wx: nowWx, today: todayPt, offline: s.fromCache || w.offline, onPlace: () => _pickPlace(context)),
        const SizedBox(height: 14),
        _SpeechCard(text: summary),

        if (hours.isNotEmpty) ...[const SectionLabel('Saatlik'), _HourlyStrip(hours: hours, sunrise: todayPt?.sunrise, sunset: todayPt?.sunset)],
        if (days.isNotEmpty) ...[const SectionLabel('7 Günlük'), _DailyList(days: days)],

        SectionLabel('Ne yağıyor, ne yağacak?', trailing: _InfoLink(title: 'Kar, karla karışık, mercimek karı, tipi',
            body: 'Kar: sıcaklık ve yaş termometre donma altındayken. Karla karışık: 0–2,5 °C bandı. Mercimek karı: kar tanesi yerine küçük beyaz boncuklar; kararsız, konvektif havada olur. Tipi: güçlü rüzgâr karı savurur; bulunduğun yerde yağış olmasa bile dağdaki kar savrulup gelebilir.')),
        Glass(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Ring('Kar', a.snowProb, kSnow), _Ring('Karla k.', a.sleetProb, kSleet), _Ring('Mercimek', a.lentilProb, kLentil), _Ring('Tipi', a.blizzardProb, kBlizzard),
          ]),
          if (a.blizzardProb > 40) ...[const SizedBox(height: 14), _Note(Icons.air, Kanki.pick(Kanki.tipiUyari, s.temp.round()), kBlizzard)],
        ])),

        const SectionLabel('Ayrıntılar'),
        _DetailGrid(s: s),

        const SectionLabel('Gece gökyüzü'),
        Glass(child: Row(children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _RingPainter(s.cloudCover > 75 ? 0 : a.starClarity / 100, const Color(0xFF5B5BD6)), child: Center(child: Icon(Icons.auto_awesome, color: s.cloudCover > 75 ? kInkFaint : const Color(0xFF5B5BD6))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.cloudCover > 75 ? 'Yıldız görünümü %0' : 'Yıldız netliği %${a.starClarity.round()}', style: T.h2),
            const SizedBox(height: 4),
            Text(s.cloudCover > 75 ? 'Gökyüzü kapalı, bugün yıldız yok kanki.' : Kanki.yildizAcik(a.starClarity), style: T.small),
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

        const SectionLabel('Rüzgâr & şimşek'),
        Glass(child: Row(children: [
          SizedBox(width: 132, height: 132, child: CustomPaint(painter: _RosePainter(s.windDir, s.windSpeed))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.windSpeed.toStringAsFixed(1)} m/s', style: T.num.copyWith(fontSize: 28)),
            Text('${windDirName(s.windDir)} yönünden · ${(s.windSpeed * 3.6).round()} km/s', style: T.small),
            const SizedBox(height: 10),
            Pill('Hamle ${s.windGust.round()} m/s', color: s.windGust > 17 ? kDanger : kAccent, icon: Icons.air),
          ])),
        ])),
        const SizedBox(height: 12),
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
            _ToolTile(Icons.videocam_outlined, 'Hava Kanalı', 'Kendi yayınını yap', kPro, const BroadcastScreen()),
          ],
        ),
      ]),
    );
  }

  static Future<void> _pickPlace(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PlaceSheet());
}

// ── Kahraman ────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final WeatherSnapshot s; final Analysis a; final Wx wx; final DayPoint? today; final bool offline; final VoidCallback onPlace;
  const _Hero({required this.s, required this.a, required this.wx, required this.today, required this.offline, required this.onPlace});

  @override
  Widget build(BuildContext context) {
    final name = s.place.name.isEmpty ? 'Konumum' : s.place.name;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(14), onTap: onPlace,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on_rounded, size: 20, color: kAccent), const SizedBox(width: 4),
            Text(name, style: T.h2.copyWith(fontSize: 19)), const Icon(Icons.expand_more_rounded, color: kInkSoft),
            if (s.place.elevation != null) Padding(padding: const EdgeInsets.only(left: 6), child: Pill('${s.place.elevation!.round()} m', color: kInkSoft, icon: Icons.terrain)),
          ])),
        ),
        if (offline) Padding(padding: const EdgeInsets.only(top: 4), child: Pill(Kanki.offlineNotu, color: kWarn, icon: Icons.cloud_off)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.temp.round()}°', style: T.hero),
            const SizedBox(height: 6),
            Text(wxLabel(wx, day: s.isDay), style: T.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text([
              'Hissedilen ${s.feelsLike.round()}°',
              if (today != null) 'En yüksek ${today!.tMax.round()}° · En düşük ${today!.tMin.round()}°',
            ].join('\n'), style: T.small.copyWith(fontSize: 14)),
          ])),
          WxGlyph(wx, day: s.isDay, size: 140),
        ]),
      ]),
    );
  }
}

class _SpeechCard extends StatelessWidget {
  final String text;
  const _SpeechCard({required this.text});
  @override
  Widget build(BuildContext context) => Glass(
        onTap: () { Sfx.tap(); Voice.speak(text); },
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(children: [
          const IconBadge(Icons.record_voice_over_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: T.body.copyWith(fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => Voice.speak(text), icon: const Icon(Icons.play_circle_fill_rounded, color: kAccent, size: 34)),
        ]),
      );
}

// ── Saatlik ─────────────────────────────────────────────────────────────────
class _HourlyStrip extends StatelessWidget {
  final List<HourPoint> hours; final DateTime? sunrise, sunset;
  const _HourlyStrip({required this.hours, this.sunrise, this.sunset});
  bool _day(DateTime t) => sunrise == null || sunset == null ? (t.hour >= 7 && t.hour < 18) : (t.hour >= sunrise!.hour && t.hour < sunset!.hour);
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(height: 124, child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: hours.length, separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final h = hours[i]; final first = i == 0;
            final wet = h.snowfall > 0.05 ? '${h.snowfall.toStringAsFixed(1)} cm' : h.precip > 0.05 ? '${h.precip.toStringAsFixed(1)} mm' : '';
            return Container(
              width: 64,
              decoration: first ? BoxDecoration(color: kAccent.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)) : null,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(first ? 'Şimdi' : h.time.hour.toString().padLeft(2, '0'), style: T.small.copyWith(fontWeight: FontWeight.w700, color: first ? kAccent : kInkSoft)),
                WxGlyph(wxFromCode(h.weatherCode), day: _day(h.time), size: 36),
                Text('${h.temp.round()}°', style: T.body.copyWith(fontWeight: FontWeight.w700)),
                Text(wet.isEmpty ? ' ' : wet, style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: kSnow)),
              ]),
            );
          },
        )),
      );
}

// ── 7 günlük ────────────────────────────────────────────────────────────────
class _DailyList extends StatelessWidget {
  final List<DayPoint> days;
  const _DailyList({required this.days});
  @override
  Widget build(BuildContext context) {
    final lo = days.map((d) => d.tMin).reduce(min), hi = days.map((d) => d.tMax).reduce(max);
    return Glass(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Column(children: [
      for (var i = 0; i < days.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
          SizedBox(width: 52, child: Text(i == 0 ? 'Bugün' : i == 1 ? 'Yarın' : _trDays[days[i].date.weekday - 1], style: T.body.copyWith(fontWeight: FontWeight.w700))),
          WxGlyph(wxFromCode(days[i].weatherCode), size: 34),
          SizedBox(width: 54, child: Text(days[i].snowSum > .1 ? '${days[i].snowSum.toStringAsFixed(0)} cm' : days[i].precipSum > .2 ? '${days[i].precipSum.toStringAsFixed(0)} mm' : '',
              textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: kSnow))),
          SizedBox(width: 34, child: Text('${days[i].tMin.round()}°', textAlign: TextAlign.right, style: T.body.copyWith(color: kInkSoft))),
          const SizedBox(width: 10),
          Expanded(child: _RangeBar(lo: lo, hi: hi, a: days[i].tMin, b: days[i].tMax)),
          const SizedBox(width: 10),
          SizedBox(width: 34, child: Text('${days[i].tMax.round()}°', style: T.body.copyWith(fontWeight: FontWeight.w700))),
        ])),
      ],
    ]));
  }
}

class _RangeBar extends StatelessWidget {
  final double lo, hi, a, b;
  const _RangeBar({required this.lo, required this.hi, required this.a, required this.b});
  Color _c(double t) => t <= -5 ? const Color(0xFF3B7DDD) : t <= 0 ? kSnow : t <= 10 ? const Color(0xFF52C4B0) : t <= 20 ? const Color(0xFFF2C94C) : t <= 28 ? kSun : kHeat;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final span = max(1.0, hi - lo);
        final l = (a - lo) / span * c.maxWidth, r = (b - lo) / span * c.maxWidth;
        return SizedBox(height: 6, child: Stack(children: [
          Container(decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4))),
          Positioned(left: l, width: max(6.0, r - l), top: 0, bottom: 0, child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_c(a), _c(b)]), borderRadius: BorderRadius.circular(4)))),
        ]));
      });
}

// ── Halka göstergeler ──────────────────────────────────────────────────────
class _Ring extends StatelessWidget {
  final String label; final double pct; final Color color;
  const _Ring(this.label, this.pct, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(width: 66, height: 66, child: CustomPaint(painter: _RingPainter(pct / 100, color), child: Center(child: Text('%${pct.round()}', style: T.body.copyWith(fontWeight: FontWeight.w800, fontSize: 15))))),
        const SizedBox(height: 8),
        Text(label, style: T.small.copyWith(fontWeight: FontWeight.w600)),
      ]);
}

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

// ── Ayrıntı kutuları ───────────────────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final WeatherSnapshot s;
  const _DetailGrid({required this.s});
  @override
  Widget build(BuildContext context) {
    final moon = moonPhase(DateTime.now());
    final fl = s.freezingLevelM, el = s.place.elevation;
    final tiles = <Widget>[
      _Tile(Icons.water_drop_outlined, 'Nem', '%${s.humidity.round()}', 'Çiy noktası ${s.dewPoint.toStringAsFixed(1)}°', const Color(0xFF3B8EE8)),
      _Tile(Icons.thermostat_outlined, 'Yaş termometre', '${s.wetBulb?.toStringAsFixed(1) ?? '–'}°', (s.wetBulb ?? 1) <= 0 ? 'Kar için uygun' : 'Kar için sıcak', kSnow),
      _Tile(Icons.speed_outlined, 'Basınç', '${s.pressure.round()}', 'hPa', kInkSoft),
      _Tile(Icons.wb_sunny_outlined, 'UV', s.uv.toStringAsFixed(1), s.uv < 3 ? 'Düşük' : s.uv < 6 ? 'Orta' : s.uv < 8 ? 'Yüksek' : 'Çok yüksek', kSun),
      _Tile(Icons.ac_unit, 'Donma seviyesi', fl == null ? '–' : '${fl.round()} m', el == null || fl == null ? 'Rakım bilinmiyor' : fl < el ? 'Senin altında: kar' : '${(fl - el).round()} m üstünde', kSnow),
      _Tile(Icons.visibility_outlined, 'Görüş', s.visibilityM >= 10000 ? '10+ km' : '${(s.visibilityM / 1000).toStringAsFixed(1)} km', s.visibilityM < 1000 ? 'Sis/pus var' : 'Açık', kInkSoft),
      _Tile(Icons.grain, 'Hava kalitesi', '${s.aqPm10.round()}', 'PM10 · toz ${s.aqDust.round()}', kGood),
      _Tile(Icons.nightlight_outlined, 'Ay', moon.name, '%${(moon.illumination * 100).round()} aydınlık', const Color(0xFF5B5BD6)),
      _Tile(Icons.layers_outlined, 'Toprak', '${s.soil0?.toStringAsFixed(1) ?? '–'}°', '6/18/54 cm: ${[s.soil6, s.soil18, s.soil54].map((e) => e == null ? '–' : e.round().toString()).join(' / ')}°', const Color(0xFF8D6E63)),
      _Tile(Icons.bolt_outlined, 'CAPE', '${s.cape.round()}', s.cape > 1000 ? 'Fırtına enerjisi yüksek' : 'Sakin atmosfer', kWarn),
      _Tile(Icons.cloud_outlined, 'Bulut', '%${s.cloudCover.round()}', 'Yüksek bulut %${s.cloudHigh.round()}', kInkSoft),
      _Tile(Icons.history, 'Zemin hafızası', '${s.soil0Past3dAvg?.toStringAsFixed(1) ?? '–'}°', 'Son 3 gün toprak ort.', const Color(0xFF8D6E63)),
    ];
    final m = s.metar;
    return Column(children: [
      GridView.count(padding: EdgeInsets.zero, crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45, children: tiles),
      if (m != null) ...[
        const SizedBox(height: 12),
        Glass(radius: 22, padding: const EdgeInsets.all(14), child: Row(children: [
          const IconBadge(Icons.flight_land_rounded, size: 40), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Havalimanı ölçümü · ${m.icao}', style: T.body.copyWith(fontWeight: FontWeight.w700)),
            Text('${m.distanceKm.round()} km uzakta, canlı METAR doğrulaması', style: T.small.copyWith(fontSize: 12)),
          ])),
          Text('${m.tempC?.round() ?? '–'}°', style: T.num),
        ])),
      ],
    ]);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon; final String title, value, sub; final Color color;
  const _Tile(this.icon, this.title, this.value, this.sub, this.color);
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.all(14), radius: 22,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Expanded(child: Text(trUpper(title), style: T.label.copyWith(fontSize: 10.5), overflow: TextOverflow.ellipsis))]),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: T.num, maxLines: 1)),
          Text(sub, style: T.small.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      );
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

class _InfoLink extends StatelessWidget {
  final String title, body;
  const _InfoLink({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.h2), const SizedBox(height: 10), Text(body, style: T.body), const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => Voice.speak(body), icon: const Icon(Icons.volume_up_rounded), label: const Text('Sesli oku')),
        ]))),
        child: const Padding(padding: EdgeInsets.all(2), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.help_outline_rounded, size: 15, color: kAccent), SizedBox(width: 4),
          Text('Bu ne demek?', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: kAccent)),
        ])),
      );
}

class _ToolTile extends StatelessWidget {
  final IconData icon; final String title, sub; final Color color; final Widget page;
  const _ToolTile(this.icon, this.title, this.sub, this.color, this.page);
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.all(14), radius: 22,
        onTap: () { Sfx.tap(); Navigator.push(context, MaterialPageRoute(builder: (_) => page)); },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconBadge(icon, color: color, size: 42),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(sub, style: T.small.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ]),
      );
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
