# Karanlık Bataklık: tasarım (tek sayfa)

**Hayal:** Karanlık bir bataklık mezarlığında, tek bir fener ışığıyla, gözünü kırpmaya mecbur kalarak ışık böceklerini toplamak.

## Çekirdek döngü
1. Labirentte yürü, 6 ışık böceği topla (hepsi toplanınca kazanırsın).
2. Gözlerin AÇIKKEN gölgeler (cadı, kabak kafa) donar. Gözünü kapattığın an yalnızca onlar hareket eder ve sana gelir.
3. Göz kuruluğu: 6.5 sn açık kalırsan göz zorla kapanır. Yani hiç kırpmadan oynayamazsın, ama kırpmak risktir.
4. Pompalıyla gölgeyi vurup birkaç saniye dondurabilir ya da dağıtabilirsin (12 sn sonra uzakta geri döner). Mermi azdır.
5. Her böcek gölgeleri hızlandırır. Yakalanırsan korku sahnesi, oyun biter.

## Oyuncunun eylemleri
Yürümek, bakmak, gözünü kapatmak/açmak (kamerayla ya da düğmeyle), ateş etmek, silah değiştirmek, toplamak (böcek, mermi kutusu, silah).

## Kazanma / kaybetme
Kazanma: 6 böcek. Kaybetme: bir gölge 0.5 karoya yaklaşır. Rekor: en kısa süre.

## Her oyunu farklı kılan
Her seferinde yeni labirent (seed), dekorun, silahların, mermi kutularının ve gölgelerin yeri değişir.

## Varlıklar
- Dekor ve karakterler: KayKit Spooktober (CC0). Mum, kabak fener ve lamba ışık verir.
- Silahlar: PSX Shotgun Pack (pompalı, kısa çifte, çifte namlu, üst üste çifte).
- Hepsi `tools/bake-models.mjs` ile `assets/models/models.json` içine pişirilir; çizici dış kütüphane kullanmaz (internetsiz WebView).

## Kontroller
- Dokunmatik: sol yarı = joystick (parmak neredeyse orada, uzaklık sınırsız), sağ yarı = yalnızca bakış (kısa dokunuş = ateş), sağ altta ATEŞ / SİLAH DEĞİŞ / GÖZÜ KAPAT.
- Klavye: WASD, Q/E ya da oklar, F ateş, R silah, Boşluk göz.

## İlk sayılar
Hepsi `assets/js/rules.js` içinde. Denge hedefi (bot, 40 seed): kazanma %60-90. İnsan botlardan zayıftır, bu yüzden bot yüksekse insan için normal olur.
