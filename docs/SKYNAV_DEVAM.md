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
