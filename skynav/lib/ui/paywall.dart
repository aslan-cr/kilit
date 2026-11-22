import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../pro/billing_service.dart';
import '../pro/pro_service.dart';
import '../services/audio_service.dart';
import 'theme.dart';

class Paywall extends StatelessWidget {
  const Paywall({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('SkyNav Pro')),
        body: ListenableBuilder(
          listenable: Listenable.merge([ProService.I, BillingService.I]),
          builder: (_, __) {
            final d = ProService.I.discount;
            final l = BillingService.I.labels(d.active);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Zorunlu değil kanki 🙂', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Reklam yok, temel hava/yol/gökyüzü hep ücretsiz. Pro, Google Play geliştirici masrafını çıkarmaya destek olur ve ileri modülleri açar:', style: TextStyle(color: kInkSoft)),
                const SizedBox(height: 8),
                const Text('• Hava Pro: 50+ senaryo ensemble, dağ radarı, sis radarı, model kıyaslaması, Turbo mod\n• Yol Pro: akıllı ETA, G-kuvveti/kayma sensörü, hız widget\'ı\n• Astronomi Pro: X-Ray gökyüzü, zaman makinesi, uydu nişangahı'),
                const SizedBox(height: 6),
                Text('Durumun: ${ProService.I.state.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ])),
              const SizedBox(height: 12),
              _pack(context, '5 Aylık SkyNav Pro', l.m5, l.m5Old, false, d.active),
              const SizedBox(height: 10),
              _pack(context, 'Ömür Boyu SkyNav Pro (tek seferlik)', l.life, l.lifeOld, true, d.active),
              const SizedBox(height: 12),
              _discountCard(context, d),
              if (BillingService.I.message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(BillingService.I.message!)),
              TextButton(onPressed: BillingService.I.restore, child: const Text('Satın alımları geri yükle')),
            ]);
          },
        ),
      );

  Widget _pack(BuildContext c, String t, String price, String? old, bool life, bool disc) => Glass(
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (old != null) Text(old, style: const TextStyle(decoration: TextDecoration.lineThrough, color: kInkSoft)),
            Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kAccent)),
          ])),
          FilledButton(onPressed: () { Sfx.tap(); BillingService.I.buy(lifetime: life, discount: disc); }, child: const Text('Al')),
        ]),
      );

  Widget _discountCard(BuildContext context, DiscountState d) {
    final code = ProService.I.myInviteCode;
    return Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🏷️ Arkadaş indirimi (7 gün geçerli)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 8),
      _row('7 Gün Kullanım', d.usageOk, '${d.usedDays.clamp(0, 7)}/7 gün'),
      _row('Arkadaş Daveti Onayı', d.friendOk, d.friendOk ? 'Arkadaşın kodu onayladı' : 'Henüz yok'),
      if (d.active) _row('İndirimin Kalan Süresi', true, '${d.remaining.inDays}g ${d.remaining.inHours % 24}s kaldı')
      else const Padding(padding: EdgeInsets.only(top: 6), child: Text('İki şart da tamamlanınca indirim 7 gün açılır. Paylaşmak yetmez: arkadaşın uygulamayı indirip kodu onaylaması gerekir. Süre dolarsa yeni ve farklı bir arkadaşla tekrar açılır.', style: TextStyle(fontSize: 12, color: kInkSoft))),
      const SizedBox(height: 8),
      if (code != null) Row(children: [
        Expanded(child: SelectableText('Kodun: $code', style: const TextStyle(fontWeight: FontWeight.w800))),
        OutlinedButton(onPressed: () => Share.share('SkyNav\'ı dene kanki, kodumla ikimiz de 1 hafta Pro kazanırız: $code'), child: const Text('Paylaş')),
      ]) else const Text('Kod almak için Google ile giriş yap.', style: TextStyle(fontSize: 12, color: kInkSoft)),
    ]));
  }

  Widget _row(String t, bool ok, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Text(ok ? '✅' : '⬜'), const SizedBox(width: 8), Expanded(child: Text(t)), Text(v, style: const TextStyle(color: kInkSoft, fontSize: 13))]),
      );
}
