# Beran-Meva Kilit (Android tablet)

Paylaşılan tablette sırayla Beran ve Meva için şifreli, süreli giriş.

## Nasıl çalışır
1. Her gün tablet açılınca **BERANIN ŞİFRESİNİ GİR** çıkar. İlk seferde Beran şifresini oluşturur.
2. Doğru şifreyle 2 saat (ayarlanabilir) uygulamalar kullanılır.
3. Süre dolunca **MEVANIN ŞİFRESİNİ GİR** çıkar. İlk seferde Meva şifresini oluşturur.
4. Meva'nın süresi bitince sıra tekrar Beran'a döner. Yeni günde her zaman Beran'dan başlar.
5. Şifre unutulursa ebeveyn, kilit ekranındaki **Ebeveyn** düğmesinden kendi şifresiyle sıfırlar.

Servis her zaman görünür bir bildirim gösterir (kimin ne kadar süresi kaldığı yazar). Gizli çalışmaz.

## Kurulum
1. Android Studio'da **Open** ile bu klasörü aç, Gradle senkronizasyonunu bekle.
2. **Build > Build APK(s)** ile derle (veya tableti USB ile bağlayıp **Run**).
3. Tablette uygulamayı aç, **ebeveyn şifresini** oluştur.
4. Panelde sırayla: (1) üstte gösterme izni, (2) bildirim izni, (3) pil kısıtlamasını kaldır.
5. "Paneli kapat ve kilitle" de. Kilit ekranı çıkmalı.

## Sınırlar
- Android, bir uygulamanın kendi kendini kaldırılmaya karşı korumasına izin vermez (cihaz sahibi / Family Link gerekir). Çocuklar için Ayarlar'dan uygulama kaldırmayı Family Link ile kısıtlayabilirsin.
- Güvenli mod ve tarih/saat değiştirme kilidi aşabilir. Ayarlar'da "Otomatik tarih ve saat"i açık tutmak yardımcı olur.
- Kilit, ekran açıldıktan yaklaşık 1 saniye sonra devreye girer.

## Ödev saati (v1.1)
Ebeveyn panelinde **Ödev saatleri** bölümünden gün ve saat aralığı eklenir (örn. Pzt-Cum 16:00-18:00).
- Bu saatlerde sıra kimde olursa olsun **ÖDEV ZAMANI** ekranı çıkar, hiçbir uygulama açılamaz.
- Ödev sırasında aktif kullanıcının süresi akmaz, ödev bitince kaldığı yerden devam eder.
- Sadece Ebeveyn düğmesi ve ebeveyn şifresiyle çıkılır.
- Aralık gece yarısını geçemez (örn. 23:00-01:00 yerine iki ayrı aralık ekle).
- APK artık sabit imzayla derlenir, yeni sürüm eskisinin üstüne kurulur.

## Güncelleyici (ikinci uygulama)
`updater` modülü ayrı bir uygulama üretir (guncelle.apk). İçine eklediğin APK dosyalarını listeler,
kurulu sürümle karşılaştırır, Kur/Güncelle düğmesi verir. Yeni sürümü tekrar eklersen eskisinin yerine geçer.
Android her kurulumda onay ister, sessiz kurulum mümkün değil.
GitHub derlemesi artık `kilit.apk` ve `guncelle.apk` dosyalarını birlikte üretir.

## Otomatik güncelleme
GitHub derlemesi bitince kilit.apk ve guncelle.apk bir Release olarak yayınlanır.
Güncelleyici'de "Güncellemeleri kontrol et" düğmesi en son Release'teki APK'ları indirir,
kurulu sürümle karşılaştırır, yeni olanı kurar. Depo herkese açık (public) olmalıdır.

## Yuvarlak sayaç ve koruma (v1.2)
- Ekranda her uygulamanın üstünde yuvarlak bir sayaç durur: kalan süre, kullanıcı adı ve ilerleme halkası.
  Parmakla sürüklenir, üstünde kapatma düğmesi yoktur. Dokununca kullanıcının rengi değişir (8 renk).
  Ödev saatinde turuncu geri sayım, kimse girişli değilken gri "SIRA" gösterir.
- Servis kapanırsa nöbetçi alarm dakikada bir yeniden başlatır. Ebeveyn panelinde "Koruma servisi" durumu görünür.

## Yeni uygulama eklemek (otomatik)
Kök klasöre içinde build.gradle.kts olan yeni bir klasör eklenirse otomatik bir uygulama (modül) sayılır.
GitHub derlemesi bütün uygulamaları derler ve Release'e koyar. Güncelleyici açılınca Release'i kendiliğinden
kontrol eder, yeni uygulamaları listeye ekler (kurulum için kullanıcı Android onayı verir).

## Sayfa uygulamaları (v1.4)
Bu klasörlerin her biri ayrı bir uygulamadır; sayfa `src/main/assets/index.html` içinde, internetsiz çalışır:
`hamamboceki` (Dancing Cockroaches), `organlar` (İnsan Vücudu), `denemeatolyesi` (Deneme Atölyesi),
`gunessistemi` (Güneş Sistemi), `yikimustasi` (Yıkım Ustası 3D). Modülde `libs.txt` varsa derleme sırasında
oradaki dosyalar (url dosyaadı) indirilip uygulamanın içine konur.

