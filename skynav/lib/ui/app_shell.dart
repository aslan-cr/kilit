import 'package:flutter/material.dart';
import '../data/phrases.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart' show LocStatus;
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import '../l10n/l10n.dart';
import 'map3d_screen.dart';
import 'plane_radar_screen.dart';
import 'road_screen.dart';
import 'sky_screen.dart';
import 'settings_screen.dart';
import 'sky_background.dart';
import 'theme.dart';
import 'weather_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;
  final _w = WeatherController.I;

  SkyState _sky() {
    final s = _w.confirmed, a = _w.analysis;
    if (s == null || a == null) return const SkyState(cloud: 30);
    return SkyState(
      kind: a.kind, cloud: s.cloudCover, windMs: s.windSpeed, windDirDeg: s.windDir, isDay: s.isDay, tempC: s.temp,
      intensity: ((s.precip + s.snowfall) / 3).clamp(.25, 1.0), fog: a.fogProb * (a.fogDensity / 100), month: DateTime.now().month,
    );
  }

  static List<(IconData, IconData, String)> get _tabs => [
    (Icons.wb_cloudy_outlined, Icons.wb_cloudy_rounded, L10n.t('nav_weather')),
    (Icons.view_in_ar_outlined, Icons.view_in_ar_rounded, L10n.t('nav_map3d')),
    (Icons.flight_outlined, Icons.flight_rounded, L10n.t('nav_planes')),
    (Icons.navigation_outlined, Icons.navigation_rounded, L10n.t('nav_road')),
    (Icons.nights_stay_outlined, Icons.nights_stay_rounded, L10n.t('nav_sky')),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _w,
        builder: (_, __) => Scaffold(
          extendBody: true,
          body: Stack(children: [
            Positioned.fill(child: SkyBackground(state: _sky())),
            SafeArea(
              bottom: false,
              child: Column(children: [
                _topBar(),
                if (_w.locStatus == LocStatus.denied || _w.locStatus == LocStatus.deniedForever)
                  Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 8), child: _Banner(Icons.location_off_outlined, Kanki.konumIzinYok)),
                Expanded(child: _page()),
              ]),
            ),
          ]),
          bottomNavigationBar: _NavBar(index: _i, tabs: _tabs, onTap: (v) { Sfx.tap(); setState(() => _i = v); }),
        ),
      );

  // Yalnızca seçili sekme kurulur: 3D Harita açılmadan çizilmez, çıkınca boşaltılır.
  Widget _page() {
    switch (_i) {
      case 0: return const WeatherScreen();
      case 1: return const Map3DScreen();
      case 2: return const PlaneRadarScreen();
      case 3: return const RoadScreen();
      default: return const SkyScreen();
    }
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 12, 6),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5AB0FF), Color(0xFF2F6FE0)])),
            child: const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('SkyNav', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.4, color: kInk)),
          const Spacer(),
          _RoundBtn(Voice.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, 'Sesli spiker', () async { await Voice.setMuted(!Voice.muted); setState(() {}); }),
          const SizedBox(width: 8),
          _RoundBtn(Icons.tune_rounded, 'Ayarlar', () { Sfx.tap(); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const _RoundBtn(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(message: tip, child: Glass(radius: 16, padding: const EdgeInsets.all(10), onTap: onTap, child: Icon(icon, size: 20, color: kInk)));
}

class _Banner extends StatelessWidget {
  final IconData icon; final String text;
  const _Banner(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Glass(
        radius: 18, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), tint: const Color(0xFFFFF6E0),
        child: Row(children: [Icon(icon, size: 18, color: kWarn), const SizedBox(width: 10), Expanded(child: Text(text, style: T.small.copyWith(color: kInk)))]),
      );
}

/// Yüzen buzlu cam alt menü.
class _NavBar extends StatelessWidget {
  final int index; final List<(IconData, IconData, String)> tabs; final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.tabs, required this.onTap});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Glass(
            radius: 26, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(child: InkWell(
                  borderRadius: BorderRadius.circular(18), onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: i == index ? kAccent.withValues(alpha: .12) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(i == index ? tabs[i].$2 : tabs[i].$1, size: 23, color: i == index ? kAccent : kInkSoft),
                      const SizedBox(height: 3),
                      Text(tabs[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: i == index ? FontWeight.w700 : FontWeight.w600, color: i == index ? kAccent : kInkSoft)),
                    ]),
                  ),
                )),
            ]),
          ),
        ),
      );
}
