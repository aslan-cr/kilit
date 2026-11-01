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
