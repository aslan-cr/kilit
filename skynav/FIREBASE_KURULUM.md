# SkyNav bulut kurulumu (Firebase)

1. Firebase'de proje aç, Android uygulaması ekle: paket adı `com.skynav.skynav`, debug/release SHA-1'leri ekle.
2. Authentication > Google'ı etkinleştir. İndirdiğin `google-services.json` dosyasını `android/app/` içine koy (depoya ekleme; `.gitignore`'da).
3. Firestore'u oluştur, `firestore.rules` dosyasını yayınla.
4. Konsolda belgeleri oluştur:
   - `app_meta/config`: `{ is_published_on_play_store: false, developer_emails: ["<senin gmail>"] }` (e-postan kaynak koda gömülmez).
     Google Play'de yayınlayınca `is_published_on_play_store: true` yap.
   - `app_meta/launch_rewards`: `{ count: 0, uids: [] }`
5. Play Console > Uygulama içi ürünler: `skynav_pro_5m` (10 TL), `skynav_pro_life` (999,99 TL), indirim ürünleri `skynav_pro_5m_disc` (5 TL), `skynav_pro_life_disc` (649,99 TL). Diğer ülkeler için fiyat şablonunu Play'de ülke bazlı gir.

## Ekosistem (4 uygulama = 30 gün Pro)
Her uygulama açılışta aynı Gmail ile giriş yapıp `users/{uid}/apps/{appId}` belgesine `firstSeen` (bir kez) ve `lastActive` (her açılış) yazar. SkyNav bunu `ProService.registerThisApp(appId: ...)` ile yapar. Diğer uygulamalara entegrasyon bu depoda yapılmadı (yalnızca `kilit` depo kapsamı).

## Güvenlik notu
Hibeler istemci tarafında hesaplanır; kurallar kötüye kullanımı zorlaştırır ama değiştirilmiş bir istemciyi tamamen engelleyemez. Para değeri taşıyan ödüller için Cloud Functions'a taşımak önerilir.
