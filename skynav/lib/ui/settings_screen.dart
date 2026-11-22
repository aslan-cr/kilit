import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/policy_text.dart';
import '../pro/pro_service.dart';
import '../services/auth_service.dart';
import '../services/store.dart';
import '../services/weather_repository.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Glass(child: Column(children: [
            ListTile(leading: const Icon(Icons.person_outline), title: Text(AuthService.user?.email ?? 'Giriş yapılmadı'),
                subtitle: Text('Durum: ${ProService.I.state.label}'),
                trailing: AuthService.user == null
                    ? TextButton(onPressed: () async { final u = await AuthService.signInWithGoogle(); if (u != null) await ProService.I.onSignedIn(); setState(() {}); }, child: const Text('Giriş'))
                    : TextButton(onPressed: () async { await AuthService.signOut(); setState(() {}); }, child: const Text('Çıkış'))),
            ListTile(leading: const Text('⭐'), title: const Text('SkyNav Pro & indirim'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall()))),
          ])),
          const SizedBox(height: 12),
          Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Diğer Uygulamalarım', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Aynı hesapla 7+ gündür aktif 4 uygulama = 30 gün Pro.', style: TextStyle(fontSize: 12, color: kInkSoft)),
            if (_apps.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Henüz kayıtlı uygulama yok (giriş yapınca görünür).')),
            for (final a in _apps) ListTile(dense: true, leading: const Icon(Icons.apps), title: Text(a['id'].toString()), subtitle: Text('İlk: ${(a['firstSeen'] as dynamic)?.toDate().toString().substring(0, 10) ?? '-'}')),
          ])),
          const SizedBox(height: 12),
          Glass(child: Column(children: [
            ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Gizlilik Politikası'), onTap: () => _show('Gizlilik Politikası', privacyText)),
            ListTile(leading: const Icon(Icons.gavel), title: const Text('Kullanım Şartları'), onTap: () => _show('Kullanım Şartları', termsText)),
            ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Veri Kullanımı & İzinler'), onTap: () => _show('Veri Kullanımı & İzinler', dataText)),
            ListTile(leading: const Icon(Icons.lock_open), title: const Text('Uygulama izinlerini aç/değiştir'), onTap: openAppSettings),
            SwitchListTile(secondary: const Icon(Icons.bolt), title: const Text('Turbo Mod (1 dk, Pro)'), subtitle: const Text('Kapalıyken pil dostu: 15 dk'),
                value: WeatherController.I.turbo, onChanged: (v) { if (ProService.I.state.isPro) { setState(() => WeatherController.I.turbo = v); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const Paywall())); } }),
          ])),
          if (_devUnlocked) ...[
            const SizedBox(height: 12),
            Glass(tint: const Color(0xFFFFF3E0), child: SwitchListTile(
              title: const Text('Geliştirici Modu: Tüm Pro Özellikleri Ücretsiz Kilitsiz', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Açıkken Pro sonsuza dek açık; lansman ödül sayacından düşmez.'),
              value: ProService.I.devMode, onChanged: (v) async { await ProService.I.setDevMode(v); setState(() {}); },
            )),
          ],
          const SizedBox(height: 12),
          Center(child: GestureDetector(onTap: _tapVersion, child: Padding(padding: const EdgeInsets.all(12), child: Text('SkyNav sürüm $_ver', style: const TextStyle(color: kInkSoft))))),
        ]),
      );

  void _show(String t, String body) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      expand: false, initialChildSize: .8, builder: (_, c) => ListView(controller: c, padding: const EdgeInsets.all(20), children: [Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text(body)])));
}
