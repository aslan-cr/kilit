import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/policy_text.dart';
import '../pro/pro_service.dart';
import '../services/auth_service.dart';
import '../services/store.dart';
import '../services/weather_repository.dart';
import '../widgets/widget_service.dart';
import '../services/icon_service.dart';
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geliştirici modu açıldı 🛠️')));
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

        const SectionLabel('Güncelleme & widget'),
        _group([
          _tile(Icons.bolt_rounded, kWarn, 'Turbo mod (1 dk)', sub: 'Kapalıyken pil dostu: 15 dakikada bir · Pro',
              trailing: Switch(value: WeatherController.I.turbo, onChanged: (v) { if (ProService.I.state.isPro) { setState(() => WeatherController.I.turbo = v); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall())); } })),
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
