import 'package:flutter/material.dart' hide Badge;
import 'package:share_plus/share_plus.dart';
import '../game/badges.dart';
import '../services/geocode_service.dart';
import '../services/open_meteo_service.dart';
import '../services/weather_repository.dart';
import 'app_icons.dart';
import 'bento.dart';
import 'theme.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _q = TextEditingController();
  String? _result; bool _busy = false;
  (String, double, String, double, String)? _race0; // ben, kar, o, kar, sonuç

  /// Arkadaşla şehirler arası kar yarışı: kar kalınlığı + sıcaklık kıyaslanır, kart paylaşılır.
  Future<void> _race() async {
    final me = WeatherController.I.confirmed;
    if (me == null || _q.text.trim().isEmpty) return;
    setState(() { _busy = true; _result = null; _race0 = null; });
    try {
      final found = await GeocodeService().search(_q.text.trim());
      if (found.isEmpty) { setState(() { _result = 'Şehri bulamadım kanki.'; _busy = false; }); return; }
      final other = await OpenMeteoService().fetch(found.first);
      final mine = (me.snowDepthM ?? 0) * 100, theirs = (other.snowDepthM ?? 0) * 100;
      final myName = me.place.name.isEmpty ? 'Ben' : me.place.name;
      final win = mine > theirs ? 'Sen kazandın' : mine < theirs ? '${found.first.name} kazandı' : 'Berabere';
      setState(() {
        _race0 = (myName, mine, found.first.name, theirs, win);
        _result = 'SkyNav Kar Yarışı\n$myName: ${mine.round()} cm kar, ${me.temp.round()}°\n${found.first.name}: ${theirs.round()} cm kar, ${other.temp.round()}°\n$win';
        _busy = false;
      });
    } catch (_) { setState(() { _result = 'Şu an yarış verisini alamadım.'; _busy = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final e = Badges.earned;
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Rozetler & Kar Yarışı')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        BlockHead('Rozetler', dot: kWarn, trailing: Text('${e.length}/${Badges.all.length}', style: T.small.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .95, padding: EdgeInsets.zero,
          children: [
            for (final b in Badges.all) _badge(b, e.contains(b.id)),
          ],
        ),
        const SizedBox(height: 18),
        Bento(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BlockHead('Arkadaşla kar yarışı', dot: kSnow),
          const SizedBox(height: 8),
          const Text('Arkadaşının şehrini yaz; yerdeki kar kalınlığınızı kıyaslayalım.', style: T.small),
          const SizedBox(height: 12),
          TextField(controller: _q, textInputAction: TextInputAction.search, onSubmitted: (_) => _race(),
              decoration: InputDecoration(hintText: 'Arkadaşının şehri', prefixIcon: const Icon(Icons.location_city_rounded), filled: true, fillColor: kIce,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _race, icon: const Icon(Icons.flag_rounded), label: Text(_busy ? 'Ölçülüyor…' : 'Yarışı başlat'))),
          if (_race0 != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _racer(_race0!.$1, _race0!.$2, _race0!.$2 >= _race0!.$4)),
              const SizedBox(width: 12),
              Expanded(child: _racer(_race0!.$3, _race0!.$4, _race0!.$4 >= _race0!.$2)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.emoji_events_rounded, color: kWarn, size: 20), const SizedBox(width: 6),
              Expanded(child: Text(_race0!.$5, style: T.body.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: () => Share.share(_result!), icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Paylaş')),
            ]),
          ] else if (_result != null) ...[const SizedBox(height: 10), Text(_result!, style: T.small)],
        ])),
      ]),
    );
  }

  Widget _badge(Badge b, bool got) {
    final (icon, color) = badgeIcon(b.id);
    return Bento(
      color: got ? const Color(0xFFFFF6DC) : Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        got ? IconBadge(icon, color: color, size: 44) : const IconBadge(Icons.lock_rounded, color: kInkFaint, size: 44),
        const Spacer(),
        Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.25, color: got ? kInk : kInkSoft)),
        const SizedBox(height: 4),
        Text(b.how, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 11.5)),
      ]),
    );
  }

  Widget _racer(String name, double cm, bool lead) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: lead ? kBentoBlue : kIce, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontWeight: FontWeight.w700, color: kInk)),
          Text('${cm.round()} cm', style: T.num.copyWith(fontSize: 24, color: lead ? kSnow : kInk)),
          const Text('yerde kar', style: T.small),
        ]),
      );
}
