import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Store.init();
  await Cloud.init();
  await Notify.init();
  runApp(const SkyNavApp());
}

class SkyNavApp extends StatefulWidget {
  const SkyNavApp({super.key});
  @override
  State<SkyNavApp> createState() => _SkyNavAppState();
}

class _SkyNavAppState extends State<SkyNavApp> {
  Timer? _pulse;
  bool _ready = Store.onboardingDone;

  @override
  void initState() {
    super.initState();
    if (_ready) _boot();
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
  void dispose() { _pulse?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SkyNav',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: _ready ? const AppShell() : Onboarding(onDone: () async { await Store.put('onboarding_done', true); setState(() => _ready = true); _boot(); }),
      );
}
