import 'package:flutter/material.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import 'paywall.dart';
import 'theme.dart';

/// Pro içerik kapısı: kilitliyse içerik yumuşakça gösterilir, zorlayıcı duvar yok.
class ProGate extends StatelessWidget {
  final Widget child; final String title;
  const ProGate({super.key, required this.child, required this.title});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProService.I,
        builder: (_, __) {
          if (ProService.I.state.isPro) return child;
          return Glass(
            onTap: () { Sfx.tap(); Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall())); },
            child: Row(children: [
              const Text('🔒', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Text('SkyNav Pro özelliği. Dokun, nasıl açılacağına bak (arkadaş davetiyle bedava da olur).', style: TextStyle(color: kInkSoft, fontSize: 13)),
              ])),
              const Pill('PRO'),
            ]),
          );
        },
      );
}

class Section extends StatelessWidget {
  final String title; final Widget child; final Widget? trailing;
  const Section(this.title, this.child, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), if (trailing != null) trailing!]),
          const SizedBox(height: 10), child,
        ])),
      );
}

class Stat extends StatelessWidget {
  final String label, value;
  const Stat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 12, color: kInkSoft)),
      ]);
}

class Bar extends StatelessWidget {
  final String label; final double pct; final Color color;
  const Bar(this.label, this.pct, {super.key, this.color = kAccent});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), minHeight: 9, color: color, backgroundColor: color.withValues(alpha: .13)))),
          SizedBox(width: 44, child: Text('%${pct.round()}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      );
}