## Sayfa uygulamaları (v1)
Her HTML sayfası kendi klasöründe ayrı bir uygulamadır (WebView, sayfa assets/index.html içinde, internetsiz çalışır):
hamamboceki, organlar, denemeatolyesi, gunessistemi, yikimustasi. Her birinin kendi logosu var.
Bir klasörde libs.txt varsa (satır: `adres dosyaadi`) GitHub derlemesi o dosyaları indirip uygulamanın içine koyar.

## Kullanım takibi (v1)
- kullanimtakip ("Kullanım Kaydı"): çocuğun cihazına kurulur, cihaza özel rastgele kodu gösterir, 5 dakikada bir
  son 7 günün uygulama sürelerini (Google, Chrome, kilit uygulaması hariç) şifreleyip ntfy.sh üzerinden gönderir.
- kullanimizle ("Kullanım İzle"): başka cihazda kod girilir, o cihazın kullanımı görünür.
Veri koda bağlı anahtarla şifrelenir, sunucuda yaklaşık 12 saat kalır. İnternet gerekir.

## Güvenlik kısayolları (v1.4)
Kilit ekranında (şifre girişi ve ödev zamanı dahil) "Ara" ve "WhatsApp" düğmeleri şifresiz açılır.
Ebeveyn panelinde 4) Kullanım erişimi verilirse kilit yalnızca ön planda arama/WhatsApp varken devreye girmez;
başka uygulamaya geçilince hemen geri gelir. Erişim verilmezse düğmeye basınca 3 dakikalık serbest süre tanınır.

## Süre sadece uygulamadayken akar (v1.5)
Ekran kapalıyken, cihaz kilit ekranındayken, ana ekranda/son uygulamalarda ya da kilit-ebeveyn ekranındayken süre durur.
Ekran kapalı süre her zaman geri eklenir. Ana ekran/uygulama dışı tespiti için Kullanım erişimi (panel 4) gerekir.

## Kullanım İzle kilide katıldı, ad Bera (v1.6)
Ebeveyn panelindeki "Kullanım izle" düğmesi, ayrı uygulamayla aynı ekranı açar (kullanimizle ayrı uygulama olarak da durur).
Bunun için kilit uygulamasına INTERNET izni eklendi; yalnızca bu ekran kullanır. Çocuğun adı ekranlarda BERA olarak yazılır.

## v1.9
Kilit uygulamasından Kullanım İzle ekranı ve INTERNET izni kaldırıldı; kilit yine tamamen internetsiz. İzleme sadece ayrı "Kullanım İzle" uygulamasında.

## Sayaç boyutu ve kenara yapışma (v2.0)
Ebeveyn panelinde "Sayaç boyutunu değiştir" (56-200). Sayaç ekranın bir kenarına (24 dp yakınına) bırakılırsa
küçülür, yarı saydam olur ve yarısı ekran dışında kalır. Dokununca açılır, 4 sn sonra tekrar yapışır; sürüklenince serbest kalır.

## Sayaçta elle boyut (v2.1)
İki parmakla sayacı büyüt/küçült (56-200), ya da sayacı basılı tut: her uzun basışta küçük, orta, büyük, çok büyük boyutlar arasında geçer.
Panelden gitmek gerekmez. Kenara yapışıkken önce dokunup aç.

## Yıkım Ustası: otomatik çok oyunculu (v1.1)
Oda kodu kalktı. "Arkadaşlarla oyna"ya basan herkes ortak bir lobiye düşer; ilk gelen kurucu olur, sonrakiler ona
otomatik bağlanır. Eşleşme mesajları ntfy.sh üzerinden, oyun verisi cihazlar arasında doğrudan (WebRTC) gider. İnternet gerekir.

## Karanlık Bataklık (gozkirpma, v2.0)
Eski "Göz Kırpma Kurbağası" birinci şahıs korku oyununa çevrildi. Kurbağanın gözünden karanlık bir bataklık labirentinde ilerlersin,
etrafta gölgeler (düşmanlar) var. Kural: gözlerin AÇIKKEN gölgeler donar; gözünü kapattığın an yalnızca onlar hareket eder.
5 ışık böceğini topla, yakalanma. Ses: kalp atışı, adım sesleri, yakalanınca çığlık.
- Kamera modu: iki göz de kapanınca "göz kapalı" sayılır. Dil algılama kaldırıldı. Göz hassasiyeti düşürüldü (CLOSE_AT 0.5, OPEN_AT 0.3; game.js başında).
- Dokunmatik: ekranın SOL yarısında parmağın nerede değerse hareket joystick'i orada belirir, uzaklık sınırı yoktur. SAĞ yarı yalnızca bakışı döndürür, hareket ettirmez, sol yarıdayken ekran dönmez.
- Kamerasız mod: sağ altta basılı tutulan "GÖZÜ KAPAT" düğmesi (klavyede Boşluk). Klavye: WASD yürü, ok tuşları/fare ile bak.
Yatay ve tam ekran çalışır. Yüz modeli ilk açılışta internetten indirilir, kamera izni ister.
