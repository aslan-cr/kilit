import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/audio_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import 'sky_background.dart';
import 'theme.dart';

class LabScreen extends StatelessWidget {
  const LabScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lab = WeatherController.I.lab;
    return Scaffold(
      appBar: AppBar(title: const Text('Yaşam & Doğa Laboratuvarı')),
      body: Stack(children: [
        const Positioned.fill(child: SkyBackground(state: SkyState(cloud: 30))),
        lab.isEmpty
            ? const Center(child: Text('Önce hava verisi gelsin kanki.'))
            : GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .95),
                itemCount: lab.length,
                itemBuilder: (_, i) => _tile(context, lab[i]),
              ),
      ]),
    );
  }

  Widget _tile(BuildContext c, LabResult r) => Glass(
        padding: const EdgeInsets.all(12),
        onTap: () { Sfx.tap(); _open(c, r); },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(r.valueText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kAccent)),
          Expanded(child: Text(r.kanki, style: const TextStyle(fontSize: 12, color: kInkSoft), overflow: TextOverflow.fade)),
          if (r.entertainment) const Pill('eğlence', color: Color(0xFF8E24AA)),
        ]),
      );

  void _open(BuildContext c, LabResult r) {
    Voice.speak('${r.title}. ${r.kanki}');
    showModalBottomSheet(context: c, isScrollControlled: true, builder: (_) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.emoji} ${r.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(r.kanki, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Bu ne demek?', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(r.explain),
            if (r.entertainment) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Eğlence amaçlıdır; bilimsel/tıbbi tahmin değildir.', style: TextStyle(fontSize: 12, color: kInkSoft))),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: () => Voice.speak(r.explain), child: const Text('🔊 Sesli oku')),
          ]),
        ));
  }
}
