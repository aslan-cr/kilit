import 'strings_data.dart';

/// Basit çeviri yardımcısı. Dil, cihaz dili kodu ile [setFromLocale] üzerinden seçilir.
/// Desteklenmeyen dil İngilizceye (en) düşer.
class L10n {
  L10n._();

  /// Aktif dil kodu (ör. 'tr').
  static String lang = 'tr';

  static const Map<String, String> _ttsTags = {
    'tr': 'tr-TR',
    'en': 'en-US',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'it': 'it-IT',
    'pt': 'pt-BR',
    'ru': 'ru-RU',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'id': 'id-ID',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'zh': 'zh-CN',
    'nl': 'nl-NL',
    'pl': 'pl-PL',
    'uk': 'uk-UA',
    'fa': 'fa-IR',
    'vi': 'vi-VN',
    'th': 'th-TH',
    'sv': 'sv-SE',
    'el': 'el-GR',
    'cs': 'cs-CZ',
    'ro': 'ro-RO',
    'hu': 'hu-HU',
    'he': 'he-IL',
    'az': 'az-AZ',
  };

  // Eski/alternatif dil kodları için eşleme (Android/Java kodları).
  static const Map<String, String> _aliases = {
    'iw': 'he',
    'in': 'id',
    'fil': 'en',
  };

  /// Cihaz dili kodunu ([PlatformDispatcher] üzerinden gelen languageCode) destekli dile eşler.
  static void setFromLocale(String languageCode) {
    var code = languageCode.trim().toLowerCase();
    code = _aliases[code] ?? code;
    lang = _ttsTags.containsKey(code) ? code : 'en';
  }

  /// [key] için aktif dildeki metni döndürür. Yoksa önce en, o da yoksa anahtarın kendisi.
  static String t(String key) {
    return kStrings[lang]?[key] ?? kStrings['en']?[key] ?? key;
  }

  /// Aktif dile ait TTS dil etiketi (ör. 'tr-TR').
  static String get ttsTag => _ttsTags[lang] ?? 'en-US';
}
