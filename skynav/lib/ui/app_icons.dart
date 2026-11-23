import 'package:flutter/material.dart';
import 'theme.dart';

// Emoji yerine uygulamanın kendi simge dili: her şeye yuvarlak zeminli, renkli Material simgesi.

/// Yaşam Laboratuvarı hesaplayıcıları.
(IconData, Color) labIcon(String id) => switch (id) {
      'kardan_adam' => (Icons.ac_unit_rounded, kSnow),
      'kartopu_savas' => (Icons.sports_handball_rounded, kSnow),
      'okul_tatili' => (Icons.school_rounded, kAccent),
      'kar_erime_camur' => (Icons.water_drop_rounded, const Color(0xFF8D6E63)),
      'kiyafet_katman' => (Icons.checkroom_rounded, kPro),
      'kombi_tasarruf' => (Icons.local_fire_department_rounded, kHeat),
      'pencere_bugulanma' => (Icons.window_rounded, kSnow),
      'sokak_hayvani_su' => (Icons.pets_rounded, kWarn),
      'gokkusagi' => (Icons.looks_rounded, kPro),
      'gun_batimi' => (Icons.wb_twilight_rounded, kHeat),
      'camasir_kurutma' => (Icons.dry_cleaning_rounded, kAccent),
      'cay_sogutma' => (Icons.coffee_rounded, const Color(0xFF8D6E63)),
      'sac_statik' => (Icons.face_retouching_natural_rounded, kPro),
      'araba_yikama' => (Icons.local_car_wash_rounded, kAccent),
      'mangal_ruzgar' => (Icons.outdoor_grill_rounded, kHeat),
      'balik_basinc' => (Icons.phishing_rounded, kGood),
      'kamp_tulum' => (Icons.cabin_rounded, kGood),
      'deprem_bulut' => (Icons.thunderstorm_rounded, kInkSoft),
      'migren_eklem' => (Icons.healing_rounded, kDanger),
      'polen_riski' => (Icons.local_florist_rounded, kWarn),
      'uyku_konforu' => (Icons.bedtime_rounded, const Color(0xFF5B5BD6)),
      'kosu_nefes' => (Icons.directions_run_rounded, kGood),
      'gunes_yanigi' => (Icons.wb_sunny_rounded, kSun),
      'yol_kayganlik' => (Icons.severe_cold_rounded, kSnow),
      'ucurtma' => (Icons.paragliding_rounded, kAccent),
      'bahce_don' => (Icons.eco_rounded, kGood),
      'bisiklet_ruzgar' => (Icons.pedal_bike_rounded, kAccent),
      _ => (Icons.science_rounded, kGood),
    };

/// Rozetler.
(IconData, Color) badgeIcon(String id) => switch (id) {
      'first_lentil' => (Icons.grain_rounded, kLentil),
      'blizzard_nav' => (Icons.air_rounded, kBlizzard),
      'calm_driver' => (Icons.severe_cold_rounded, kSnow),
      'star_hunter' => (Icons.auto_awesome_rounded, kWarn),
      _ => (Icons.emoji_events_rounded, kWarn),
    };

/// Yol güvenliği kalemleri.
IconData roadIcon(String id) => switch (id) {
      'bridge_ice' => Icons.severe_cold_rounded,
      'slope_grip' => Icons.terrain_rounded,
      'sun_glare' => Icons.wb_sunny_rounded,
      'morning_scrape' => Icons.ac_unit_rounded,
      'washer_fluid' => Icons.local_car_wash_rounded,
      'visibility_light' => Icons.highlight_rounded,
      'fuel_wind' => Icons.local_gas_station_rounded,
      'wind_tunnel' => Icons.air_rounded,
      'mountain_view' => Icons.landscape_rounded,
      'echo' => Icons.campaign_rounded,
      _ => Icons.shield_outlined,
    };

/// Uyku mikseri kayıtları.
(IconData, Color) mixerIcon(String key) => switch (key) {
      'rain' => (Icons.water_drop_rounded, kAccent),
      'forest' => (Icons.forest_rounded, kGood),
      'waves' => (Icons.waves_rounded, kSnow),
      'campfire' => (Icons.local_fire_department_rounded, kHeat),
      'waterfall' => (Icons.water_rounded, const Color(0xFF00A3BF)),
      _ => (Icons.graphic_eq_rounded, kAccent),
    };

/// Baştaki emojiyi ayıklar ("🌧️ Gece yağmuru" → "Gece yağmuru").
String noEmoji(String s) => s.replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();
