import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/phrases.dart';
import '../data/policy_text.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_backup.dart';
import '../services/notify_service.dart';
import '../services/store.dart';
import 'hero_scene.dart' show ScenePalette;
import 'scene_shaders.dart';
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
      // Daha önce bu Gmail ile kullandıysa: yerler, rozetler, kapsüller, ayarlar geri gelsin
      CloudBackup.announce(await CloudBackup.restoreIfNeeded());
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
          const Positioned.fill(child: ColoredBox(color: kIce)),
          SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(children: [
                const _Logo(size: 34),
                const SizedBox(width: 10),
                const Text('SkyNav', style: TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.w800, color: kInk, letterSpacing: -.4)),
                const Spacer(),
                for (var i = 0; i < 4; i++) AnimatedContainer(
                  duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(left: 6),
                  width: i == _page ? 22 : 8, height: 8,
                  decoration: BoxDecoration(color: i <= _page ? kAccent : kAccent.withValues(alpha: .2), borderRadius: BorderRadius.circular(4)),
                ),
              ]),
            ),
            Expanded(child: PageView(
              controller: _pc,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [_policyPage(), _discoverPage(), _permPage(), _loginPage()],
            )),
          ])),
        ]),
      );

  Widget _page0(List<Widget> top, List<Widget> bottom) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView(padding: EdgeInsets.zero, children: top)),
          const SizedBox(height: 12),
          ...bottom,
        ]),
      );

  Widget _policyPage() => _page0([
        const SizedBox(height: 4),
        // Süs sahnesi: gün batımında karlı zirveler (veri göstermez)
        const DecorScene(pal: ScenePalette.goldenHour, height: 168, cover: .32, cloudLit: Color(0xFFFFDCC0), cloudShade: Color(0xFF8E6F88), cloudWeight: .2,
            sun: Offset(.76, .44), light: .9, snowLit: Color(0xFFFFC9B5)),
        const SizedBox(height: 20),
        const Text('Gökyüzü cebinde,\nkanki.', style: TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1, color: kInk)),
        const SizedBox(height: 10),
        const Text('Hava, yol ve yıldızlar tek uygulamada. Reklam yok, zorlama yok.', style: T.body),
        const SizedBox(height: 22),
        const _Feature(Icons.ac_unit_rounded, kSnow, 'Kar, mercimek karı, tipi', 'Bulunduğun noktaya özel, dağları da hesaba katan tahmin'),
        const _Feature(Icons.navigation_rounded, kGood, 'Akıllı yol tarifi', 'Buzlu yolda uyaran, sesli ve samimi asistan'),
        const _Feature(Icons.nights_stay_rounded, Color(0xFF5B5BD6), 'Gece gökyüzü', 'Takımyıldızlar, ISS geçişleri, yıldız netliği'),
        const SizedBox(height: 18),
        const Text('BAŞLAMADAN ÖNCE', style: T.label),
        const SizedBox(height: 10),
        Glass(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
          _docTile(Icons.privacy_tip_outlined, 'Gizlilik Politikası', privacyText),
          const Divider(height: 1, indent: 64),
          _docTile(Icons.gavel_rounded, 'Kullanım Şartları', termsText),
          const Divider(height: 1, indent: 64),
          _docTile(Icons.shield_outlined, 'Veri Kullanımı & İzinler', dataText),
        ])),
      ], [
        InkWell(
          borderRadius: BorderRadius.circular(16), onTap: () => setState(() => _accepted = !_accepted),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180), width: 26, height: 26,
              decoration: BoxDecoration(color: _accepted ? kAccent : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _accepted ? kAccent : kInkFaint, width: 2)),
              child: _accepted ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Okudum ve Kabul Ediyorum', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: kInk))),
          ])),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _accepted ? () async { await Store.put('consent_v1', true); _next(); } : null, child: const Text('Devam')),
      ]);

  Widget _docTile(IconData icon, String title, String body) => ListTile(
        leading: IconBadge(icon, size: 38, color: kInkSoft),
        title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right_rounded, color: kInkFaint),
        onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
            expand: false, initialChildSize: .75, builder: (_, c) => ListView(controller: c, padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
              Text(title, style: T.h1), const SizedBox(height: 14), Text(body, style: T.body),
            ]))),
      );

  Widget _discoverPage() => _page0([
        const SizedBox(height: 8),
        const Text('Bizi nereden\nbuldun?', style: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1, color: kInk)),
        const SizedBox(height: 10),
        const Text('Arkadaşın davet ettiyse ikiniz de 1 hafta SkyNav Pro kazanırsınız.', style: T.body),
        const SizedBox(height: 22),
        _Choice(icon: Icons.card_giftcard_rounded, color: kPro, title: 'Davet edildim', sub: 'Arkadaşımın kodu var', selected: _invited, onTap: () { Sfx.tap(); setState(() => _invited = true); }),
        const SizedBox(height: 12),
        _Choice(icon: Icons.explore_rounded, color: kAccent, title: 'Kendim keşfettim', sub: 'YouTube’da ya da başka yerde gördüm', selected: false, onTap: () { Sfx.tap(); Store.put('source', 'self'); _next(); }),
        if (_invited) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _code, textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'SKY-XXXXXX', filled: true, fillColor: Colors.white,
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Kod, Google ile giriş yaptığında onaylanır. Tek kullanımlıktır; kendi kodunu giremezsin.', style: T.small),
        ],
      ], [
        if (_invited) FilledButton(onPressed: () async {
          final c = _code.text.trim();
          if (c.isEmpty) return;
          await Store.put('pending_code', c.toUpperCase()); await Store.put('source', 'invite'); _next();
        }, child: const Text('Kodu kaydet ve devam')),
      ]);

  Widget _permPage() => _page0([
        const SizedBox(height: 8),
        const Text('İki küçük izin', style: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1, color: kInk)),
        const SizedBox(height: 10),
        const Text('Neden istediğimizi açıkça söylüyoruz. Vermezsen de uygulama çalışır.', style: T.body),
        const SizedBox(height: 22),
        const _Feature(Icons.location_on_rounded, kAccent, 'Konum', 'Tam bulunduğun noktanın havası, gerçek rakımın ve çevre dağların için. Vermezsen şehri elle seçersin.'),
        const _Feature(Icons.notifications_active_rounded, kWarn, 'Bildirim', 'Kar, tipi, fırtına ve ISS geçişi uyarıları için. Vermezsen uyarıları yalnızca uygulamada görürsün.'),
        const SizedBox(height: 6),
        const Text('İzinleri sonra Ayarlar’dan da değiştirebilirsin.', style: T.small),
      ], [
        FilledButton(onPressed: _busy ? null : _permissions, child: const Text('İzinleri iste')),
        const SizedBox(height: 6),
        TextButton(onPressed: _next, child: const Text('Şimdilik geç')),
      ]);

  Widget _loginPage() => _page0([
        const SizedBox(height: 8),
        const Text('Tek hesap,\ntüm uygulamalar', style: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1, color: kInk)),
        const SizedBox(height: 10),
        const Text('Google ile girersen haklarını kaybetmezsin, uygulamalarım arasında birleşir.', style: T.body),
        const SizedBox(height: 22),
        const _Feature(Icons.workspace_premium_rounded, kPro, '4 uygulama = 1 ay Pro', 'Aynı hesapla 4 uygulamamı 7+ gün kullanırsan 30 gün Pro hediye.'),
        const _Feature(Icons.card_giftcard_rounded, kGood, 'Davet ödülleri', 'Kodunu paylaş; arkadaşın onaylarsa ikiniz de 1 hafta Pro.'),
        const _Feature(Icons.sync_rounded, kAccent, 'Hakların güvende', 'Telefon değiştirsen de Pro ve ödüllerin hesabında kalır.'),
        for (final n in _notes) Padding(padding: const EdgeInsets.only(top: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: kWarn), const SizedBox(width: 8), Expanded(child: Text(n, style: T.small.copyWith(color: kInk))),
        ])),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg!, style: T.small.copyWith(color: kDanger))),
      ], [
        SizedBox(height: 54, child: OutlinedButton(
          style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: kLine, width: 1.5)),
          onPressed: _busy ? null : _signIn,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('G', style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
            const SizedBox(width: 12),
            Text(_busy ? 'Bağlanıyor…' : 'Google ile devam et', style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
          ]),
        )),
        const SizedBox(height: 6),
        TextButton(onPressed: widget.onDone, child: const Text('Girişsiz devam et')),
      ]);
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({this.size = 34});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .32), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5AB0FF), Color(0xFF2F6FE0)])),
        child: Icon(Icons.ac_unit_rounded, color: Colors.white, size: size * .58),
      );
}

class _Feature extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub;
  const _Feature(this.icon, this.color, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(icon, color: color, size: 44),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 2),
            Text(sub, style: T.small),
          ])),
        ]),
      );
}

class _Choice extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub; final bool selected; final VoidCallback onTap;
  const _Choice({required this.icon, required this.color, required this.title, required this.sub, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Glass(
        onTap: onTap, tint: selected ? color.withValues(alpha: .08) : null,
        child: Row(children: [
          IconBadge(icon, color: color, size: 50),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: kInk)),
            Text(sub, style: T.small),
          ])),
          Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: selected ? color : kInkFaint),
        ]),
      );
}
