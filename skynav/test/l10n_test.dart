import 'package:flutter_test/flutter_test.dart';
import 'package:skynav/l10n/l10n.dart';
import 'package:skynav/l10n/strings_data.dart';

const _langs = [
  'tr', 'en', 'de', 'fr', 'es', 'it', 'pt', 'ru', 'ar', 'hi', 'id', 'ja', 'ko', 'zh',
  'nl', 'pl', 'uk', 'fa', 'vi', 'th', 'sv', 'el', 'cs', 'ro', 'hu', 'he', 'az',
];

const _keys = [
  'nav_weather', 'nav_map3d', 'nav_planes', 'nav_road', 'nav_sky', 'app_name_tagline',
  'offline_note', 'loc_denied', 'notif_denied', 'cam_denied', 'mic_denied',
  'accept_continue', 'invited', 'self_discovered', 'pro', 'free', 'buy', 'restore',
  'speed_kmh', 'start_route', 'stop_route', 'search_places', 'search_hint', 'add_stop',
  'route_off', 'slip_alert', 'snow', 'rain', 'sleet', 'lentil_snow', 'blizzard', 'fog',
  'clear_sky', 'cloudy', 'stars_hidden', 'x_ray_sky', 'time_machine', 'iss_alert',
  'aim_hint', 'red_mode', 'hide_weather', 'show_weather', 'map3d_title', 'planes_title',
  'free_badge', 'settings', 'language', 'widget_weather_title', 'widget_speed_title',
  'speed_unit_mph',
];

void main() {
  test('her dilde her anahtar dolu', () {
    for (final lang in _langs) {
      final m = kStrings[lang];
      expect(m, isNotNull, reason: 'dil eksik: $lang');
      for (final key in _keys) {
        expect(m![key], isNotNull, reason: '$lang / $key yok');
        expect(m[key]!.trim(), isNotEmpty, reason: '$lang / $key boş');
      }
    }
  });

  test('dil listesi tam ve fazla dil yok', () {
    expect(kStrings.keys.toSet(), _langs.toSet());
    expect(_langs.length, greaterThanOrEqualTo(26));
  });

  test('her dilde anahtar seti aynı', () {
    for (final lang in _langs) {
      expect(kStrings[lang]!.keys.toSet(), _keys.toSet(), reason: lang);
    }
  });

  test('ttsTag her desteklenen dil için doğru', () {
    const expected = {
      'tr': 'tr-TR', 'en': 'en-US', 'de': 'de-DE', 'fr': 'fr-FR', 'es': 'es-ES',
      'it': 'it-IT', 'pt': 'pt-BR', 'ru': 'ru-RU', 'ar': 'ar-SA', 'hi': 'hi-IN',
      'id': 'id-ID', 'ja': 'ja-JP', 'ko': 'ko-KR', 'zh': 'zh-CN', 'nl': 'nl-NL',
      'pl': 'pl-PL', 'uk': 'uk-UA', 'fa': 'fa-IR', 'vi': 'vi-VN', 'th': 'th-TH',
      'sv': 'sv-SE', 'el': 'el-GR', 'cs': 'cs-CZ', 'ro': 'ro-RO', 'hu': 'hu-HU',
      'he': 'he-IL', 'az': 'az-AZ',
    };
    for (final e in expected.entries) {
      L10n.setFromLocale(e.key);
      expect(L10n.lang, e.key);
      expect(L10n.ttsTag, e.value);
    }
  });

  test('desteklenmeyen dil İngilizceye düşer', () {
    L10n.setFromLocale('xx');
    expect(L10n.lang, 'en');
    expect(L10n.ttsTag, 'en-US');
    expect(L10n.t('settings'), kStrings['en']!['settings']);
  });

  test('t(): eksik anahtar en, sonra anahtarın kendisi', () {
    L10n.lang = 'tr';
    expect(L10n.t('settings'), 'Ayarlar');
    expect(L10n.t('bilinmeyen_anahtar'), 'bilinmeyen_anahtar');
    L10n.lang = 'xx-yok';
    expect(L10n.t('settings'), 'Settings');
    L10n.lang = 'tr';
  });
}
