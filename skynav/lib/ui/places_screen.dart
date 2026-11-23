import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/open_meteo_service.dart';
import '../services/weather_repository.dart';
import 'bento.dart';
import 'compare_screen.dart';
import 'hero_scene.dart' show deg;
import 'theme.dart';
import 'wx_glyph.dart';

/// Yerlerim: şu anki konum ve kayıtlı yerlerin (Evim, Anneannem…) anlık havası yan yana.
/// Dokununca o yere geçilir. Her yer için hafif bir istek; sonuçlar 15 dk saklanır.
class PlacesScreen extends StatefulWidget {
  /// Test için veri kaynağı; boşsa Open-Meteo.
  final Future<PlaceNow> Function(GeoPoint2 p)? fetch;
  final Future<void> Function()? onAdd;
  const PlacesScreen({super.key, this.fetch, this.onAdd});
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  static final Map<String, (DateTime, PlaceNow)> _cache = {};
  final Map<String, PlaceNow?> _now = {};
  final Set<String> _failed = {};

  static String _key(GeoPoint2 p) => '${p.lat.toStringAsFixed(3)},${p.lon.toStringAsFixed(3)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final get = widget.fetch ?? OpenMeteoService().fetchLite;
    await Future.wait([
      for (final p in LocationService.places()) () async {
        final k = _key(p);
        final c = _cache[k];
        if (c != null && DateTime.now().difference(c.$1) < const Duration(minutes: 15)) { _now[k] = c.$2; return; }
        try {
          final r = await get(p);
          _cache[k] = (DateTime.now(), r);
          _now[k] = r;
        } catch (_) { _failed.add(k); }
        if (mounted) setState(() {});
      }(),
    ]);
    if (mounted) setState(() {});
  }

  void _go(GeoPoint2? p) {
    Sfx.tap();
    if (p == null) { WeatherController.I.useGps(); } else { WeatherController.I.setPlace(p); }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Şu anki konumun özeti (karşılaştırma için 7 gün dahil).
  PlaceNow? _here() {
    final s = WeatherController.I.confirmed;
    if (s == null) return null;
    final t = DateTime.now();
    final days = s.daily.where((d) => !d.date.isBefore(DateTime(t.year, t.month, t.day))).take(7).toList();
    return PlaceNow(place: s.place.name.isEmpty ? GeoPoint2(s.place.lat, s.place.lon, name: 'Konumum') : s.place,
        temp: s.temp, tMax: days.isEmpty ? s.temp : days.first.tMax, tMin: days.isEmpty ? s.temp : days.first.tMin,
        wind: s.windSpeed, precip: s.precip, cloud: s.cloudCover, code: s.weatherCode, isDay: s.isDay, days: days);
  }

  void _compare(PlaceNow b) {
    final a = _here();
    if (a == null) return;
    Sfx.tap();
    Navigator.push(context, MaterialPageRoute(builder: (_) => CompareScreen(a: a, b: b)));
  }

  /// Hangi kayıtlı yerle karşılaştırılacağını sorar.
  void _pickCompare() {
    final ready = [for (final p in LocationService.places()) if (_now[_key(p)] != null) _now[_key(p)]!];
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Neresiyle karşılaştıralım?', style: T.h2),
        const SizedBox(height: 8),
        if (ready.isEmpty) const Text('Kayıtlı yerlerin havası henüz gelmedi.', style: T.small),
        for (final p in ready) ListTile(contentPadding: EdgeInsets.zero, leading: WxGlyph(wxFromCode(p.code), day: p.isDay, size: 34),
            title: Text(p.place.name, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text(deg(p.temp), style: T.num.copyWith(fontSize: 18)),
            onTap: () { Navigator.pop(ctx); _compare(p); }),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final saved = LocationService.places();
    final here = _here();
    final cards = <Widget>[
      if (here != null) _PlaceCard(name: here.place.name, here: true, now: here, onTap: () => Navigator.pop(context)),
      for (final p in saved) _PlaceCard(name: p.name, now: _now[_key(p)], failed: _failed.contains(_key(p)), onTap: () => _go(p),
          onLongPress: _now[_key(p)] == null ? null : () => _compare(_now[_key(p)]!)),
      _AddCard(onTap: () async { Sfx.tap(); await widget.onAdd?.call(); await _load(); }),
    ];
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Yerlerim')),
      body: RefreshIndicator(
        onRefresh: () async { _cache.clear(); _failed.clear(); await _load(); },
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
          Text('Kayıtlı yerlerinin havası tek bakışta. Dokun: o yere geç · uzun bas: karşılaştır.', style: T.small),
          const SizedBox(height: 12),
          GridView.count(
            padding: EdgeInsets.zero, crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .76,
            children: cards,
          ),
          const SizedBox(height: 14),
          if (saved.isNotEmpty && here != null) ...[
            Bento(onTap: _pickCompare, color: kBentoBlue, padding: const EdgeInsets.all(14), child: Row(children: [
              const Icon(Icons.compare_arrows_rounded, color: kAccent), const SizedBox(width: 12),
              Expanded(child: Text('İki yeri karşılaştır (7 gün yan yana)', style: T.body.copyWith(fontWeight: FontWeight.w700))),
              const Icon(Icons.chevron_right_rounded, color: kInkFaint),
            ])),
            const SizedBox(height: 12),
          ],
          Bento(padding: const EdgeInsets.all(14), child: Row(children: [
            const Icon(Icons.my_location_rounded, color: kAccent), const SizedBox(width: 12),
            Expanded(child: Text('Konumumu kullan (GPS)', style: T.body.copyWith(fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => _go(null), child: const Text('Geç')),
          ])),
        ]),
      ),
    );
  }
}

