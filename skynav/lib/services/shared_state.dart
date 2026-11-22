import 'package:shared_preferences/shared_preferences.dart';

/// Ana uygulama ile arka plan görevi arasında paylaşılan küçük durum.
/// Hive dosyası iki ayrı isolate'tan aynı anda yazılınca bozulup çökmeye yol açabileceği için
/// arka plan görevi Hive'a hiç dokunmaz; ihtiyaç duyduğu birkaç değeri buradan okur/yazar.
class SharedState {
  static SharedPreferences? _p;
  static Future<SharedPreferences> get() async {
    _p ??= await SharedPreferences.getInstance();
    return _p!;
  }

  /// Arka plan görevi başında: diğer isolate'ın yazdıklarını görmek için önbelleği tazele.
  static Future<SharedPreferences> fresh() async { final p = await get(); await p.reload(); return p; }

  /// Önceden yüklenmiş örnek (senkron okumalar için). init() çağrılmadıysa null.
  static SharedPreferences? get cached => _p;

  static Future<void> init() async { await get(); }
}
