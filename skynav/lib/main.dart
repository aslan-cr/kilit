import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'services/shared_state.dart';
import 'l10n/l10n.dart';
import 'pro/billing_service.dart';
import 'pro/pro_service.dart';
import 'services/auth_service.dart';
import 'services/cloud.dart';
import 'services/notify_service.dart';
import 'services/icon_service.dart';
import 'services/store.dart';
import 'services/voice_service.dart';
import 'services/weather_repository.dart';
import 'background/bg_tasks.dart';
import 'widgets/widget_service.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

void _saveError(String text) {
  SharedState.get().then((p) {
    p.setString('sn_last_error', text.length > 4000 ? text.substring(0, 4000) : text);
    p.setInt('sn_last_error_t', DateTime.now().millisecondsSinceEpoch);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Store.init();
  await SharedState.init();
  // Tanılama: yakalanmayan Dart hatalarını kaydet (Ayarlar > Tanılama'da görünür).
  FlutterError.onError = (d) { FlutterError.presentError(d); _saveError('${d.exception}\n${d.stack}'); };
  PlatformDispatcher.instance.onError = (e, st) { _saveError('$e\n$st'); return true; };
  // Eski sürümden kalan konum/sapma değerlerini arka plan görevi için aktar.
  final sp = await SharedState.get();
  final lp = Store.prefs.get('last_place') as String?;
  if (lp != null) await sp.setString('sn_last_place', lp);
  await sp.setDouble('sn_bias', (Store.prefs.get('bias_c', defaultValue: 0.0) as num).toDouble());
  await Cloud.init();
  await Notify.init();
  runApp(const SkyNavApp());
}

class SkyNavApp extends StatefulWidget {
  const SkyNavApp({super.key});
  @override
  State<SkyNavApp> createState() => _SkyNavAppState();
}

class _SkyNavAppState extends State<SkyNavApp> with WidgetsBindingObserver {
  Timer? _pulse;
  bool _ready = Store.onboardingDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IconService.markForeground(true);
    if (_ready) _boot();
  }

  /// İkon değişikliği uygulama açıkken yapılmaz (Android, özellikle Samsung, uygulamayı kapatıyor);
  /// uygulama birkaç dakika kullanılmayınca arka planda uygulanır.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      IconService.markForeground(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // İkon burada DEĞİŞTİRİLMEZ (izin/giriş penceresi açılınca da bu durum oluşur, Samsung uygulamayı kapatır).
      // Sadece son kullanım anını kaydet ve birkaç dakika sonrası için arka plan işi planla.
      IconService.markForeground(false);
      Background.scheduleIconApply();
    }
  }

  Future<void> _boot() async {
    L10n.setFromLocale(PlatformDispatcher.instance.locale.languageCode);
    Voice.init(L10n.ttsTag);
    BillingService.I.init();
    await ProService.I.markUsageAndRefresh();
    if (AuthService.user != null) { await ProService.I.onSignedIn(); }
    ProService.I.addListener(_toast);
    // 1 sn'lik nabız: doğrulama sessiz çalışır, ekran yalnızca onaylı veriyle güncellenir.
    WeatherController.I.refresh(force: true);
    _pulse = Timer.periodic(const Duration(seconds: 1), (_) { WeatherController.I.pulse(); });
    WeatherController.I.addListener(() {
      final w = WeatherController.I;
      IconService.maybeUpdate(w.analysis, w.confirmed);
      if (w.confirmed != null && w.analysis != null) WidgetService.updateWeather(w.confirmed!, w.analysis!);
    });
    Background.start().catchError((_) {});
    if (WidgetService.speedEnabled) WidgetService.startSpeedTracking();
  }

  void _toast() {
    final m = ProService.I.lastMessage;
    if (m != null) { ProService.I.lastMessage = null; Notify.show('SkyNav', m); }
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _pulse?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SkyNav',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: _ready ? const AppShell() : Onboarding(onDone: () async { await Store.put('onboarding_done', true); setState(() => _ready = true); _boot(); }),
      );
}