/// Havaya göre kart göğü: açık gündüz mavi, bulutlu gri, yağışlı kurşuni, karlı buz, gece lacivert.
List<Color> _skyFor(Wx wx, bool day) {
  if (!day) return wx == Wx.clear || wx == Wx.partly ? const [Color(0xFF0E1838), Color(0xFF2B3B78)] : const [Color(0xFF1C2434), Color(0xFF3E4A60)];
  return switch (wx) {
    Wx.clear => const [Color(0xFF3F8EE6), Color(0xFF8EC2F5)],
    Wx.partly => const [Color(0xFF4F8FD6), Color(0xFFA9CBEB)],
    Wx.snow || Wx.blizzard || Wx.lentil || Wx.sleet => const [Color(0xFF6685AB), Color(0xFFB9CBE0)],
    Wx.rain || Wx.drizzle || Wx.thunder => const [Color(0xFF4E5F75), Color(0xFF8E9DB0)],
    _ => const [Color(0xFF7D90A6), Color(0xFFC3CFDB)],
  };
}

class _PlaceCard extends StatelessWidget {
  final String name; final PlaceNow? now; final bool here, failed; final VoidCallback onTap; final VoidCallback? onLongPress;
  const _PlaceCard({required this.name, required this.now, this.here = false, this.failed = false, required this.onTap, this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final n = now;
    final wx = n == null ? Wx.cloudy : wxFromCode(n.code);
    final sky = _skyFor(wx, n?.isDay ?? true);
    const white = TextStyle(fontFamily: 'Inter', color: Colors.white);
    return Pressable(child: Material(
      borderRadius: BorderRadius.circular(26), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: Ink(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky),
            boxShadow: const [BoxShadow(color: Color(0x141B3A5C), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 10))]),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (here) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.near_me_rounded, size: 14, color: Colors.white)),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: white.copyWith(fontSize: 15, fontWeight: FontWeight.w800))),
          ]),
          const Spacer(),
          if (n == null)
            Center(child: failed
                ? Text('Bağlantı yok', style: white.copyWith(fontSize: 13, fontWeight: FontWeight.w600))
                : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)))
          else ...[
            WxGlyph(wx, day: n.isDay, size: 44),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(deg(n.temp), style: white.copyWith(fontFamily: 'InterDisplay', fontSize: 44, fontWeight: FontWeight.w300, height: 1, letterSpacing: -1.5))),
          ],
          const Spacer(),
          if (n != null) ...[
            Text(wxLabel(wx, day: n.isDay), maxLines: 1, overflow: TextOverflow.ellipsis, style: white.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
            Text('↑ ${deg(n.tMax)}   ↓ ${deg(n.tMin)}', style: white.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .85))),
          ],
        ])),
      )),
    ));
  }
}

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});
  @override
  Widget build(BuildContext context) => Bento(
        onTap: onTap, color: kBentoBlue,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: kAccent, size: 28)),
          const SizedBox(height: 10),
          Text('Yer ekle', style: T.body.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Evim, Anneannem…', style: T.small.copyWith(fontSize: 12)),
        ]),
      );
}
