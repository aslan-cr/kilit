import 'package:flutter/material.dart';
import '../data/models.dart';
import '../services/audio_service.dart';
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import 'app_icons.dart';
import 'bento.dart';
import 'theme.dart';

/// Yaşam Laboratuvarı: havaya göre günlük hayat hesaplayıcıları (bento kartları).
class LabScreen extends StatelessWidget {
  const LabScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lab = WeatherController.I.lab;
    return Scaffold(
      backgroundColor: kIce,
      appBar: AppBar(title: const Text('Yaşam Laboratuvarı')),
      body: lab.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Önce hava verisi gelsin kanki.', style: T.h2, textAlign: TextAlign.center)))
          : CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                sliver: SliverToBoxAdapter(child: Text('${lab.length} hesaplayıcı, şu anki havana göre. Dokun, anlatsın.', style: T.small)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .82),
                  delegate: SliverChildBuilderDelegate((_, i) => _tile(context, lab[i]), childCount: lab.length),
                ),
              ),
            ]),
    );
  }

  Widget _tile(BuildContext c, LabResult r) {
    final (icon, color) = labIcon(r.id);
    return Bento(
      padding: const EdgeInsets.all(14),
      onTap: () { Sfx.tap(); _open(c, r); },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(icon, color: color, size: 38),
          const Spacer(),
          if (r.entertainment) const Pill('eğlence', color: kPro),
        ]),
        const SizedBox(height: 10),
        Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.25)),
        const SizedBox(height: 4),
        Text(r.valueText, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.num.copyWith(fontSize: 20, color: color)),
        const SizedBox(height: 4),
        Expanded(child: Text(r.kanki, maxLines: 4, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 12.5))),
        if (r.score != null) ...[
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (r.score! / 100).clamp(0, 1), minHeight: 5, color: color, backgroundColor: color.withValues(alpha: .12))),
        ],
      ]),
    );
  }

  void _open(BuildContext c, LabResult r) {
    final (icon, color) = labIcon(r.id);
    Voice.speak('${r.title}. ${r.kanki}');
    showModalBottomSheet(context: c, isScrollControlled: true, builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(icon, color: color, size: 46), const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: T.h2),
                Text(r.valueText, style: T.num.copyWith(fontSize: 18, color: color)),
              ])),
            ]),
            const SizedBox(height: 14),
            Text(r.kanki, style: T.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            const BlockHead('Bu ne demek?'),
            const SizedBox(height: 6),
            Text(r.explain, style: T.body),
            if (r.entertainment) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Eğlence amaçlıdır; bilimsel/tıbbi tahmin değildir.', style: T.small.copyWith(fontSize: 12))),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => Voice.speak(r.explain), icon: const Icon(Icons.volume_up_rounded), label: const Text('Sesli oku')),
          ]),
        ));
  }
}
