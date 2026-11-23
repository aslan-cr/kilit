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
import 'app_icons.dart';
import 'bento.dart';
import 'theme.dart';

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
  Widget build(BuildContext context) => Glass(child: Row(children: [
        const IconBadge(Icons.bolt_rounded, color: kWarn, size: 46),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Şimşek mesafe ölçer', style: T.h2),
          const SizedBox(height: 2),
          Text(_sw.isRunning ? '${(_sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} sn… gürlemeyi bekle'
              : _km == null ? 'Çakınca başlat, gürleyince durdur.' : 'Yıldırım yaklaşık ${_km!.toStringAsFixed(1)} km uzakta.', style: T.small),
        ])),
        const SizedBox(width: 10),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(92, 46), backgroundColor: _sw.isRunning ? kDanger : kWarn),
          onPressed: _toggle, child: Text(_sw.isRunning ? 'Gürledi' : 'Çaktı'),
        ),
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
        backgroundColor: kIce,
        appBar: AppBar(title: const Text('Uyku Mikseri')),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
          Bento(color: kBentoNight, padding: const EdgeInsets.all(18), child: Row(children: [
            const IconBadge(Icons.bedtime_rounded, color: Color(0xFFF4ECCF), size: 46), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gerçek doğa kayıtları', style: T.h2.copyWith(color: const Color(0xFFF4ECCF))),
              const SizedBox(height: 2),
              Text('Freesound, CC0. Sentetik ses yok. Sesleri karıştır, uykuna dal.', style: T.small.copyWith(color: const Color(0xFF9DA9CF))),
            ])),
          ])),
          const SizedBox(height: 14),
          for (final k in SleepMixer.tracks.keys) Padding(padding: const EdgeInsets.only(bottom: 12), child: _track(k)),
        ]),
      );

  Widget _track(String k) {
    final (icon, color) = mixerIcon(k);
    final on = _vol[k]! > 0;
    return Bento(
      color: on ? Color.lerp(Colors.white, color, .07)! : Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(children: [
        Row(children: [
          IconBadge(icon, color: color, size: 40), const SizedBox(width: 12),
          Expanded(child: Text(noEmoji(SleepMixer.labels[k]!), style: T.body.copyWith(fontWeight: FontWeight.w700))),
          Text(on ? '%${(_vol[k]! * 100).round()}' : 'kapalı', style: T.small.copyWith(fontWeight: FontWeight.w700, color: on ? color : kInkFaint)),
        ]),
        _missing.contains(k)
            ? Padding(padding: const EdgeInsets.fromLTRB(52, 4, 0, 8), child: Text('Ses dosyası pakette yok (assets/audio/CREDITS.md)', style: T.small.copyWith(color: kDanger, fontSize: 12)))
            : SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color, inactiveTrackColor: color.withValues(alpha: .15)), child: Slider(value: _vol[k]!, onChanged: (v) async {
                setState(() => _vol[k] = v);
                final ok = await SleepMixer.setVolume(k, v);
                if (!ok) setState(() { _missing.add(k); _vol[k] = 0; });
              })),
      ]),
    );
  }
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
        backgroundColor: kIce,
        appBar: AppBar(title: const Text('SOS Feneri')),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
          Bento(padding: const EdgeInsets.all(22), child: Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 300), width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: (_on ? kDanger : kDanger.withValues(alpha: .1)),
                    boxShadow: _on ? [BoxShadow(color: kDanger.withValues(alpha: .45), blurRadius: 40, spreadRadius: 4)] : null),
                child: Icon(Icons.sos_rounded, size: 64, color: _on ? Colors.white : kDanger)),
            const SizedBox(height: 18),
            Text(_on ? 'Fener SOS veriyor' : 'Işıkla yardım çağrısı', style: T.h2),
            const SizedBox(height: 6),
            const Text('Fener SOS ritmiyle (… --- …) yanıp söner.', textAlign: TextAlign.center, style: T.small),
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: T.small.copyWith(color: kDanger))),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _on ? kInk : kDanger),
              onPressed: () { if (_on) { _cancel = true; } else { _run(); } },
              icon: Icon(_on ? Icons.stop_rounded : Icons.flashlight_on_rounded), label: Text(_on ? 'Durdur' : 'Başlat'),
            )),
          ])),
          const SizedBox(height: 12),
          Bento(color: const Color(0xFFFFF1E2), child: Row(children: [
            const IconBadge(Icons.call_rounded, color: kDanger, size: 40), const SizedBox(width: 12),
            Expanded(child: Text('Gerçek acil durumda önce 112\'yi ara kanki.', style: T.body.copyWith(fontWeight: FontWeight.w700))),
          ])),
        ]),
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
        backgroundColor: kIce,
        appBar: AppBar(title: const Text('Zaman Kapsülü')),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
          Bento(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BlockHead('Bugünü sakla', dot: kWarn),
            const SizedBox(height: 8),
            const Text('Şu anki hava kapsüle girer; yanına bir cümle ekle, yıllar sonra aç.', style: T.small),
            const SizedBox(height: 12),
            TextField(controller: _note, maxLines: 2, decoration: InputDecoration(hintText: 'Bugünü bir cümleyle anlat…', filled: true, fillColor: kIce,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.inventory_2_rounded), label: const Text('Kapsüle koy'))),
          ])),
          if (_items.isNotEmpty) ...[const SizedBox(height: 18), BlockHead('Kapsüller', dot: kWarn, trailing: Text('${_items.length}', style: T.small.copyWith(fontWeight: FontWeight.w700))), const SizedBox(height: 10)],
          for (final c in _items) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bento(padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 56, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: kBentoPeach, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text('${(c['temp'] as num).round()}°', style: T.num.copyWith(fontSize: 18)),
                  Text(c['t'].toString().substring(0, 4), style: T.small.copyWith(fontSize: 11)),
                ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['place'] ?? ''}', style: T.body.copyWith(fontWeight: FontWeight.w700)),
              Text(c['t'].toString().substring(0, 16).replaceAll('T', ' '), style: T.small.copyWith(fontSize: 12)),
              if ((c['note'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c['note']}', style: T.body.copyWith(fontSize: 14))),
            ])),
            IconButton(icon: const Icon(Icons.share_rounded, color: kInkSoft), onPressed: () => Share.share('SkyNav zaman kapsülü: ${c['place']} ${(c['temp'] as num).round()}° — ${c['note']}')),
          ]))),
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
              Positioned(left: 12, right: 12, bottom: 90, child: Glass(child: Row(children: [
                const IconBadge(Icons.live_tv_rounded, color: kDanger, size: 36), const SizedBox(width: 10),
                Expanded(child: Text(s == null ? 'SkyNav Hava Kanalı' : '${s.place.name}: ${s.temp.round()}° · ${a?.kind.name} · rüzgâr ${s.windSpeed.toStringAsFixed(1)} m/s', style: T.body.copyWith(fontWeight: FontWeight.w800))),
              ]))),
              Positioned(left: 0, right: 0, bottom: 20, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FilledButton(style: FilledButton.styleFrom(backgroundColor: _rec ? const Color(0xFFC62828) : kAccent), onPressed: () async {
                  if (_rec) { _last = await _c!.stopVideoRecording(); setState(() => _rec = false); } else { await _c!.startVideoRecording(); setState(() => _rec = true); }
                }, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_rec ? Icons.stop_rounded : Icons.fiber_manual_record_rounded, size: 20), const SizedBox(width: 6), Text(_rec ? 'Kaydı bitir' : 'Kayda başla')])),
                if (_last != null) Padding(padding: const EdgeInsets.only(left: 8), child: OutlinedButton(onPressed: () => Share.shareXFiles([_last!]), child: const Text('Paylaş'))),
              ])),
            ]),
    );
  }
}
