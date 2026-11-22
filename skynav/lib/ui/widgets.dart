import 'package:flutter/material.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import 'paywall.dart';
import 'theme.dart';

/// Pro içerik kapısı: kilitliyse sakin bir davet kartı gösterir; zorlayıcı duvar yok.
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
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: const LinearGradient(colors: [Color(0xFF8E6CFF), Color(0xFF4F7BFF)])),
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('SkyNav Pro ile açılır · arkadaş davetiyle 1 hafta bedava', style: T.small),
              ])),
              const Icon(Icons.chevron_right_rounded, color: kInkFaint),
            ]),
          );
        },
      );
}

/// Başlıklı kart.
class Section extends StatelessWidget {
  final String title; final Widget child; final Widget? trailing;
  const Section(this.title, this.child, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: T.h2)), if (trailing != null) trailing!]),
          const SizedBox(height: 12), child,
        ])),
      );
}

class Stat extends StatelessWidget {
  final String label, value;
  const Stat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: T.num.copyWith(fontSize: 18)),
        Text(label, style: T.small.copyWith(fontSize: 12)),
      ]);
}

class Bar extends StatelessWidget {
  final String label; final double pct; final Color color;
  const Bar(this.label, this.pct, {super.key, this.color = kAccent});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 112, child: Text(label, style: T.small.copyWith(color: kInk, fontWeight: FontWeight.w600))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), minHeight: 8, color: color, backgroundColor: color.withValues(alpha: .12)))),
          SizedBox(width: 46, child: Text('%${pct.round()}', textAlign: TextAlign.right, style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: 14))),
        ]),
      );
}
