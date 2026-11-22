import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/phrases.dart';
import '../services/audio_service.dart';
import '../services/store.dart';
import '../services/weather_repository.dart';
import 'sky_background.dart';
import 'theme.dart';
import 'widgets.dart';

/// Şimşek Mesafe Ölçer: çakmayı gördüğünde başlat, gök gürültüsünü duyunca durdur (ses ≈ 343 m/sn).
class LightningMeter extends StatefulWidget {
  const LightningMeter({super.key});
  @override
  State<LightningMeter> createState() => _LightningMeterState();
}

class _LightningMeterState extends State<LightningMeter> {
  final _sw = Stopwatch();
  Timer? _t;
  double? _km;
  void _toggle() {
    Sfx.tap();
    if (_sw.isRunning) {
      _sw.stop(); _t?.cancel();
      setState(() => _km = _sw.elapsedMilliseconds / 1000 * 0.343);
    } else { _sw..reset()..start(); _km = null; _t = Timer.periodic(const Duration(milliseconds: 100), (_) => setState(() {})); }
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Section('⚡ Şimşek Mesafe Ölçer', Row(children: [
        Expanded(child: Text(_sw.isRunning ? '${(_sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} sn…' : _km == null ? 'Çakmayı görünce başlat, gürültüyü duyunca durdur.' : 'Yıldırım yaklaşık ${_km!.toStringAsFixed(1)} km uzakta.')),
        FilledButton(onPressed: _toggle, child: Text(_sw.isRunning ? 'Gürledi!' : 'Çaktı!')),
      ]));
}

class SleepMixerScreen extends StatefulWidget {
  const SleepMixerScreen({super.key});
  @override
  State<SleepMixerScreen> createState() => _SleepMixerScreenState();
}

class _SleepMixerScreenState extends State<SleepMixerScreen> {
  final _vol = {for (final k in SleepMixer.tracks.keys) k: 0.0};
  final _missing = <String>{};
  @override
  void dispose() { SleepMixer.stopAll(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Doğa Kayıtlı Uyku Mikseri')),
        body: Stack(children: [
          const Positioned.fill(child: SkyBackground(state: SkyState(cloud: 20, isDay: false))),
          ListView(padding: const EdgeInsets.all(16), children: [
            Glass(child: Column(children: [
              const Text('Gerçek doğa kayıtları (CC0). Sentetik ses yok.', style: TextStyle(color: kInkSoft)),
              for (final k in SleepMixer.tracks.keys) ListTile(
                title: Text(SleepMixer.labels[k]!),
                subtitle: _missing.contains(k)
                    ? const Text('Ses dosyası pakette yok (assets/audio/README.md)', style: TextStyle(color: Color(0xFFC62828), fontSize: 12))
                    : Slider(value: _vol[k]!, onChanged: (v) async {
                        setState(() => _vol[k] = v);
                        final ok = await SleepMixer.setVolume(k, v);
                        if (!ok) setState(() { _missing.add(k); _vol[k] = 0; });
                      }),
              ),
            ])),
          ]),
        ]),
      );
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _on = false; bool _cancel = false; String? _err;
  // ... --- ... (birim 250 ms)
  static const _pat = [1, 1, 1, 3, 3, 3, 3, 1, 1, 1];

  Future<void> _run() async {
    setState(() { _on = true; _cancel = false; _err = null; });
    try {
      await TorchLight.isTorchAvailable();
      while (!_cancel) {
        for (final u in _pat) {
          if (_cancel) break;
          await TorchLight.enableTorch(); await Future.delayed(Duration(milliseconds: 250 * u));
          await TorchLight.disableTorch(); await Future.delayed(const Duration(milliseconds: 250));
        }
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (_) { _err = 'Bu cihazda fener kullanılamıyor.'; }
    try { await TorchLight.disableTorch(); } catch (_) {}
    if (mounted) setState(() => _on = false);
  }
  @override
  void dispose() { _cancel = true; super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Acil Durum SOS Feneri')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Glass(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🆘', style: TextStyle(fontSize: 60)),
          const Text('Fener SOS ritmiyle (… --- …) yanıp söner. Gerçek acil durumda 112\'yi ara.', textAlign: TextAlign.center),
          if (_err != null) Text(_err!, style: const TextStyle(color: Color(0xFFC62828))),
          const SizedBox(height: 14),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _on ? const Color(0xFFC62828) : kAccent), onPressed: () { if (_on) { _cancel = true; } else { _run(); } }, child: Text(_on ? 'Durdur' : 'Başlat')),
        ])))),
      );
}

