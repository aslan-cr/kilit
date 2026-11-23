import 'gpu.dart';
import 'plain.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/policy_text.dart';
import '../pro/pro_service.dart';
import '../services/auth_service.dart';
import '../services/store.dart';
import '../services/weather_repository.dart';
import '../widgets/widget_service.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../services/icon_service.dart';
import '../services/notify_service.dart';
import '../services/shared_state.dart';
import 'badges_screen.dart';
import 'paywall.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ver = '';
  int _taps = 0;
  bool _devUnlocked = Store.prefs.get('dev_unlocked', defaultValue: false) as bool;
  List<Map<String, dynamic>> _apps = [];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) => setState(() => _ver = '${p.version}+${p.buildNumber}'));
    ProService.I.myApps().then((a) => setState(() => _apps = a));
  }

  void _tapVersion() async {
    _taps++;
    if (_taps >= 7 && !_devUnlocked) {
      _devUnlocked = true; await Store.put('dev_unlocked', true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geliştirici modu açıldı.')));
    }
    setState(() {});
  }

  Widget _tile(IconData icon, Color color, String title, {String? sub, Widget? trailing, VoidCallback? onTap}) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: IconBadge(icon, color: color, size: 38),
        title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15, color: kInk)),
        subtitle: sub == null ? null : Text(sub, style: T.small.copyWith(fontSize: 12.5)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, color: kInkFaint) : null),
        onTap: onTap,
      );

  Widget _group(List<Widget> kids) {
    final out = <Widget>[];
    for (var i = 0; i < kids.length; i++) { if (i > 0) out.add(const Divider(height: 1, indent: 66)); out.add(kids[i]); }
    return Glass(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: out));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        Glass(child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: kAccent.withValues(alpha: .12),
              child: Text((user?.email ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: kAccent))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.email ?? 'Giriş yapılmadı', style: T.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Pill(ProService.I.state.label, color: ProService.I.state.isPro ? kPro : kInkSoft, icon: Icons.workspace_premium_rounded),
          ])),
          user == null
              ? FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 42)), onPressed: () async { final u = await AuthService.signInWithGoogle(); if (u != null) await ProService.I.onSignedIn(); setState(() {}); }, child: const Text('Giriş'))
              : TextButton(onPressed: () async { await AuthService.signOut(); setState(() {}); }, child: const Text('Çıkış')),
        ])),

        const SectionLabel('SkyNav Pro'),
        _group([
          _tile(Icons.workspace_premium_rounded, kPro, 'Pro & arkadaş indirimi', sub: 'Paketler, davet kodun, indirim durumu', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall()))),
          _tile(Icons.emoji_events_rounded, kWarn, 'Rozetler & kar yarışı', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen()))),
        ]),

        const SectionLabel('Görünüm'),
        _group([
          _tile(Icons.record_voice_over_outlined, kGood, 'Anlaşılır dil', sub: 'Bilimsel terimler herkesin anlayacağı dile döner: hPa → hava basıncı, CAPE → gök gürültüsü riski, m/s → km/s',
              trailing: Switch(value: Plain.on, onChanged: (v) async { await Plain.set(v); setState(() {}); })),
        ]),

        const SectionLabel('Güncelleme & widget'),
        _group([
          _tile(Icons.bolt_rounded, kWarn, 'Turbo mod (1 dk)', sub: 'Kapalıyken pil dostu: 15 dakikada bir · Pro',
              trailing: Switch(value: WeatherController.I.turbo, onChanged: (v) { if (ProService.I.state.isPro) { setState(() => WeatherController.I.turbo = v); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall())); } })),
          _tile(Icons.notifications_active_outlined, kDanger, 'Hava uyarıları', sub: 'Fırtına, buzlanma, yoğun kar, tipi · arka planda 15 dakikada bir',
              trailing: Switch(value: SharedState.cached?.getBool('sn_alerts_off') != true, onChanged: (v) async {
                final p = await SharedState.get();
                await p.setBool('sn_alerts_off', !v);
                if (v) await Notify.requestPermission();
                setState(() {});
              })),
          _tile(Icons.auto_awesome_rounded, kAccent, 'Dinamik ikon', sub: 'Uygulama ikonu havaya göre değişir · uygulamadan çıkınca uygulanır',
              trailing: Switch(value: IconService.enabled, onChanged: (v) async { await IconService.setEnabled(v); setState(() {}); })),
          _tile(Icons.speed_rounded, kGood, 'Hız & yol widget’ı', sub: 'Görünür bildirimle canlı GPS hızı · Pro',
              trailing: Switch(value: WidgetService.speedTracking, onChanged: (v) async { if (!ProService.I.state.isPro) { Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall())); return; } if (v) { await WidgetService.startSpeedTracking(); } else { await WidgetService.stopSpeedTracking(); } setState(() {}); })),
        ]),

        const SectionLabel('Diğer uygulamalarım'),
        Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Aynı hesapla 7+ gündür aktif 4 uygulama = 30 gün Pro.', style: T.small),
          if (_apps.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Henüz kayıtlı uygulama yok (giriş yapınca görünür).', style: T.body.copyWith(fontSize: 14))),
          for (final a in _apps) ListTile(contentPadding: EdgeInsets.zero, leading: const IconBadge(Icons.apps_rounded, size: 36), title: Text(a['id'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('İlk: ${(a['firstSeen'] as dynamic)?.toDate().toString().substring(0, 10) ?? '-'}')),
        ])),

        const SectionLabel('Gizlilik & izinler'),
        _group([
          _tile(Icons.privacy_tip_outlined, kInkSoft, 'Gizlilik Politikası', onTap: () => _show('Gizlilik Politikası', privacyText)),
          _tile(Icons.gavel_rounded, kInkSoft, 'Kullanım Şartları', onTap: () => _show('Kullanım Şartları', termsText)),
          _tile(Icons.shield_outlined, kInkSoft, 'Veri Kullanımı & İzinler', onTap: () => _show('Veri Kullanımı & İzinler', dataText)),
          _tile(Icons.app_settings_alt_outlined, kAccent, 'Uygulama izinlerini değiştir', onTap: openAppSettings),
          _tile(Icons.copyright_rounded, kInkSoft, 'Kaynaklar ve lisanslar', sub: 'Ay haritası, yıldızlar, doğa sesleri, yazı tipi, haritalar', onTap: () => _show('Kaynaklar ve lisanslar', creditsText)),
        ]),

        if (_devUnlocked) ...[
          const SectionLabel('Geliştirici'),
          Glass(tint: const Color(0xFFFFF3E0), child: Row(children: [
            const IconBadge(Icons.developer_mode_rounded, color: kWarn, size: 40), const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Geliştirici Modu: Tüm Pro Özellikleri Ücretsiz Kilitsiz', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, color: kInk)),
              Text('Açıkken Pro sonsuza dek açık; lansman ödül sayacından düşmez.', style: T.small),
            ])),
            Switch(value: ProService.I.devMode, onChanged: (v) async { await ProService.I.setDevMode(v); setState(() {}); }),
          ])),
        ],
        const SectionLabel('Tanılama'),
        Builder(builder: (_) {
          final p = SharedState.cached;
          final err = p?.getString('sn_last_error');
          final t = p?.getInt('sn_last_error_t');
          return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(err == null ? Icons.check_circle_outline_rounded : Icons.bug_report_outlined, color: err == null ? kGood : kWarn, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Text(err == null ? 'Kayıtlı hata yok' : 'Son hata · ${DateTime.fromMillisecondsSinceEpoch(t ?? 0).toString().substring(0, 16)}', style: T.body.copyWith(fontWeight: FontWeight.w700))),
            ]),
            if (err != null) ...[
              const SizedBox(height: 10),
              Text(err.split('\n').take(4).join('\n'), style: T.small.copyWith(fontSize: 11.5), maxLines: 6, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: err)), icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Kopyala')),
                TextButton(onPressed: () async { await p!.remove('sn_last_error'); setState(() {}); }, child: const Text('Temizle')),
              ]),
            ],
            const SizedBox(height: 4),
            Text('İkon: ${p?.getString('sn_icon_key') ?? 'kar (varsayılan)'} · bekleyen: ${p?.getString('sn_icon_pending') ?? '-'}', style: T.small.copyWith(fontSize: 11.5)),
            Text(Gpu.summary, style: T.small.copyWith(fontSize: 11.5)),
          ]));
        }),
        const SizedBox(height: 18),
        Center(child: GestureDetector(onTap: _tapVersion, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const Icon(Icons.ac_unit_rounded, color: kInkFaint, size: 20),
          const SizedBox(height: 4),
          Text('SkyNav $_ver', style: T.small),
        ])))),
      ]),
    );
  }

  void _show(String t, String body) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      expand: false, initialChildSize: .8, builder: (_, c) => ListView(controller: c, padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [Text(t, style: T.h1), const SizedBox(height: 14), Text(body, style: T.body)])));
}

