import 'dart:ui';

/// Çevrimdışı yedek fiyat: ülke koduna / alım gücüne (PPP) göre. Mağaza fiyatı gelirse o kullanılır.
class Price {
  final String symbol; final double fiveMonth, lifetime; final String code;
  const Price(this.code, this.symbol, this.fiveMonth, this.lifetime);
  String fmt(double v) {
    final s = v == v.roundToDouble() && v > 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    final tr = code == 'TRY' || code == 'EUR';
    return tr ? '${s.replaceAll('.', ',')} $symbol' : '$symbol$s';
  }
}

class Pricing {
  static const _eur = Price('EUR', '€', 1.99, 44.99);
  static const _table = <String, Price>{
    'TR': Price('TRY', '₺', 10, 999.99),
    'US': Price('USD', r'$', 1.99, 49.99),
    'GB': Price('GBP', '£', 1.79, 39.99),
    'DE': _eur, 'FR': _eur, 'IT': _eur, 'ES': _eur, 'NL': _eur, 'AT': _eur,
    'IN': Price('INR', '₹', 49, 1299),
    'BR': Price('BRL', r'R$', 7.9, 149.9),
    'RU': Price('RUB', '₽', 99, 2490),
    'JP': Price('JPY', '¥', 300, 6800),
    'MX': Price('MXN', r'MX$', 29, 799),
    'ID': Price('IDR', 'Rp', 15000, 449000),
    'EG': Price('EGP', 'E£', 45, 999),
    'SA': Price('SAR', 'SAR ', 7.5, 179),
  };
  static const discountFactor5m = 0.5;          // 10 -> 5
  static const discountFactorLife = 649.99 / 999.99; // ~%35

  static Price forCountry(String? cc) => _table[(cc ?? '').toUpperCase()] ?? _table['US']!;
  static String country() => PlatformDispatcher.instance.locale.countryCode ?? 'US';
}
