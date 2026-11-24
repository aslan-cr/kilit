const privacyText = '''Gizlilik Politikası (özet)

• SkyNav reklam göstermez, verini satmaz.
• Konum: hava durumunu, rakımını ve çevre dağlarını hesaplamak için cihazında kullanılır. Hava verisi alınırken yaklaşık koordinatın Open-Meteo, NOAA ve RainViewer gibi ücretsiz servislere gider; kim olduğun gönderilmez.
• Hesap: Google ile girersen e-posta adresin ve Pro hakların Firebase'de (Firestore) senin hesabına bağlı saklanır. Girişsiz de kullanabilirsin.
• Bulut yedeği: Google ile girdiysen kayıtlı yerlerin, rozetlerin, zaman kapsüllerin, gözlem kayıtların ve uygulama ayarların da Firestore'da yalnızca senin erişebildiğin hesap kaydına yedeklenir; uygulamayı silip yeniden kursan ya da telefon değiştirsen aynı Google hesabıyla girince geri gelir. Ayarlar > Bulut yedeği'nden kapatabilir ya da buluttaki yedeği silebilirsin.
• Cihaz kimliği: davet/ödül suistimalini önlemek için cihazdan türetilmiş tek yönlü bir özet (hash) saklanır; ham kimlik gönderilmez.
• Özetler ve hava önbelleği yalnızca cihazında (Hive) kalır. Giriş yapmadıysan ya da bulut yedeği kapalıysa kayıtlı konumların ve öz-denetim kayıtların da yalnızca cihazındadır. Harici yapay zeka servisi kullanılmaz.
• Kamera/mikrofon yalnızca "Kendi Hava Kanalını Sun" kaydı sırasında, senin başlattığında çalışır; kayıt cihazında kalır.
• Verilerini silmek için Ayarlar > Hesabı ve verilerimi sil.''';

const termsText = '''Kullanım Şartları (özet)

• SkyNav bilgi ve eğlence amaçlıdır. Hava, yol ve gökyüzü tahminleri hatalı olabilir; can ve mal güvenliği kararlarını resmî kurumların (MGM, AFAD vb.) uyarılarına göre ver.
• Sürüş sırasında telefonla ilgilenme; sesli uyarılar yardımcıdır, sürücü sorumluluğunu ortadan kaldırmaz.
• "Deprem Bulutu/Basınç Anomali Günlüğü", "Okul Tatili Kahini" ve benzeri eğlence hesaplayıcıları bilimsel tahmin değildir. "Migren/Eklem" uyarısı tıbbi tavsiye değildir.
• Pro hakları (satın alma, davet, ödül) hesabına bağlıdır; kötüye kullanım (sahte hesap, cihaz sıfırlama ile ödül kasma) hakların iptaline yol açabilir.''';

const dataText = '''Veri Kullanımı & İzinler

• Konum (isteğe bağlı): otomatik hava durumu, rakım ve dağ radarı için. Vermezsen elle şehir seçersin.
• Bildirim (isteğe bağlı): kutlama ve uyarı bildirimleri için. Vermezsen uyarıları yalnızca uygulama içinde görürsün.
• Kamera & mikrofon (isteğe bağlı): sadece Hava Kanalı kaydı için.
• Fener: SOS feneri için.
• İnternet: hava, radar ve harita verisi için. Bağlantı kopunca son kaydedilen veri gösterilir.''';
