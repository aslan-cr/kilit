import 'dart:ui';
import 'package:flutter/material.dart';

const kIce = Color(0xFFF7FAFC);
const kInk = Color(0xFF1A2B3C);
const kInkSoft = Color(0xFF50657A);
const kAccent = Color(0xFF2F9BFF);

ThemeData buildTheme([Color accent = kAccent]) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light, surface: Colors.white),
      scaffoldBackgroundColor: kIce,
      textTheme: ThemeData.light().textTheme.apply(bodyColor: kInk, displayColor: kInk),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: kInk),
    );

/// Buzlu cam kart: beyaz yarı saydam zemin, blur, yumuşak gölge. Okunaklılık için opaklık yüksek tutulur.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? tint;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.tint});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: [BoxShadow(color: const Color(0xFF1A2B3C).withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = kAccent});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}
