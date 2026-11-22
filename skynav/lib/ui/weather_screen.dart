import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/phrases.dart';
import '../engine/formulas.dart';
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
      PrecipKind.none => s.cloudCover > 60 ? Kanki.bulutlu : Kanki.acik,
    };
    return Kanki.pick(l, seed);
  }

  @override
  Widget build(BuildContext context) {
    final w = WeatherController.I;
    final s = w.confirmed, a = w.analysis;
    if (s == null || a == null) {
      return Center(child: Glass(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('☁️', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 6),
        Text(w.offline ? Kanki.offlineNotu : 'Gökyüzüne bakıyorum kanki…', textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => _pickPlace(context), child: const Text('Elle konum seç')),
      ])));
    }
    final summary = _summary(s, a);
    return RefreshIndicator(
      onRefresh: () => w.refresh(force: true),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        // Başlık kartı
        Padding(padding: const EdgeInsets.only(bottom: 14), child: Glass(onTap: () => _speak(summary), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('📍 ${s.place.name.isEmpty ? 'Konumum' : s.place.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => _pickPlace(context), child: const Text('Konum')),
          ]),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${s.temp.round()}°', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(width: 12),
            Expanded(child: Text('${WeatherScreen.kindName(a.kind)} · hissedilen ${s.feelsLike.round()}°', style: const TextStyle(color: kInkSoft))),
          ]),
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('🔊 Dokununca sesli okurum', style: TextStyle(fontSize: 12, color: kInkSoft)),
          if (s.fromCache || w.offline) Padding(padding: const EdgeInsets.only(top: 6), child: Text(Kanki.offlineNotu, style: const TextStyle(fontSize: 12, color: Color(0xFFB26A00)))),
        ]))),

        // Yağış türü olasılıkları (ücretsiz temel)
        Section('Ne yağıyor, ne yağacak?', Column(children: [
          Bar('Kar', a.snowProb, color: const Color(0xFF4FA3E8)),
          Bar('Karla karışık', a.sleetProb, color: const Color(0xFF7E8CE0)),
          Bar('Mercimek karı', a.lentilProb, color: const Color(0xFF8A9BB0)),
          Bar('Tipi', a.blizzardProb, color: const Color(0xFF3C5A8A)),
          if (a.blizzardProb > 40) Padding(padding: const EdgeInsets.only(top: 6), child: Text(Kanki.pick(Kanki.tipiUyari, s.temp.round()), style: const TextStyle(fontSize: 13))),
          _explain(context, 'Bu ne demek?', 'Kar: sıcaklık ve yaş termometre donma altındayken. Karla karışık: 0-2.5°C bandı. Mercimek karı: kar tanesi yerine küçük boncuklar (kararsız hava, konvektif). Tipi: güçlü rüzgâr karı savurur; bulunduğun yerde yağış olmasa bile dağdaki kar savrulup gelebilir.'),
        ])),

        ProGate(title: 'Dağ Desteği, Sis & Her Yere Yağmayan Kar', child: Section('Çevre Dağlar Radarı', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('+Dağ Desteği: +%${a.mountainBonusPct.round()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kAccent)),
          Text(Kanki.dagDestegi(a.mountainBonusPct), style: const TextStyle(color: kInkSoft)),
          const SizedBox(height: 6),
          for (final m in s.mountains) Text('⛰️ ${m.elevation.round()} m · ${m.distanceKm.round()} km ${windDirName(m.bearingDeg)}${m.snowDepthM != null ? ' · kar ${(m.snowDepthM! * 100).round()} cm' : ''}${m.tempC != null ? ' · ${m.tempC!.round()}°' : ''}', style: const TextStyle(fontSize: 13)),
          const Divider(),
          Bar('Sis ihtimali', a.fogProb, color: const Color(0xFF90A4AE)),
          Bar('Sis yoğunluğu', a.fogDensity, color: const Color(0xFF607D8B)),
          Text(Kanki.sisKademeli(a.fogDensity, s.temp.round()), style: const TextStyle(fontWeight: FontWeight.w600)),
          const Divider(),
          Text('Her yere yağmaz: ${a.unevenSnowText}', style: const TextStyle(fontSize: 13)),
          Text('Yerel gerçeklik: şehir ortalamasından ${a.localityNote.toStringAsFixed(1)}°C sapma (METAR ile).', style: const TextStyle(fontSize: 12, color: kInkSoft)),
        ]))),

        Section('Gece Gökyüzü & Yıldız Netliği', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.cloudCover > 75) Text(Kanki.yildizKapali, style: const TextStyle(fontWeight: FontWeight.w700))
          else ...[Bar('Netlik', a.starClarity, color: const Color(0xFF5C6BC0)), Text(Kanki.yildizAcik(a.starClarity))],
        ])),

        Section('Gözlem Butonları (beni eğit)', Wrap(spacing: 8, runSpacing: 6, children: [
          for (final e in [('🔘 Mercimek karı yağıyor', PrecipKind.lentilSnow), ('❄️ Normal kar başladı', PrecipKind.snow), ('🌨️ Tipi var', PrecipKind.blizzard), ('⛄ Kar tuttu', PrecipKind.snow)])
            ActionChip(label: Text(e.$1), onPressed: () { Sfx.tap(); w.observe(e.$2); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teşekkürler kanki, tahminimi buna göre ayarladım.'))); }),
        ]), trailing: Pill('Karne %${w.accuracy.round()}')),

        Section('Detaylar', Wrap(spacing: 22, runSpacing: 12, children: [
          Stat('Çiy noktası', '${s.dewPoint.toStringAsFixed(1)}°'),
          Stat('Yaş termometre', '${s.wetBulb?.toStringAsFixed(1) ?? '-'}°'),
          Stat('Nem', '%${s.humidity.round()}'),
          Stat('Basınç', '${s.pressure.round()} hPa'),
          Stat('Rüzgâr', '${s.windSpeed.toStringAsFixed(1)} m/s ${windDirName(s.windDir)}'),
          Stat('Donma seviyesi', s.freezingLevelM == null ? '-' : '${s.freezingLevelM!.round()} m'),
          Stat('Rakımın (GPS)', s.place.elevation == null ? '-' : '${s.place.elevation!.round()} m'),
          Stat('CAPE', '${s.cape.round()}'),
          Stat('UV', s.uv.toStringAsFixed(1)),
          Stat('Toz/PM10', '${s.aqPm10.round()}'),
          Stat('Toprak 0/6/18/54 cm', [s.soil0, s.soil6, s.soil18, s.soil54].map((e) => e?.toStringAsFixed(1) ?? '-').join(' / ')),
          Stat('Zemin hafızası (3 gün)', '${s.soil0Past3dAvg?.toStringAsFixed(1) ?? '-'}°'),
          Stat('Ay evresi', moonPhase(DateTime.now()).name),
          if (s.metar != null) Stat('METAR ${s.metar!.icao} (${s.metar!.distanceKm.round()} km)', '${s.metar!.tempC?.round() ?? '-'}° · ${s.metar!.windKt?.round() ?? '-'} kt'),
        ])),

        ProGate(title: 'Ensemble, Model Kıyaslaması & Güven', child: Section('Süper Bilgisayarlar', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.ensembleMembers} senaryo: kar olasılığı %${s.ensembleSnowProb.round()}, yağmur %${s.ensembleRainProb.round()}'),
          const SizedBox(height: 6),
          for (final e in s.modelTemp24h.entries) Text('${e.key.toUpperCase()}: ${e.value.toStringAsFixed(1)}° ort · ${(s.modelPrecip24h[e.key] ?? 0).toStringAsFixed(1)} mm'),
          const SizedBox(height: 6),
          Bar('3-7 gün güven', a.confidence, color: const Color(0xFF43A047)),
        ]))),

        ProGate(title: 'Atmosfer Kesiti 1000–300 hPa', child: Section('Atmosfer Kesiti', SizedBox(height: 170, child: CustomPaint(painter: _ProfilePainter(s), size: Size.infinite)))),

        Section('Rüzgâr Gülü', SizedBox(height: 150, child: Center(child: SizedBox(width: 150, child: CustomPaint(painter: _RosePainter(s.windDir, s.windSpeed)))))),
        const LightningMeter(),
        const RadarMapCard(),
        Section('Araçlar', Wrap(spacing: 8, runSpacing: 8, children: [
          _tool(context, '🎧 Uyku Mikseri', const SleepMixerScreen()),
          _tool(context, '🔦 SOS Feneri', const SosScreen()),
          _tool(context, '💊 Zaman Kapsülü', const TimeCapsuleScreen()),
          _tool(context, '📺 Hava Kanalı', const BroadcastScreen()),
          _tool(context, '🧪 Yaşam Laboratuvarı', const LabScreen()),
        ])),
      ]),
    );
  }

  Widget _tool(BuildContext c, String t, Widget page) => FilledButton.tonal(onPressed: () { Sfx.tap(); Navigator.push(c, MaterialPageRoute(builder: (_) => page)); }, child: Text(t));

  Widget _explain(BuildContext c, String t, String body) => Align(alignment: Alignment.centerLeft, child: TextButton(
      onPressed: () { showModalBottomSheet(context: c, builder: (_) => Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(body), const SizedBox(height: 10),
        FilledButton.tonal(onPressed: () => Voice.speak(body), child: const Text('🔊 Sesli oku'))]))); }, child: Text(t)));

  void _speak(String t) { Sfx.tap(); Voice.speak(t); }

  Future<void> _pickPlace(BuildContext context) async {
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _PlaceSheet());
  }
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet();
  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _q = TextEditingController();
  List<GeoPoint2> _res = [];
  @override
  Widget build(BuildContext context) {
    final saved = LocationService.places();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.my_location), title: const Text('Konumumu kullan (GPS)'), onTap: () { WeatherController.I.useGps(); Navigator.pop(context); }),
        for (final p in saved) ListTile(leading: const Icon(Icons.bookmark), title: Text(p.name), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await LocationService.deletePlace(p.name); setState(() {}); }), onTap: () { WeatherController.I.setPlace(p); Navigator.pop(context); }),
        TextField(controller: _q, decoration: const InputDecoration(hintText: 'Şehir, ilçe, mahalle, köy ara…', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) async { try { final r = await GeocodeService().search(v); setState(() => _res = r); } catch (_) {} }),
        for (final p in _res) ListTile(title: Text(p.name), trailing: IconButton(icon: const Icon(Icons.bookmark_add_outlined), tooltip: 'Kaydet (Evim, Anneannem…)', onPressed: () async { await LocationService.savePlace(p); setState(() {}); }), onTap: () { WeatherController.I.setPlace(p); Navigator.pop(context); }),
      ]),
    );
  }
}

