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
