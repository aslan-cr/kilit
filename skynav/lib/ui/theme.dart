import 'dart:ui';
import 'package:flutter/material.dart';

// ── Renk paleti ───────────────────────────────────────────────────────────
// Buz beyazı zemin, derin lacivert mürekkep, gökyüzü mavisi vurgu.
const kIce = Color(0xFFF5F9FD);
const kInk = Color(0xFF0F2236);
const kInkSoft = Color(0xFF5B7088);
const kInkFaint = Color(0xFF8DA0B5);
const kLine = Color(0xFFE3EBF3);
const kAccent = Color(0xFF2F80ED);
const kSnow = Color(0xFF4BA3E3);
const kLentil = Color(0xFF7C8DA6);
const kBlizzard = Color(0xFF3D5A80);
const kSleet = Color(0xFF7A86D8);
const kSun = Color(0xFFFFB020);
const kHeat = Color(0xFFF2643D);
const kGood = Color(0xFF2E9E6A);
const kWarn = Color(0xFFE59A14);
const kDanger = Color(0xFFE5484D);
const kPro = Color(0xFF7B5CFA);

const _fallback = ['NotoColorEmoji'];

ThemeData buildTheme([Color accent = kAccent]) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light, surface: Colors.white, primary: accent),
    scaffoldBackgroundColor: kIce,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: kInk, displayColor: kInk, fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, foregroundColor: kInk, centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -.3),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: accent, foregroundColor: Colors.white, minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: kInk, minimumSize: const Size(0, 52), side: const BorderSide(color: kLine, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: kInk, fontSize: 13),
    ),
    sliderTheme: const SliderThemeData(trackHeight: 4),
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 20),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: kInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}

// ── Yazı stilleri ─────────────────────────────────────────────────────────
class T {
  static const hero = TextStyle(fontFamily: 'InterDisplay', fontSize: 96, fontWeight: FontWeight.w300, height: 1, letterSpacing: -4, color: kInk, fontFamilyFallback: _fallback);
  static const h1 = TextStyle(fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.6, color: kInk, height: 1.15, fontFamilyFallback: _fallback);
  static const h2 = TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.3, color: kInk, fontFamilyFallback: _fallback);
  static const body = TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500, color: kInk, height: 1.4, fontFamilyFallback: _fallback);
  static const small = TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: kInkSoft, height: 1.35, fontFamilyFallback: _fallback);
  static const label = TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: kInkFaint, letterSpacing: 1.1, fontFamilyFallback: _fallback);
  static const num = TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -.5, fontFeatures: [FontFeature.tabularFigures()], fontFamilyFallback: _fallback);
}

/// Buzlu cam kart: beyaz yarı saydam zemin, bulanıklık, yumuşak gölge, ince parlak kenar.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double radius;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.tint, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? Colors.white).withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1),
          ),
          child: child,
        ),
      ),
    );
    final shadowed = DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: [
        BoxShadow(color: const Color(0xFF1B3A5C).withValues(alpha: 0.06), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 10)),
        BoxShadow(color: const Color(0xFF1B3A5C).withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
      ]),
      child: card,
    );
    if (onTap == null) return shadowed;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: shadowed));
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color = kAccent, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', color: color, fontWeight: FontWeight.w700, fontSize: 12, fontFamilyFallback: _fallback))),
        ]),
      );
}

/// Küçük, aralıklı büyük harfli bölüm başlığı.
/// Türkçe büyük harf (i → İ, ı → I).
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

class SectionLabel extends StatelessWidget {
  final String text; final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
        child: Row(children: [Expanded(child: Text(trUpper(text), style: T.label)), if (trailing != null) trailing!]),
      );
}

/// Yuvarlak zeminli ikon (liste ve kart başlarında).
class IconBadge extends StatelessWidget {
  final IconData icon; final Color color; final double size;
  const IconBadge(this.icon, {super.key, this.color = kAccent, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .32)),
        child: Icon(icon, color: color, size: size * .52),
      );
}
