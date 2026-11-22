import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/phrases.dart';
import '../data/policy_text.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/notify_service.dart';
import '../services/store.dart';
import 'sky_background.dart';
import 'theme.dart';

class Onboarding extends StatefulWidget {
  final VoidCallback onDone;
  const Onboarding({super.key, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pc = PageController();
  int _page = 0;
  bool _accepted = false;
  bool _invited = false;
  final _code = TextEditingController();
  String? _msg;
  bool _busy = false;
  final _notes = <String>[];

  void _next() { Sfx.tap(); _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic); }

  Future<void> _permissions() async {
    setState(() => _busy = true);
    _notes.clear();
    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) _notes.add(Kanki.konumIzinYok);
    final n = await Permission.notification.request();
    if (!n.isGranted) _notes.add(Kanki.bildirimIzinYok);
    await Notify.requestPermission();
    await Store.put('perm_asked', true);
    setState(() => _busy = false);
    _next();
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _msg = null; });
    final u = await AuthService.signInWithGoogle();
    if (u != null) {
      await ProService.I.onSignedIn();
      final pending = Store.get<String>('pending_code');
      if (pending != null) {
        final err = await ProService.I.redeemInvite(pending);
        if (err == null) { await Store.put('pending_code', null); } else { _msg = err; }
      }
      setState(() => _busy = false);
      if (_msg == null) widget.onDone();
    } else {
      setState(() { _busy = false; _msg = AuthService.lastError; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: SkyBackground(state: SkyState(cloud: 35))),
          SafeArea(child: PageView(
            controller: _pc,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [_policyPage(), _discoverPage(), _permPage(), _loginPage()],
          )),
        ]),
      );

  Widget _wrap(List<Widget> kids) => Padding(
        padding: const EdgeInsets.all(18),
        child: Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids)),
      );

  Widget _policyPage() => _wrap([
        const Text('☁️ SkyNav\'a hoş geldin kanki', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Reklam yok, zorlama yok. Başlamadan önce kuralları kısaca oku:', style: TextStyle(color: kInkSoft)),
        const SizedBox(height: 10),
        Expanded(child: ListView(children: [
          _doc('Gizlilik Politikası', privacyText),
          _doc('Kullanım Şartları', termsText),
          _doc('Veri Kullanımı & İzinler', dataText),
        ])),
        CheckboxListTile(
          value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false),
          title: const Text('Okudum ve Kabul Ediyorum', style: TextStyle(fontWeight: FontWeight.w700)),
          controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero,
        ),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _accepted ? () async { await Store.put('consent_v1', true); _next(); } : null, child: const Text('Devam'))),
      ]);

  Widget _doc(String t, String body) => ExpansionTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), tilePadding: EdgeInsets.zero, children: [Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)))]);

  Widget _discoverPage() => _wrap([
        const Text('Seni nereden tanıyoruz?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Arkadaşın davet ettiyse ikiniz de 1 hafta Pro kazanırsınız.', style: TextStyle(color: kInkSoft)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () { Sfx.tap(); setState(() => _invited = true); }, icon: const Text('🤝'), label: const Text('Davet Edildim')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () { Sfx.tap(); Store.put('source', 'self'); _next(); }, icon: const Text('🔎'), label: const Text('Kendim Keşfettim / YouTube\'dan Gördüm')),
        if (_invited) ...[
          const SizedBox(height: 16),
          TextField(controller: _code, textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'Davet kodu (SKY-XXXXXX)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 8),
          const Text('Kod, Google ile giriş yaptığında onaylanır; tek kullanımlıktır, kendi kodunu giremezsin.', style: TextStyle(fontSize: 12, color: kInkSoft)),
          const SizedBox(height: 8),
          FilledButton(onPressed: () async {
            final c = _code.text.trim();
            if (c.isEmpty) return;
            await Store.put('pending_code', c.toUpperCase()); await Store.put('source', 'invite'); _next();
          }, child: const Text('Kodu kaydet ve devam')),
        ],
      ]);

  Widget _permPage() => _wrap([
        const Text('İzinler, açık açık', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text('📍 Konum: bulunduğun noktanın havasını, rakımını ve çevre dağlarını bulmak için.'),
        const SizedBox(height: 6),
        const Text('🔔 Bildirim: kutlama ve tehlikeli hava uyarıları için.'),
        const SizedBox(height: 6),
        const Text('Vermezsen sorun yok: uygulama kilitlenmez, elle şehir seçip temel görünümle devam edersin. Sonradan Ayarlar\'dan da açabilirsin.', style: TextStyle(color: kInkSoft)),
        const Spacer(),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _permissions, child: const Text('İzinleri iste'))),
        TextButton(onPressed: _next, child: const Text('Şimdilik geç')),
      ]);

  Widget _loginPage() => _wrap([
        const Text('Tek hesap, tüm uygulamalarım', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Google ile girersen davet/ödül haklarını ve diğer uygulamalarımdaki kullanımını birleştiririm: aynı hesapla 4 uygulamayı 7+ gün kullanırsan 30 gün Pro hediye.', style: TextStyle(color: kInkSoft)),
        for (final n in _notes) Padding(padding: const EdgeInsets.only(top: 8), child: Text('ℹ️ $n', style: const TextStyle(fontSize: 13))),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: Color(0xFFC62828)))),
        const Spacer(),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _signIn, icon: const Text('G'), label: const Text('Google ile giriş yap'))),
        TextButton(onPressed: widget.onDone, child: const Text('Girişsiz devam et')),
      ]);
}
