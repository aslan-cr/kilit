import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/store.dart';
import 'bento.dart';
import 'hero_scene.dart' show ScenePalette;
import 'scene_shaders.dart' show DecorScene;
import 'theme.dart';

/// "Yenilikler": güncellemeden sonra bir kez açılır; Ayarlar'dan her zaman ulaşılır.
class WhatsNew extends StatelessWidget {
  const WhatsNew({super.key});

  static const _groups = <(IconData, Color, Color, String, List<String>)>[
    (Icons.landscape_rounded, Color(0xFF3B7DDD), kBentoBlue, 'Canlı sahne', [
      'Gece göğünde o an gerçekten görünen yıldızlar ve gezegenler',
      'Derinlikli kar, yere sıçrayan yağmur, dallanan şimşek, vadide sis',
      'Canlı pencere: tam ekran sahne, telefonu eğince derinlik, gerçek doğa sesleri, paylaş',
    ]),
    (Icons.grid_view_rounded, kGood, kBentoMint, 'Keşfet menüsü', [
      'Gök & Ay: bu gece gökte, Ay saatleri, fotoğrafçı saatleri, gökyüzü takvimi',
      'Yerlerim ve iki yeri karşılaştırma · En iyi zaman · Kayak merkezleri',
      'İklim: normalden ne kadar farklı, rekorlar, bu kış kar, son 30 gün',
      'Hava kalitesi · 72 saatlik basınç ve rüzgâr grafikleri',
    ]),
    (Icons.notifications_active_outlined, kDanger, Color(0xFFFFEDEE), 'Bildirimler', [
      'Fırtına, buzlanma, yoğun kar ve tipi uyarıları',
      'Yağış geliyor: 30 dakika içinde başlayacaksa haber',
      'Sabah özeti (saatini sen seç) · meteor yağmuru ve tutulma akşamları',
    ]),
    (Icons.widgets_outlined, kPro, Color(0xFFEFEAFE), 'Ana ekran widget\'ları', [
      'Saatlik, Mini, Ay, Kayak ve Hava kalitesi; dokununca ilgili sayfa açılır',
    ]),
    (Icons.touch_app_outlined, kWarn, kBentoPeach, 'Kolaylık', [
      'Günlere ve saatlere dokun: ayrıntı sayfası',
      'Anlaşılır dil: bilimsel terimler gündelik dile döner',
      'Konum araması yazarken arar; büyük yazı ve ekran okuyucu desteği',
    ]),
  ];

  static Future<String> _version() async { try { return (await PackageInfo.fromPlatform()).version; } catch (_) { return ''; } }

  /// Yeni bir sürüme geçildiyse bir kez gösterir; yeni kurulumda göstermez (yalnızca işaretler).
  static Future<void> maybeShow(BuildContext context) async {
    final v = await _version();
    if (v.isEmpty) return;
    final seen = Store.prefs.get('whats_new_seen') as String?;
    if (seen == v) return;
    await Store.put('whats_new_seen', v);
    final fresh = seen == null && DateTime.now().difference(Store.firstRun) < const Duration(hours: 1);
    if (fresh || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const WhatsNew()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kIce,
        body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
          Row(children: [
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const DecorScene(pal: ScenePalette.clearNight, night: true, height: 168, cover: .25, light: .45, sun: Offset(.72, .32)),
          const SizedBox(height: 18),
          FutureBuilder<String>(future: _version(), builder: (_, v) => Text(v.data == null || v.data!.isEmpty ? 'SkyNav' : 'SkyNav ${v.data}',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -.8, color: kInk, height: 1.1))),
          const SizedBox(height: 6),
          const Text('Neler yeni kanki? Kısaca:', style: T.body),
          const SizedBox(height: 16),
          for (final (icon, fg, bg, title, items) in _groups) ...[
            Bento(color: bg, padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), shape: BoxShape.circle),
                  child: Icon(icon, color: fg, size: 21)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                for (final t in items) Padding(padding: const EdgeInsets.only(top: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: T.small.copyWith(color: kInk, height: 1.35))),
                ])),
              ])),
            ])),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          FilledButton(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: const Text('Hadi bakalım', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 16))),
        ])),
      );
}
