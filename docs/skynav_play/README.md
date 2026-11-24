# SkyNav — Google Play mağaza sayfası

| Alan | Dosya | Sınır |
|---|---|---|
| Uygulama adı | title.txt | 30 karakter |
| Kısa açıklama | short_description.txt | 80 karakter |
| Tam açıklama | full_description.txt | 4000 karakter |
| Uygulama simgesi | icon_512.png | 512×512 PNG |
| Öne çıkan görsel | feature_graphic_1024x500.png | 1024×500 |
| Telefon ekran görüntüleri | screen_1..8.png | 1080×1920 (9:16) |

Yeniden üretmek:
- Ekranlar: `flutter test test/shots/shots_test.dart --dart-define=STORE=true` → /tmp/store (390×780, 3×)
- Öne çıkan sahne: `flutter test test/shots/feature_graphic_test.dart` → /tmp/store/feature_*.png
- Çerçeve ve yazılar: PIL betiği (başlık Inter ExtraBold 66, alt yazı Inter Medium 36, buz beyazı zemin).
