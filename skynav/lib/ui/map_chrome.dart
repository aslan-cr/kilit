import 'package:flutter/material.dart';
import 'theme.dart';

// Harita ekranlarının (3D Harita, Uçak Radarı) ortak yüzen parçaları: aynı buzlu cam, aynı bento dili.

/// Üst başlık kartı: ikon rozeti, başlık, alt bilgi ve sağda ek parça.
class MapHeader extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub; final Widget? trailing;
  const MapHeader({super.key, required this.icon, required this.title, required this.sub, this.color = kAccent, this.trailing});
  @override
  Widget build(BuildContext context) => Glass(
        radius: 22, padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(children: [
          IconBadge(icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: 12)),
          ])),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Uyarı/bilgi şeridi.
class MapNote extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const MapNote(this.icon, this.text, {super.key, this.color = kWarn});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Glass(radius: 18, tint: const Color(0xFFFFF6E0), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: T.small.copyWith(color: kInk, fontSize: 12.5)))])),
      );
}

/// Açık/kapalı katman düğmesi (ör. hava katmanı).
class LayerToggle extends StatelessWidget {
  final IconData icon; final String label; final bool on; final VoidCallback onTap;
  const LayerToggle({super.key, required this.icon, required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true, toggled: on, label: label,
        child: Glass(radius: 22, padding: const EdgeInsets.fromLTRB(12, 10, 14, 10), onTap: onTap, child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(duration: const Duration(milliseconds: 200), width: 28, height: 28,
              decoration: BoxDecoration(color: on ? kAccent : kLine, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: on ? Colors.white : kInkSoft)),
          const SizedBox(width: 8),
          Text(label, style: T.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: on ? kInk : kInkSoft)),
        ])),
      );
}

/// Yuvarlak cam düğme.
class MapRoundButton extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const MapRoundButton(this.icon, this.tip, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Tooltip(message: tip, child: Glass(radius: 16, padding: const EdgeInsets.all(10), onTap: onTap, child: Icon(icon, size: 20, color: kInk)));
}

/// Kaynak notu (küçük cam hap).
class MapCredit extends StatelessWidget {
  final String text;
  const MapCredit(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .78), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w600, color: kInkSoft, height: 1.3)),
      );
}

/// Küçük ölçüm sütunu (değer + etiket).
class MapStat extends StatelessWidget {
  final String label, value;
  const MapStat(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trUpper(label), style: T.label.copyWith(fontSize: 10, letterSpacing: .9)),
        const SizedBox(height: 2),
        Text(value, style: T.num.copyWith(fontSize: 18)),
      ]);
}
