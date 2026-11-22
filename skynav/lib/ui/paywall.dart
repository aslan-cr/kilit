import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../pro/billing_service.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import 'sky_background.dart';
import 'theme.dart';

class Paywall extends StatefulWidget {
  const Paywall({super.key});
  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  bool _life = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(),
        body: Stack(children: [
          const Positioned.fill(child: SkyBackground(state: SkyState(cloud: 20))),
          ListenableBuilder(
            listenable: Listenable.merge([ProService.I, BillingService.I]),
            builder: (_, __) {
              final st = ProService.I.state;
              final d = ProService.I.discount;
              final l = BillingService.I.labels(d.active);
              return ListView(padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 52, 18, 32), children: [
                // ── Vitrin ──
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7B5CFA), Color(0xFF2F80ED)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF4F6BF0).withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -8)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                          child: Text(st.label, style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
                    ]),
                    const SizedBox(height: 18),
                    const Text('SkyNav Pro', style: TextStyle(fontFamily: 'Inter', fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -.8)),
                    const SizedBox(height: 6),
                    Text('Zorunlu değil kanki. Reklam yok, temel özellikler hep ücretsiz. Pro, geliştirici masrafını çıkarmaya destek olur ve ileri modülleri açar.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white.withValues(alpha: .9), height: 1.4, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 18),
                const _Perk(Icons.ac_unit_rounded, kSnow, 'Hava Pro', '50+ senaryo, dağ radarı, sis radarı, model kıyaslaması, 1 dk Turbo mod'),
                const _Perk(Icons.navigation_rounded, kGood, 'Yol Pro', 'Buz ve tipiye göre akıllı varış süresi, kayma sensörü, hız widget’ı'),
                const _Perk(Icons.nights_stay_rounded, Color(0xFF5B5BD6), 'Astronomi Pro', 'Bulutları kapat (X-Ray), zaman makinesi, ISS nişangahı'),
                const SizedBox(height: 8),
                // ── Paketler ──
                _Plan(title: 'Ömür Boyu', sub: 'Tek seferlik ödeme, sonsuza dek Pro', price: l.life, old: l.lifeOld, badge: 'En avantajlı', selected: _life, onTap: () => setState(() => _life = true)),
                const SizedBox(height: 10),
                _Plan(title: '5 Aylık', sub: '150 gün Pro, otomatik yenilenmez', price: l.m5, old: l.m5Old, selected: !_life, onTap: () => setState(() => _life = false)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: st.isPro && st.lifetime ? null : () { Sfx.tap(); BillingService.I.buy(lifetime: _life, discount: d.active); },
                  child: Text(st.lifetime ? 'Zaten Ömür Boyu Pro’sun' : 'Devam et · ${_life ? l.life : l.m5}'),
                ),
                if (BillingService.I.message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(BillingService.I.message!, textAlign: TextAlign.center, style: T.small)),
                TextButton(onPressed: BillingService.I.restore, child: const Text('Satın alımları geri yükle')),
                const SizedBox(height: 8),
                _DiscountCard(d: d, code: ProService.I.myInviteCode),
              ]);
            },
          ),
        ]),
      );
}

class _Perk extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub;
  const _Perk(this.icon, this.color, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(icon, color: color, size: 42), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.body.copyWith(fontWeight: FontWeight.w700)), Text(sub, style: T.small),
          ])),
        ]),
      );
}

class _Plan extends StatelessWidget {
  final String title, sub, price; final String? old, badge; final bool selected; final VoidCallback onTap;
  const _Plan({required this.title, required this.sub, required this.price, this.old, this.badge, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? kAccent : kLine, width: selected ? 2.2 : 1.5),
            boxShadow: selected ? [BoxShadow(color: kAccent.withValues(alpha: .15), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -6)] : null,
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? kAccent : kInkFaint),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: T.h2),
                if (badge != null) ...[const SizedBox(width: 8), Pill(badge!, color: kPro)],
              ]),
              Text(sub, style: T.small.copyWith(fontSize: 12.5)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (old != null) Text(old!, style: T.small.copyWith(decoration: TextDecoration.lineThrough)),
              Text(price, style: T.num.copyWith(fontSize: 19)),
            ]),
          ]),
        ),
      );
}

class _DiscountCard extends StatelessWidget {
  final DiscountState d; final String? code;
  const _DiscountCard({required this.d, required this.code});
  @override
  Widget build(BuildContext context) => Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.local_offer_rounded, color: kGood, size: 40), const SizedBox(width: 12),
          const Expanded(child: Text('Arkadaş indirimi', style: T.h2)),
          if (d.active) const Pill('Aktif', color: kGood) else const Pill('Kilitli', color: kInkSoft, icon: Icons.lock_outline),
        ]),
        const SizedBox(height: 14),
        _Progress('7 gün kullanım', '${d.usedDays.clamp(0, 7)}/7 gün', d.usedDays.clamp(0, 7) / 7, kAccent),
        const SizedBox(height: 10),
        _Progress('Arkadaş daveti onayı', d.friendOk ? 'Onaylandı' : 'Henüz yok', d.friendOk ? 1 : 0, kPro),
        if (d.active) ...[
          const SizedBox(height: 10),
          _Progress('İndirimin kalan süresi', '${d.remaining.inDays} gün ${d.remaining.inHours % 24} sa', d.remaining.inMinutes / (7 * 24 * 60), kGood),
        ],
        const SizedBox(height: 12),
        const Text('İki şart tamamlanınca indirim 7 gün açılır. Paylaşmak yetmez; arkadaşın uygulamayı indirip kodunu onaylamalı. Süre dolarsa yeni ve farklı bir arkadaşla yeniden açılır.', style: T.small),
        const SizedBox(height: 14),
        if (code != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(color: kIce, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
            child: Row(children: [
              Expanded(child: SelectableText(code!, style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2, color: kInk))),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Share.share('SkyNav’ı dene kanki, kodumla ikimiz de 1 hafta Pro kazanırız: $code'),
                icon: const Icon(Icons.ios_share_rounded, size: 18), label: const Text('Paylaş'),
              ),
            ]),
          )
        else
          const Text('Davet kodu almak için Ayarlar’dan Google ile giriş yap.', style: T.small),
      ]));
}

class _Progress extends StatelessWidget {
  final String label, value; final double v; final Color color;
  const _Progress(this.label, this.value, this.v, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: T.small.copyWith(color: kInk, fontWeight: FontWeight.w600))), Text(value, style: T.small.copyWith(fontWeight: FontWeight.w700, color: color))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: v.clamp(0.0, 1.0), minHeight: 7, color: color, backgroundColor: color.withValues(alpha: .12))),
      ]);
}