/// Üçüncü taraf içerikler ve lisansları (CC BY gibi lisanslar kaynak gösterilmesini ister).
const creditsText = '''Ay görüntüsü: Solar System Scope (solarsystemscope.com) Ay dokusu, NASA Lunar Reconnaissance Orbiter (LRO) verisine dayanır. Lisans: CC BY 4.0. Uygulamada küreye sarılıp gerçek evreye göre aydınlatılır.

Doğa sesleri: Freesound.org kullanıcıları ali-k, greysound, florianreichelt, cagancelik. Lisans: CC0 (kamu malı). Gerçek kayıtlardır, sentetik ses yoktur.

Yıldızlar: Yale Parlak Yıldız Kataloğu, 5. baskı (Hoffleit & Warren 1991, Harvard/CDS), kamu malı. Ana sahnedeki yıldızlar ve gezegenler o an gökte gerçekten bulundukları yerde ve parlaklıkta çizilir.

Yazı tipi: Inter, Rasmus Andersson. Lisans: SIL Open Font License 1.1.

Haritalar ve uydu: Esri World Imagery ve World Hillshade, OpenStreetMap katkıcıları (ODbL), NASA GIBS (MODIS), RainViewer radar.

Hava verisi: Open-Meteo (CC BY 4.0), havalimanı ölçümleri NOAA Aviation Weather Center, uzay havası NOAA SWPC. Uçaklar: OpenSky Network. Uydular: CelesTrak. Yol tarifi: OSRM. Yer arama: Photon (komoot), Overpass API (OpenStreetMap).

Bulutlar, dağlar ve gökyüzü uygulamanın kendi kodu ile çizilir.''';
