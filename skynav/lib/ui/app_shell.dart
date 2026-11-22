import 'package:flutter/material.dart';
import '../data/phrases.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart' show LocStatus;
import '../services/voice_service.dart';
import '../services/weather_repository.dart';
import '../l10n/l10n.dart';
import 'map3d_screen.dart';
import 'plane_radar_screen.dart';
import 'placeholders.dart';
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

  static List<(String, String)> get _tabs => [
    ('❄️', L10n.t('nav_weather')), ('🗺️', L10n.t('nav_map3d')), ('✈️', L10n.t('nav_planes')), ('🧭', L10n.t('nav_road')), ('🌌', L10n.t('nav_sky')),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _w,
        builder: (_, __) => Scaffold(
          extendBody: true,
          body: Stack(children: [
            Positioned.fill(child: SkyBackground(state: _sky())),
            SafeArea(
              child: Column(children: [
                _topBar(),
                if (_w.offline) _note('📡 ${Kanki.offlineNotu}'),
                if (_w.locStatus == LocStatus.denied || _w.locStatus == LocStatus.deniedForever) _note('📍 ${Kanki.konumIzinYok}'),
                Expanded(child: _page()),
              ]),
            ),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _i, backgroundColor: Colors.white.withValues(alpha: .92),
            onDestinationSelected: (v) { Sfx.tap(); setState(() => _i = v); },
            destinations: [for (final t in _tabs) NavigationDestination(icon: Text(t.$1, style: const TextStyle(fontSize: 22)), label: t.$2)],
          ),
        ),
      );

  // Yalnızca seçili sekme kurulur: 3D Harita açılmadan çizilmez, çıkınca boşaltılır.
  Widget _page() {
    switch (_i) {
      case 0: return const WeatherScreen();
      case 1: return const Map3DScreen();
      case 2: return const PlaneRadarScreen();
      case 3: return const FeaturePlaceholder(emoji: '🧭', title: 'Yol Tarifi', text: 'OSRM navigasyonu, canlı hız, G-kuvveti sensörü ve esprili sesli asistan 2. yarıda geliyor.');
      default: return const FeaturePlaceholder(emoji: '🌌', title: 'Gökyüzü & Astronomi', text: 'Zaman makinesi, uydu nişangahı ve 360° kubbe 2. yarıda geliyor. (Gece yıldız netliği radarı Hava sekmesinde hazır.)');
    }
  }

  Widget _note(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Glass(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), tint: const Color(0xFFFFF8E1), child: Row(children: [Expanded(child: Text(t, style: const TextStyle(fontSize: 13)))])),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(children: [
          const Text('SkyNav', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
            tooltip: 'Sesli spiker', icon: Icon(Voice.muted ? Icons.volume_off : Icons.volume_up),
            onPressed: () async { await Voice.setMuted(!Voice.muted); setState(() {}); },
          ),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () { Sfx.tap(); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
        ]),
      );
}


