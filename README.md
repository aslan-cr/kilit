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

## Karanlık Bataklık (gozkirpma, v3.4)
Eski "Göz Kırpma Kurbağası" birinci şahıs korku oyununa çevrildi. Kurbağanın gözünden karanlık, mezarlık dekorlu bir bataklık labirentinde ilerlersin.
Kural: gözlerin AÇIKKEN gölgeler (cadı, kabak kafa) donar; gözünü kapattığın an yalnızca onlar hareket eder ve sana gelir.
6 ışık böceğini topla, yakalanma. Ayrıntılı tasarım: `gozkirpma/DESIGN.md`.
- **Silahlar (PSX Shotgun Pack):** Pompalı tüfekle başlarsın. Labirentte Kısa Çifte, Çifte Namlu ve Üst Üste Çifte var; kırmızı mermi kutuları mermi verir. Vurulan gölge birkaç saniye kıpırdayamaz, ölen gölge uzakta yeniden doğar.
- **Dekor (KayKit Spooktober, CC0):** mezar taşı, ölü ağaç, kabak, mum, fener direği, tabut, kazan, mihrap. Mum, kabak fener ve lamba etraflarına ışık verir.
- **Göz kuruluğu:** gözlerini 6.5 sn'den uzun açık tutarsan göz kendiliğinden kapanır (gölgeler o an hareket eder), 4 sn'den sonra görüş kararır.
- Kamera modu: iki göz de kapanınca "göz kapalı" sayılır. Dil algılama yok. Göz hassasiyeti düşük (`eyes.closeAt` 0.5, `eyes.openAt` 0.3).
- **Dokunmatik:** Ekranın SOL yarısında parmağın nerede değerse hareket joystick'i orada belirir, uzaklık sınırı yoktur. SAĞ yarı yalnızca ekranı (bakışı) döndürür, hareket ettirmez; sol yarıdayken ekran dönmez. Sağ yarıya kısa dokunuş ve sağ alttaki ATEŞ düğmesi ateş eder.
- Kamerasız mod: "GÖZÜ KAPAT" düğmesi (klavyede Boşluk). Klavye: WASD yürü, Q/E ya da ok tuşları bak, F ateş, R silah değiş.
- **Oyuncu karakteri (Hazmat):** Hazmat kıyafetli karakter giriş ekranında görünür; çok oyunculu için oyun durumunda `players` listesi ve `setPlayer()` hazır, diğer oyuncular modelle ve adlarıyla çizilir (`?players=2` ile dene).
- **Hesap:** Giriş yap / hesap oluştur / misafir. Şifre PBKDF2-SHA256 ile saklanır, 5 yanlışta 30 sn kilit, hesap başına rekor ve istatistik. SINIR: hesaplar yalnızca bu cihazda tutulur, şifre sıfırlanamaz; çok oyunculu için sunucu gerekir (`js/auth.js` içindeki `store` değiştirilecek şekilde yazıldı).
- **Kamera internetsiz:** Yüz modeli ve MediaPipe dosyaları APK'nın içine gömülür (GitHub derlemesi `tools/fetch-mediapipe.sh` ile indirip `assets/mediapipe/` altına koyar). Gömülemezse eski gibi internetten yüklemeyi dener. Yüz algılama ~15 Hz çalışır ve yavaşsa kendini seyreltir (kasma önlemi, `rules.eyes.detectMs`); kamera 320x240.
- **Lobi + odalar (çok oyunculu):** Menüden "Lobiye gir" (sunucu adresi gerekir). Lobide yürürsün; kuzeydeki 4 kabinden birine girince o odaya katılırsın, oda başına en fazla 10 kişi (dolu/oyundaki kabine girilemez). Odaya ilk kişi girince 50 sn sayaç başlar (`rules.lobby.countdown`); sayaç bitince oyun odadakilerle OTOMATİK başlar (başlat düğmesi yok), hepsi aynı labirentte başlar ve birbirini Hazmat olarak görür. Herkes çıkarsa sayaç durur. SINIR: gölgeler henüz oyuncular arasında eşitlenmiyor (herkes kendi gölgelerini görür).
- **Lobi sunucusu:** `node server/server.mjs [port]` (bağımlılık yok; Node 18+). Aynı Wi-Fi'de tabletler `ip:port` yazar (örn. `192.168.1.5:8080`). İnternet üzerinden oynamak için sunucuyu bir barındırmada çalıştırıp `wss://` ile bağlan. Hesaplar cihaz içi olduğundan sunucu adı doğrulamaz; aynı ad varsa `#2` eklenir.

Geliştirme (goat-game-creator yöntemi): bütün sayılar `assets/js/rules.js`'te, mantık DOM'suz `assets/js/sim.js`'te, `bot.js` oyuncuyla aynı girdiyle oynar.
```
cd gozkirpma
npm test                                  # sim kuralları + söz testleri (metindeki her iddia kontrol edilir)
node test/balance.mjs 40                  # bot dengesi, 40 seed
node tools/serve.mjs 5151                 # tarayıcıda dene: ?play  ?autoplay&speed=4  ?sim=30&seed=7  ?gallery=0..3  ?r.enemies.count=3
node tools/shot.mjs "?sim=30" shots/a.png # headless ekran görüntüsü (+ sayfa hataları)
node tools/lobby-ui-test.mjs             # iki tarayıcı + gerçek sunucu: lobi, oda, başlatma, dolu oda
node tools/auth-ui-test.mjs               # giriş ekranını gerçek tarayıcıda sınar
node tools/bake-hazmat.mjs <Hazmat klasörü>   # oyuncu modelini yeniden pişir
node tools/touch-test.mjs                 # dokunmatik kurallarını gerçek dokunma olaylarıyla sınar
node tools/bake-models.mjs <Spooktober klasörü> <PSXShotgunPack/Files>   # modelleri yeniden pişir
```
Varlık lisansları: KayKit Spooktober Seasonal Pack 1.1 (Kay Lousberg, CC0). PSX Shotgun Pack: paketin içinde lisans dosyası yok, yayımlamadan önce kaynağındaki koşullara bak.

