import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../game/badges.dart';
import '../services/geocode_service.dart';
import '../services/open_meteo_service.dart';
import '../services/weather_repository.dart';
import 'sky_background.dart';
import 'theme.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _q = TextEditingController();
  String? _result; bool _busy = false;

  /// Arkadaşla şehirler arası kar yarışı: kar kalınlığı + sıcaklık kıyaslanır, kart paylaşılır.
  Future<void> _race() async {
    final me = WeatherController.I.confirmed;
    if (me == null || _q.text.trim().isEmpty) return;
    setState(() { _busy = true; _result = null; });
    try {
      final found = await GeocodeService().search(_q.text.trim());
      if (found.isEmpty) { setState(() { _result = 'Şehri bulamadım kanki.'; _busy = false; }); return; }
      final other = await OpenMeteoService().fetch(found.first);
      final mine = (me.snowDepthM ?? 0) * 100, theirs = (other.snowDepthM ?? 0) * 100;
      final win = mine > theirs ? '🏆 Sen kazandın' : mine < theirs ? '🏆 ${found.first.name} kazandı' : '🤝 Berabere';
      setState(() { _result = '❄️ SkyNav Kar Yarışı\n${me.place.name.isEmpty ? 'Ben' : me.place.name}: ${mine.round()} cm kar, ${me.temp.round()}°\n${found.first.name}: ${theirs.round()} cm kar, ${other.temp.round()}°\n$win'; _busy = false; });
    } catch (_) { setState(() { _result = 'Şu an yarış verisini alamadım.'; _busy = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final e = Badges.earned;
    return Scaffold(
      appBar: AppBar(title: const Text('Rozetler & Kar Yarışı')),
      body: Stack(children: [
        const Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30))),
        ListView(padding: const EdgeInsets.all(16), children: [
          for (final b in Badges.all) Padding(padding: const EdgeInsets.only(bottom: 10), child: Glass(tint: e.contains(b.id) ? const Color(0xFFFFF8DC) : null, child: Row(children: [
            Text(e.contains(b.id) ? b.emoji : '🔒', style: const TextStyle(fontSize: 30)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(b.how, style: const TextStyle(fontSize: 12, color: kInkSoft))])),
          ]))),
          Glass(child: Column(children: [
            const Text('🏁 Arkadaşla kar yarışı', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            TextField(controller: _q, decoration: const InputDecoration(hintText: 'Arkadaşının şehri')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _race, child: const Text('Yarışı başlat')),
            if (_result != null) ...[const SizedBox(height: 8), Text(_result!), TextButton(onPressed: () => Share.share(_result!), child: const Text('Kartı paylaş'))],
          ])),
        ]),
      ]),
    );
  }
}
