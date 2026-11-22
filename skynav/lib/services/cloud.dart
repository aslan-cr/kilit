import 'package:firebase_core/firebase_core.dart';

/// Firebase yapılandırması (google-services.json) yoksa uygulama bulutsuz çalışmaya devam eder.
class Cloud {
  static bool ready = false;
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      ready = true;
    } catch (_) {
      ready = false;
    }
  }
}