class _RosePainter extends CustomPainter {
  final double dir, speed; _RosePainter(this.dir, this.speed);
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero); final r = s.width / 2 - 8;
    final p = Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.stroke;
    c.drawCircle(ctr, r, p); c.drawCircle(ctr, r * .5, p);
    for (var i = 0; i < 8; i++) { final a = i * pi / 4; c.drawLine(ctr, ctr + Offset(sin(a), -cos(a)) * r, p); }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in [('K', 0.0), ('D', 90.0), ('G', 180.0), ('B', 270.0)]) {
      tp.text = TextSpan(text: e.$1, style: const TextStyle(fontSize: 11, color: kInkSoft, fontWeight: FontWeight.w800)); tp.layout();
      final a = e.$2 * pi / 180; tp.paint(c, ctr + Offset(sin(a), -cos(a)) * (r + 2) - Offset(tp.width / 2, tp.height / 2));
    }
    final to = (dir + 180) * pi / 180; // rüzgârın gittiği yön
    final len = r * (.35 + (speed / 20).clamp(0, 1) * .6);
    final tip = ctr + Offset(sin(to), -cos(to)) * len;
    c.drawLine(ctr, tip, Paint()..color = kAccent..strokeWidth = 4..strokeCap = StrokeCap.round);
    c.drawCircle(tip, 6, Paint()..color = kAccent);
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
    final tMin = temps.reduce(min) - 2, tMax = temps.reduce(max) + 2;
    final path = Path();
    for (var i = 0; i < lv.length; i++) {
      final y = size.height * i / (lv.length - 1);
      final x = size.width * (temps[i] - tMin) / (tMax - tMin);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final zeroX = size.width * (0 - tMin) / (tMax - tMin);
    if (zeroX > 0 && zeroX < size.width) c.drawLine(Offset(zeroX, 0), Offset(zeroX, size.height), Paint()..color = const Color(0xFF4FA3E8)..strokeWidth = 1);
    c.drawPath(path, Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.stroke..strokeWidth = 3);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < lv.length; i++) {
      tp.text = TextSpan(text: '${lv[i]} hPa  ${temps[i].round()}°', style: const TextStyle(fontSize: 10, color: kInkSoft)); tp.layout();
      tp.paint(c, Offset(2, size.height * i / (lv.length - 1) - (i == 0 ? 0 : tp.height / 2)));
    }
  }
  @override
  bool shouldRepaint(covariant _ProfilePainter o) => o.s != s;
}
