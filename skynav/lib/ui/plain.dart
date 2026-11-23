import 'package:flutter/widgets.dart';
import '../services/store.dart';

/// Anlaşılır dil: açıkken bilimsel terimler ve birimler herkesin anlayacağı gündelik dile çevrilir
/// (hPa → hava basıncı, CAPE → gök gürültüsü riski, çiy noktası → buğu sıcaklığı, m/s → km/s ...).
/// Ayarlar > "Anlaşılır dil". Değer Hive'da (yalnızca ana uygulama okur/yazar).
class Plain {
  static bool on = false;

  static void load() {
    try { on = Store.prefs.get('plain_lang', defaultValue: false) == true; } catch (_) {}
  }

  static Future<void> set(bool v) async {
    on = v;
    try { await Store.put('plain_lang', v); } catch (_) {}
    _rebuildAll();
  }

  /// Bilimsel ya da gündelik metin.
  static String t(String sci, String easy) => on ? easy : sci;

  /// Rüzgâr hızı: bilimsel modda m/s, anlaşılır modda km/s (saatte kilometre).
  static String wind(double ms, {int digits = 1}) => on ? '${(ms * 3.6).round()} km/s' : '${ms.toStringAsFixed(digits)} m/s';

  /// Rüzgâr yönü: K/KD... yerine "kuzeyden", "kuzeydoğudan"...
  /// [noun]: dar yerler için ek almadan ("kuzeybatı").
  static String windFrom(double deg, String short, {bool noun = false}) {
    if (!on || !deg.isFinite) return short;
    const names = ['kuzeyden', 'kuzeydoğudan', 'doğudan', 'güneydoğudan', 'güneyden', 'güneybatıdan', 'batıdan', 'kuzeybatıdan'];
    const nouns = ['kuzey', 'kuzeydoğu', 'doğu', 'güneydoğu', 'güney', 'güneybatı', 'batı', 'kuzeybatı'];
    if (noun) return nouns[((((deg % 360) + 360) % 360 + 22.5) / 45).floor() % 8];
    final d = ((deg % 360) + 360) % 360;
    return names[((d + 22.5) / 45).floor() % 8];
  }

  /// Toz/duman (PM10, µg/m³) gündelik derece: AB ve DSÖ eşiklerine yakın.
  static String dust(double pm10) => pm10 < 20 ? 'Temiz' : pm10 < 50 ? 'Makul' : pm10 < 100 ? 'Kirli' : 'Çok kirli';

  /// Gök gürültüsü riski (CAPE, J/kg).
  static String stormRisk(double cape) => cape < 300 ? 'Yok' : cape < 1000 ? 'Düşük' : cape < 2500 ? 'Orta' : 'Yüksek';

  /// Basınç seviyesi (hPa) yerine yaklaşık yükseklik.
  static String level(int hpa, double? heightM) {
    if (!on) return '$hpa hPa';
    final h = (heightM != null && heightM.isFinite) ? heightM : const {1000: 100.0, 925: 800.0, 850: 1500.0, 700: 3000.0, 500: 5600.0, 300: 9200.0}[hpa] ?? 0;
    return h < 1000 ? '~${(h / 100).round() * 100} m' : '~${(h / 1000).toStringAsFixed(h < 3000 ? 1 : 0)} km';
  }

  /// Dil değişince açık tüm ekranlar yeniden çizilsin (yerinde kalırsın, gezinme bozulmaz).
  static void _rebuildAll() {
    void visit(Element e) { e.markNeedsBuild(); e.visitChildren(visit); }
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
  }
}
