# SkyNav (Flutter)

Beyaz/buzlu cam tasarımlı hava durumu, 3D harita, uçak radarı, yol tarifi ve gökyüzü uygulaması. Beş sekme: Hava (+Yaşam Laboratuvarı), 3D Harita, Uçak Radarı, Yol Tarifi, Gökyüzü & Astronomi. Ayrıca giriş/ekosistem, davet-indirim-ödül-satın alma altyapısı, dinamik ikon, 2 ana ekran widget'ı, arka plan alarmları, rozetler ve 27 dil.

Güncelleyici uygulamada "SkyNav" olarak görünmesi için CI (`.github/workflows/build.yml`) `skynav.apk` dosyasını da release'e ekler (release yalnızca `main` dalında yayınlanır).

- Derleme: `cd skynav && flutter pub get && flutter build apk` (Flutter 3.35+). Firebase için `FIREBASE_KURULUM.md`.
- Gerçek ses dosyaları: `assets/audio/README.md`.
- Bu klasörde `build.gradle.kts` olmadığı için kökteki Gradle çok modüllü yapıya dahil edilmez.
