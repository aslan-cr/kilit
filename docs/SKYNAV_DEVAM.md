# SkyNav — devir notu (yeni oturum buradan devam etsin)

Kullanıcı (RSA): Türkçe, kısa ve samimi konuş; teknik değil, tasarıma çok önem veriyor. Uzun açıklama istemiyor ("direk yap").
Çalışma dalı: `ccr-dd18a72f-iray62` (aslan-cr/kilit). Uygulama `skynav/` (Flutter 3.35.7).
**Kullanıcı izni:** her büyük iş bitince sürümü (pubspec versionCode) artırıp main'e al ve GitHub derlemesini izle
(`curl https://api.github.com/repos/aslan-cr/kilit/actions/workflows/build.yml/runs?branch=main&per_page=1`).
**10 saatlik serbest geliştirme izni**: yalnızca AKTİF çalışma süresi sayılır (kota beklemesi sayılmaz). ~2 sa kullanıldı.

## Ortam
- Flutter: `/opt/flutter` (yoksa storage.googleapis.com'dan flutter_linux_3.35.7-stable.tar.xz). `ln -sfn /opt/flutter /tmp/fl/flutter` (shots testi MaterialIcons yolunu oradan okur).
- Doğrulama: `flutter analyze lib test`, `flutter test test/{smoke,ui_smoke,l10n,engine_rules,scene_render}_test.dart`,
  ekran görüntüleri `flutter test test/shots` → `/tmp/shots/*.png` (ödeme ekranı yüzünden test "failed" görünür, normal).
- APK yerelde derlenemez; CI derler. Derleme tuzakları: Flutter 3.35.7, Kotlin 2.2.20, AGP 8.9.1, permission_handler ^12, workmanager ^0.8, firebase sürümleri sabit.

## Bu oturumda yapılanlar (hepsi dalda, 1.5.0+9 main'e alındı)
- Figma bento ana ekranı (lib/ui/bento.dart, hero_scene.dart), Gökyüzü/3D Harita/Uçak radarı/widget'lar yeni dilde.
- GPU shader'lar: `shaders/clouds.frag` (tek parça bulut), `mountains.frag` (ışıklı dağ), `moon.frag` (NASA LRO Ay haritası, CC BY 4.0, assets/moon).
  Dart: lib/ui/clouds.dart, scene_shaders.dart (MountainLayer, SceneLook, DecorScene), sky_bodies.dart (MoonRenderer, paintSun).
- Astronomi doğrulandı (yıldız, tutulma, takımyıldız), hava motoru düzeltmeleri, APK 67→40 MB.
- Emoji yerine simgeler (lib/ui/app_icons.dart), tüm ekranlar bento.
- **Doğa sesleri (son iş, CİHAZDA DOĞRULANMADI):** lib/services/audio_service.dart baştan yazıldı
  (ses odağı yok → kanallar birbirini susturmuyor; tek oynatıcı/kanal; yumuşak geçiş; uyku zamanlayıcısı; hazır karışımlar),
  Android ön plan servisi `MixerService.kt` (mediaPlayback, "Durdur" bildirimi) + MainActivity kanalı `mixerService`/`mixerStop`,
  kayıtlar −24 LUFS'a eşitlendi, tepeler sınırlandı, döngü geçişli. **İlk iş: main derlemesinin (Kotlin servis) geçtiğini kontrol et.**

## Sıradaki işler (görev listesi)
1. Ses: döngü sınırında hâlâ küçük sıçrama var (orman/kamp ateşi son→baş); MediaPlayer döngüsü yerine iki oynatıcıyla
   çapraz geçiş ya da dosya sonuna/başına birkaç ms fade düşün. Cihazdan geri bildirim al.
2. Ana sahnede rastgele yıldızlar yerine gerçek yıldız/gezegen konumları (astro_math + star_catalog), parlaklığa göre boy.
3. Gerçekçi yağış (kar derinlik bulanıklığı, yağmur sıçraması), fırtınada şimşek çakması/yıldırım, vadide bulut shader'ıyla sis.
4. Yeni özellik fikirleri: gün detay sayfası (7 günlükte dokununca), fotoğrafçı saatleri (altın/mavi saat), Ay doğuş/batış,
   basınç/rüzgâr grafikleri, hava uyarı bildirimleri, "Canlı pencere" (tam ekran sahne + havaya uygun doğa sesi).
5. Zamanlanmış "devam" görevi (trig_01FVr2RbhKYjAbAgfNm3iwx2) eski oturuma bağlı ve devre dışı bırakıldı;
   yeni oturumda gerekirse yeniden kur (create_trigger, 2 saatte bir, bu dosyayı okumasını söyle).

## 2. oturum (2026-11-23, 1.6.0+10)
- **Cihazda bozuk GPU çizimi düzeltildi** (1.5.0'da Ay mor, ana sahnede dağlar üstte renkli diken şeridi):
  tüm shader'lar artık yalnızca vec4 uniform kullanıyor (vec3 hizası bazı GPU'larda kayıyordu), hep dönüşümsüz
  ekran dışı görüntüye çiziliyor (lib/ui/gpu.dart), açılışta `shaders/probe.frag` ile koordinat ölçülüyor ve her
  program piksel okunarak doğrulanıyor; başarısızsa o program kapanır, eski kanvas çizimi devreye girer.
  Durum Ayarlar > Tanılama'da "GPU çizimi: ..." satırında. **Kullanıcıdan bu satırı iste.**
  Yeni uniform eklerken: yalnızca vec4, Dart'ta setFloat sırası birebir.
- Ses: döngü sıçraması giderildi (tool/make_loops.py; eski alimiter başa 5 ms sessizlik ekliyordu), mikser iki
  oynatıcıyla 3 sn çapraz geçiş yapıyor (cihazda doğrulanmadı).
- Ana sahne: gerçek yıldızlar (lib/astro/bsc5.dart, Yale BSC V≤5) + gezegenler (planetMagnitude), lib/ui/sky_stars.dart.
- Yağış: kar derinlik bulanıklığı, yağmur çizgi + sıçrama, fırtınada yıldırım (Lightning sınıfı), vadi sisi (ters CloudLayer).
- Ekran görüntüsü testi: altın/mavi saat boylamı otomatik; 06h yıldızlı gece, 06i fırtına (çakış anı), 06j sis.

## 1.7.0+11 (aynı oturum)
- lib/ui/detail_screens.dart: DayDetailScreen (7 günlükte güne dokun), PhotoHoursBlock (ana ekranda da), MoonTimesBlock +
  MoonDetailScreen (Ay bloğuna dokun), TrendScreen + SeriesChart (basınç/rüzgâr bloğuna dokun; son 48 sa + 24 sa),
  LiveWindow (sahneye dokun: tam ekran + havaya uygun CC0 kayıt; çıkınca mikserin önceki karışımı geri gelir, "son karışım" ezilmez).
- lib/astro/sky_times.dart: altın/mavi saat, Ay doğuş/batış, ana evreler (PyEphem ile ±1–2 dk, evreler ±15 dk; testli).
- lib/engine/alerts.dart: fırtına (WMO 95+), tipi, buzlanma, yoğun kar, rüzgâr fırtınası, mercimek, kar, sıcak; bg_tasks
  önem sırasıyla, her uyarı 6 saatte bir, tek çalıştırmada tek bildirim. Ayarlar > "Hava uyarıları" (SharedState sn_alerts_off).
- HourPoint'e uv ve gust eklendi (Open-Meteo hourly wind_gusts_10m).
- Ekran görüntüleri: 15_day, 16_moon, 17_trend, 18_live (en sonda; ses eklentisi testte yok).
- Sıradaki fikirler: cihaz geri bildirimi (GPU tanılama satırı, sesler), canlı pencere için sahne ufak animasyonları.

## 1.8.0+12
- Ayarlar > Görünüm > "Anlaşılır dil" (lib/ui/plain.dart, Hive 'plain_lang'): Plain.t(bilimsel, gündelik), Plain.wind (km/s),
  Plain.windFrom, Plain.dust, Plain.stormRisk, Plain.level. Açılıp kapanınca tüm ekranlar yerinde yenilenir.
  Yeni teknik metin eklerken Plain.t ile gündelik karşılığını da yaz. Ekran görüntüsü: 02d_plain_full, 17b_trend_plain.

## 1.9.0+13 — kullanıcı: "3.0'a kadar devam et", "her şey alt alta olmasın, yeni menüler"
- Ana ekran: sahne, spiker, (yağış varsa) 2 saatlik şimdi-tahmini, saatlik, 7 günlük, **Keşfet menüsü** (bento kutular),
  sonra Figma ölçüm blokları. Eskiden alttaki uzun liste artık sayfalarda: SkyMoonPage (Gök & Ay: bu gece gökte,
  gece gökyüzü, Ay saatleri, fotoğrafçı saatleri), TrendScreen, ProPage, RadarPage, ObservePage, ToolsPage (weather_screen.dart).
  YENİ ÖZELLİKLERİ ANA LİSTEYE ALT ALTA EKLEME: Keşfet'e kutu + kendi sayfası.
- lib/engine/nowcast.dart + NowPoint (minutely_15; değer önceki 15 dk toplamı → dilim başlangıcıyla saklanır), NowcastBlock.
- lib/astro/tonight.dart: bu gece görünen gezegenler (PyEphem ±10 dk/1°), TonightSkyBlock.
- lib/engine/compare.dart: dünle kıyas (spiker cümlesine eklenir).
- Canlı pencere: ivmeölçerle paralaks (HeroScene.tilt).
- Yol haritası görev listesinde (#9).

## 2.0.0+14
- Keşfet > Yerlerim (lib/ui/places_screen.dart, OpenMeteoService.fetchLite, PlaceNow): kayıtlı yerlerin anlık havası kartlarda.
- Keşfet > En iyi zaman (lib/engine/best_time.dart, lib/ui/best_time_screen.dart): 6 etkinlik, kışa uygun eşikler, engel nedeni.
- Keşfet > İklim (lib/services/climate_service.dart, lib/ui/climate_screen.dart): ERA5 30 yıl (archive-api.open-meteo.com),
  konum başına (0,1°) bir kez indirilir → Store.cache 'clim_v1_*'; normalden fark, hafta bandı, takvim günü rekorları.
  Sandbox'ta archive API kapalı: canlı indirme cihazda doğrulanmadı, hesap testli.

## 2.1.0+15
- Keşfet > Hava kalitesi (lib/services/air_service.dart, lib/ui/air_screen.dart): EAQI, PM2.5/PM10/O₃/NO₂ (DSÖ 2021), 3 gün.
- Saatlik detay: HourlyBlock.onHour → showHourSheet (detail_screens.dart).
- Sabah özeti: lib/engine/brief.dart + bg_tasks (07–10, günde bir; SharedState sn_brief_off / sn_brief_day).
- Canlı pencere paylaşma (share_plus SharePlus.instance.share + path_provider temp).

## 2.2.0+16
- İklim > Bu kış kar: ClimateNormals.snowCum (sezon 1 Eyl–31 May, 273 gün), SeasonSnow (historical-forecast-api). Önbellek clim_v2.
- Büyük yazı: main.dart builder textScaler 0,9–1,25; test/shots/large_text_test.dart (gerçek fontla, 360 genişlik; SCALE/W dart-define).
- flutter analyze: 0 sorun (SharePlus.instance.share'e geçildi). Böyle kalsın.

## 2.3.0+17
- KULLANICI HATASI: "Ağrı yazıyorum çıkmıyor" → lib/services/geocode_service.dart yeniden: Open-Meteo Geocoding (tr) + Photon (lang default),
  paralel, birleştir (2 km), düz harfle yeniden dene, GeocodeOffline. _PlaceSheet: yazarken arama (450 ms), mesajlar, add modu (Yerlerim).
  Test: test/geocode_test.dart (MockClient). Sandbox'ta iki host da kapalı → canlı doğrulama cihazda.
- Keşfet: _ExplorePager (2×2 sayfalar, yana kaydırma, noktalar).

## 2.4.0+18 — kullanıcı: "birkaç tane daha ana ekran şeyi ekle" (= ana ekran widget'ı)
- Yeni widget'lar: SkyNav Saatlik (4×2), SkyNav Ay (2×2), SkyNav Mini (2×2). Kotlin: ImageWidgets.kt (open class ImageWidget(key)
  + 3 alt sınıf, SkyWeatherWidget ile aynı kalıp), res/xml/sky_{hourly,moon,mini}_widget_info.xml, widget_strings.xml, manifest receiver.
  Dart: widget_faces.dart (HourlyWidgetFace, MoonWidgetFace, MiniWidgetFace), WidgetService._renderExtras (yalnızca eklenmiş
  widget'lar; HomeWidget.getInstalledWidgets). KOTLIN CI'DA DERLENİYOR — kırılırsa ImageWidgets.kt'ye bak.
- Gökyüzü takvimi: lib/astro/sky_calendar.dart (meteor tepe gecesi koşulu: radyant yüksekliği × Ay ışığı), SkyCalendarBlock (Gök & Ay).
- Yağış geliyor bildirimi: bg_tasks (Nowcast, 30 dk içinde, 3 saatte bir; SharedState sn_rainsoon_off).

## 2.5.0+19
- Yerlerim > Karşılaştır (lib/ui/compare_screen.dart; PlaceNow.days, fetchLite forecast_days=7; Türkçe ayrılma eki ablative()).
- Keşfet > Kayak merkezleri (lib/services/ski_service.dart: 8 merkez, Open-Meteo çoklu konum + elevation; lib/ui/ski_screen.dart).
  Model tahmini olduğu ekranda yazıyor; merkez koordinat/yükseklikleri yaklaşık.

## 2.6.0+20
- Widget: SkyNav Kayak (SkySkiWidget, ski_img; en yakın merkez, SkiService) ve SkyNav Hava Kalitesi (SkyAirWidget, air_img).
- Ekran okuyucu: çizimli bloklarda Semantics(container: true, label); test large_text_test.dart içinde.

