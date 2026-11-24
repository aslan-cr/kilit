# SkyNav — Gizlilik Politikası

**Uygulama:** SkyNav: Kar, Hava ve Gökyüzü (Google Play)

- SkyNav reklam göstermez, verini satmaz.
- Konum: hava durumunu, rakımını ve çevre dağlarını hesaplamak için cihazında kullanılır. Hava verisi alınırken yaklaşık koordinatın Open-Meteo, NOAA ve RainViewer gibi ücretsiz servislere gider; kim olduğun gönderilmez.
- Hesap: Google ile girersen e-posta adresin ve Pro hakların Firebase'de (Firestore) senin hesabına bağlı saklanır. Girişsiz de kullanabilirsin.
- Bulut yedeği: Google ile girdiysen kayıtlı yerlerin, rozetlerin, zaman kapsüllerin, gözlem kayıtların ve uygulama ayarların da Firestore'da yalnızca senin erişebildiğin hesap kaydına yedeklenir; uygulamayı silip yeniden kursan ya da telefon değiştirsen aynı Google hesabıyla girince geri gelir. Ayarlar > Bulut yedeği'nden kapatabilir ya da buluttaki yedeği silebilirsin.
- Cihaz kimliği: davet/ödül suistimalini önlemek için cihazdan türetilmiş tek yönlü bir özet (hash) saklanır; ham kimlik gönderilmez.
- Özetler ve hava önbelleği yalnızca cihazında (Hive) kalır. Giriş yapmadıysan ya da bulut yedeği kapalıysa kayıtlı konumların ve öz-denetim kayıtların da yalnızca cihazındadır. Harici yapay zeka servisi kullanılmaz.
- Kamera/mikrofon yalnızca "Kendi Hava Kanalını Sun" kaydı sırasında, senin başlattığında çalışır; kayıt cihazında kalır.
- Hesabını ve verilerini silmek için: Ayarlar > Gizlilik & izinler > Hesabımı ve verilerimi sil. Hesabın, Pro hakların, davet kredilerin ve buluttaki yedeğin kalıcı olarak silinir. Kötüye kullanımı önlemek için cihazdan türetilmiş tek yönlü özet ve kullanılmış davet kodları saklanır. Telefondaki veriler uygulamayı silince kalkar.

Hesap ve veri silme: [skynav_hesap_silme.md](skynav_hesap_silme.md)
