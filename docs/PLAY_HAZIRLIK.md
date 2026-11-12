# Google Play hazırlık listesi (Aile Kilidi)

Bu belge, uygulamayı Google Play'e yüklemeden önce yapılması gerekenleri toplar. Kod tarafında yapılanlar ve elle yapılacaklar ayrılmıştır. Play'e yayınlamak ayrı bir süreçtir; bu depo APK dağıtımı için hazırdır.

## Kodda yapıldı
- Sabit "Bera-Meva" kaldırıldı; 1-4 çocuk, ad ve yaş kurulumda girilir. Eski kurulumlar otomatik taşınır.
- İlk açılışta kurulum sihirbazı: hoş geldin ve gizlilik özeti, ebeveyn şifresi, çocuklar, izinler (her birinin açıklamasıyla), önerilen süre ve ödev saati.
- İzin açıklamaları: "Diğer uygulamaların üzerinde göster" ve "Kullanım erişimi" ayarına gitmeden önce uygulama içinde ne için kullanıldığını anlatan onay penceresi çıkar.
- Yaşa göre uyarlama: 5-8 yaş büyük, renkli ekran ve klavyesiz hayvan şifresi; 9-12 standart; 13-15 sade ve daha az çocuksu. Önerilen günlük süreler: 60 / 90 / 120 dk (ebeveyn değiştirebilir).
- Uygulama internet izni istemez, reklam ve üçüncü taraf SDK içermez, konum ve reklam kimliği kullanmaz.
- Gizlilik politikası: `PRIVACY.md`.

## Doğrulanan Play kuralları (Google Play Console Yardım, kasım 2026'da okundu)
- Hedef API: 31 Ağustos 2026'dan itibaren yeni uygulamalar ve güncellemeler **Android 16 (API 36) veya üstünü hedeflemeli.** (1 Kasım 2026'ya kadar uzatma talep edilebiliyordu; bu tarih geçti.)
- Families politikası: Play Console'da hedef yaş grubu seçilir; Google seçimi görsel ve metinlere bakarak değiştirebilir. Gizlilik politikası zorunlu. Yalnızca çocuklara yönelik uygulamalar reklam kimliği, SIM/IMEI/MAC gibi tanımlayıcıları göndermemeli ve konum izni istememeli. Uygulama bunların hiçbirini kullanmıyor.

Kaynaklar:
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://support.google.com/googleplay/android-developer/answer/9893335

## Yayından önce yapılacaklar

### 1. Hedef API'yi 36'ya çıkar (zorunlu, henüz yapılmadı)
Şu an `compileSdk` ve `targetSdk` 34, Android Gradle Plugin 8.5.2. API 36 için şunlar gerekir ve gerçek cihazda denenmeden yapılmamalıdır:
- Android Gradle Plugin'i API 36'yı destekleyen sürüme yükselt (8.9 ve üstü; sürümü kontrol et) ve GitHub derlemesindeki Gradle sürümünü (şu an 8.7) uyumlu hale getir.
- Android 15 ve sonrasında kenardan kenara (edge-to-edge) çizim zorunlu: `MainActivity` ve `LockActivity` içeriği durum ve gezinme çubuklarının altında kalabilir; pencere kenar boşlukları (insets) eklenmeli.
- Ön plan servisi, "uygulamaların üzerinde göster" ve arka plandan etkinlik başlatma kuralları yeni sürümlerde sıkılaştı; kilit ekranının arka plandan açılması (`GuardService`) Android 14-16 tabletlerde denenmeli.
- Kedi bölümündeki ek pencereler (AudioTrack, ACTION_OUTSIDE ile dokunma algılama) yeni sürümlerde denenmeli.

### 2. Play Console'da elle yapılacaklar
- Geliştirici hesabı, uygulama imzası (Play App Signing) ve sürüm paketi: Play, `.aab` ister; şu an yalnızca debug `.apk` üretiliyor. Gradle'a `bundleRelease` ve yükleme anahtarı eklenmeli. Mevcut `app/debug.keystore` herkese açık depoda duruyor; Play için ayrı, gizli bir anahtar kullanılmalı.
- Gizlilik politikasının herkese açık bir adreste yayınlanması (örn. GitHub Pages) ve adresin Play Console'a girilmesi.
- Hedef kitle ve içerik: uygulamayı ebeveynler kurar, kullanıcıları 5-15 yaş çocuklardır. Hangi yaş gruplarının işaretleneceği ve Families programına uygunluk Play Console'daki sorularla belirlenir.
- Veri güvenliği formu: uygulama veri toplamaz ve paylaşmaz (internet izni yok). Ad, yaş ve şifre özetleri yalnızca cihazda tutulur.
- Hassas izin formları: "Diğer uygulamaların üzerinde göster" (SYSTEM_ALERT_WINDOW), "Kullanım erişimi" (PACKAGE_USAGE_STATS), özel kullanım ön plan servisi (FOREGROUND_SERVICE_SPECIAL_USE). Play bu izinler için ek açıklama veya form isteyebilir; bu istekler bu belgeyi yazarken Google sayfalarından doğrulanmadı, Play Console'da çıkanlara göre doldurulmalı.
- Paket görünürlüğü: manifestte `com.whatsapp` ve `com.whatsapp.w4b` için `queries` var (Arama/WhatsApp kısayolu). Play'de bunun gerekçesi sorulabilir.
- Mağaza listesi: ad, açıklama, ekran görüntüleri, simge. Şu an simge basit bir kilit çizimi.
- İç ve kapalı test: yeni kişisel geliştirici hesaplarında kapalı test şartı olabilir; Play Console'da güncel koşula bakın.

### 3. Ürün kararları
- Dil yalnızca Türkçe. Başka dil için metinler `strings.xml`'e taşınmalı (şu an kodda yazılı).
- Ad "Aile Kilidi" olarak ayarlandı; paket adı `com.beranmeva.kilit` kaldı (eski kurulumlar bozulmadan güncellensin diye). Play'e yeni uygulama olarak yüklenecekse paket adı yayından önce seçilmeli, sonradan değişmez.
