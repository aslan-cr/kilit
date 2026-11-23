import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'pricing.dart';
import 'pro_service.dart';

/// Google Play Billing. İndirim, Play Console'da tanımlı ayrı ürün kimlikleriyle (…_disc) uygulanır;
/// uygulama fiyatı kendisi değiştiremez, mağaza gerçek tutarı gösterir.
class BillingService extends ChangeNotifier {
  static final BillingService I = BillingService._();
  BillingService._();

  static const id5m = 'skynav_pro_5m', idLife = 'skynav_pro_life';
  static const id5mDisc = 'skynav_pro_5m_disc', idLifeDisc = 'skynav_pro_life_disc';

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> products = {};
  bool storeAvailable = false;
  String? message;

  Future<void> init() async {
    storeAvailable = await _iap.isAvailable().catchError((_) => false);
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    if (!storeAvailable) { notifyListeners(); return; }
    final r = await _iap.queryProductDetails({id5m, idLife, id5mDisc, idLifeDisc});
    for (final p in r.productDetails) { products[p.id] = p; }
    notifyListeners();
  }

  /// (5 aylık, ömür boyu) için gösterilecek fiyat metni; mağaza yoksa PPP yedeği.
  ({String m5, String life, String? m5Old, String? lifeOld}) labels(bool discount) {
    final s5 = products[discount ? id5mDisc : id5m] ?? products[id5m];
    final sl = products[discount ? idLifeDisc : idLife] ?? products[idLife];
    if (s5 != null && sl != null) {
      return (m5: s5.price, life: sl.price, m5Old: discount ? products[id5m]?.price : null, lifeOld: discount ? products[idLife]?.price : null);
    }
    final p = Pricing.forCountry(Pricing.country());
    final m5 = discount ? p.fiveMonth * Pricing.discountFactor5m : p.fiveMonth;
    final life = discount ? p.lifetime * Pricing.discountFactorLife : p.lifetime;
    return (m5: p.fmt(m5), life: p.fmt(life), m5Old: discount ? p.fmt(p.fiveMonth) : null, lifeOld: discount ? p.fmt(p.lifetime) : null);
  }

  Future<void> buy({required bool lifetime, required bool discount}) async {
    final pid = lifetime ? (discount ? idLifeDisc : idLife) : (discount ? id5mDisc : id5m);
    final pd = products[pid] ?? products[lifetime ? idLife : id5m];
    if (pd == null) { message = 'Mağaza şu an hazır değil, biraz sonra tekrar dene kanki.'; notifyListeners(); return; }
    final param = PurchaseParam(productDetails: pd);
    if (lifetime) { await _iap.buyNonConsumable(purchaseParam: param); } else { await _iap.buyConsumable(purchaseParam: param); }
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        final life = p.productID == idLife || p.productID == idLifeDisc;
        await ProService.I.grantPurchase(lifetime: life);
        message = 'Teşekkürler kanki! SkyNav Pro açıldı.';
      } else if (p.status == PurchaseStatus.error) {
        message = 'Satın alma tamamlanamadı.';
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    notifyListeners();
  }
}
