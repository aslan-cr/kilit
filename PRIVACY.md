# Aile Kilidi — Gizlilik Politikası

Son güncelleme: 12 Kasım 2026

Aile Kilidi, telefon ya da tableti paylaşan 5-15 yaş arası çocuklar için sıra ve kullanım süresi düzeni kuran bir ebeveyn aracıdır. Bu metin uygulamanın hangi bilgilere eriştiğini ve bunları nasıl kullandığını açıklar.

## Kısaca
- Uygulama **internete bağlanmaz.** Manifestinde internet izni yoktur.
- Hiçbir bilgi cihazdan dışarı gönderilmez, sunucuya ya da üçüncü kişilere aktarılmaz.
- Reklam, reklam kimliği, analiz ya da takip aracı (SDK) yoktur.
- Konum, kişi listesi, kamera, mikrofon ya da dosyalara erişilmez.

## Cihazda saklanan bilgiler
Aşağıdaki bilgiler yalnızca bu cihazın uygulama depolamasında tutulur. Uygulama kaldırılınca silinir.
- **Çocukların adı ve yaşı:** ebeveynin kurulumda yazdığı ad ve yaş. Ekran dilini ve önerilen süreyi seçmek için kullanılır.
- **Şifreler:** ebeveyn ve çocuk şifreleri düz metin olarak saklanmaz. Rastgele tuzla PBKDF2 ile özetlenir. Küçük çocuklar için "hayvan seçme" şifresi de aynı biçimde özetlenir.
- **Süre ve sıra bilgisi:** kimin ne kadar süresinin kaldığı, sıranın kimde olduğu, ödev saatleri ve sayaç ayarları.

## Android izinleri ve ne için kullanıldıkları
- **Diğer uygulamaların üzerinde göster:** kilit ekranını ve süre sayacını diğer uygulamaların üstünde göstermek için. Ekrandaki içerik okunmaz ya da kaydedilmez.
- **Bildirim:** koruma servisinin çalıştığını gösteren sabit bildirim için. Uygulama gizli çalışmaz.
- **Ön plan servisi:** süre sayımının arka planda kesilmeden sürmesi için.
- **Başlangıçta çalıştır:** cihaz yeniden açılınca kilidin tekrar devreye girmesi için.
- **Kullanım erişimi (isteğe bağlı):** yalnızca o an ön planda hangi uygulamanın açık olduğunu öğrenir. Arama ve WhatsApp kısayolları açıkken kilidin araya girmemesi ve sürenin sadece uygulama içindeyken akması için kullanılır. Bilgi kaydedilmez ve cihazdan çıkmaz. Vermezseniz uygulama çalışmaya devam eder, bu iki özellik sınırlı olur.
- **Pil kısıtlamasını kaldırma:** servis arka planda kapatılmasın diye ebeveynin onayıyla.

## Çocukların gizliliği
Uygulama çocuklardan kişisel bilgi toplamaz. Ad ve yaş çocuğun kendisinden değil, kurulumu yapan ebeveynden alınır ve yalnızca cihazda kalır. Çocuklara reklam, satın alma ya da sosyal özellik sunulmaz.

## Silme ve kontrol
Ebeveyn panelinden bir çocuk silinebilir; bu işlem o çocuğun adını, yaşını ve şifresini siler. Tüm bilgiler uygulama kaldırılarak ya da Android ayarlarından uygulama verisi temizlenerek silinebilir.

## Değişiklikler
Bu politika değişirse yeni tarihle burada yayınlanır.

## İletişim
Sorular için: GitHub deposundaki "Issues" bölümü (https://github.com/aslan-cr/kilit/issues).