/// Zaman Kapsülü: bugünün havasını nota bağlayıp sakla, yıllar sonra aç.
class TimeCapsuleScreen extends StatefulWidget {
  const TimeCapsuleScreen({super.key});
  @override
  State<TimeCapsuleScreen> createState() => _TimeCapsuleScreenState();
}

class _TimeCapsuleScreenState extends State<TimeCapsuleScreen> {
  final _note = TextEditingController();
  List<Map<String, dynamic>> get _items => ((Store.prefs.get('capsules', defaultValue: <dynamic>[]) as List).map((e) => (jsonDecode(e as String) as Map).cast<String, dynamic>())).toList().reversed.toList();

  Future<void> _save() async {
    final s = WeatherController.I.confirmed, a = WeatherController.I.analysis;
    if (s == null) return;
    final l = (Store.prefs.get('capsules', defaultValue: <dynamic>[]) as List).cast<String>().toList();
    l.add(jsonEncode({'t': DateTime.now().toIso8601String(), 'place': s.place.name, 'temp': s.temp, 'kind': a?.kind.name, 'wind': s.windSpeed, 'note': _note.text}));
    await Store.put('capsules', l); _note.clear(); setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hava Durumu Zaman Kapsülü')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Glass(child: Column(children: [
            TextField(controller: _note, decoration: const InputDecoration(hintText: 'Bugünü bir cümleyle anlat…')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Kapsüle koy')),
          ])),
          for (final c in _items) Padding(padding: const EdgeInsets.only(top: 10), child: Glass(child: ListTile(
            title: Text('${c['place'] ?? ''} · ${(c['temp'] as num).round()}° · ${c['kind']}'),
            subtitle: Text('${c['t'].toString().substring(0, 16)}\n${c['note']}'),
            trailing: IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share('SkyNav zaman kapsülü: ${c['place']} ${(c['temp'] as num).round()}° — ${c['note']}')),
          ))),
        ]),
      );
}

/// Kendi Hava Kanalını Sun: ön kamera + canlı hava bandı. Kayıt cihazda kalır, paylaşımı sen seçersin.
class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});
  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  CameraController? _c; bool _rec = false; String? _err; XFile? _last;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    final cam = await Permission.camera.request(); final mic = await Permission.microphone.request();
    if (!cam.isGranted) { setState(() => _err = Kanki.kameraIzinYok); return; }
    if (!mic.isGranted) _err = Kanki.mikrofonIzinYok;
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere((e) => e.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      _c = CameraController(front, ResolutionPreset.high, enableAudio: mic.isGranted);
      await _c!.initialize();
    } catch (_) { _err = 'Kamera açılamadı.'; }
    if (mounted) setState(() {});
  }
  @override
  void dispose() { _c?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = WeatherController.I.confirmed, a = WeatherController.I.analysis;
    return Scaffold(
      appBar: AppBar(title: const Text('Hava Kanalı Stüdyosu')),
      body: _c == null || !_c!.value.isInitialized
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err ?? 'Kamera hazırlanıyor…', textAlign: TextAlign.center)))
          : Stack(children: [
              Positioned.fill(child: CameraPreview(_c!)),
              Positioned(left: 12, right: 12, bottom: 90, child: Glass(child: Text(s == null ? 'SkyNav Hava Kanalı' : '📺 ${s.place.name}: ${s.temp.round()}° · ${a?.kind.name} · rüzgâr ${s.windSpeed.toStringAsFixed(1)} m/s', style: const TextStyle(fontWeight: FontWeight.w800)))),
              Positioned(left: 0, right: 0, bottom: 20, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FilledButton(style: FilledButton.styleFrom(backgroundColor: _rec ? const Color(0xFFC62828) : kAccent), onPressed: () async {
                  if (_rec) { _last = await _c!.stopVideoRecording(); setState(() => _rec = false); } else { await _c!.startVideoRecording(); setState(() => _rec = true); }
                }, child: Text(_rec ? '⏹ Kaydı bitir' : '⏺ Kayda başla')),
                if (_last != null) Padding(padding: const EdgeInsets.only(left: 8), child: OutlinedButton(onPressed: () => Share.shareXFiles([_last!]), child: const Text('Paylaş'))),
              ])),
            ]),
    );
  }
}
