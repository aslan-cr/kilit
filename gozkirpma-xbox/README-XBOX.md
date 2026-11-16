# Karanlık Bataklık — Xbox kontrolcü sürümü

`gozkirpma` oyununun kopyasıdır; ana oyun klasörü değiştirilmedi. Fark: Xbox kontrolcüsü (Gamepad API) desteği ve fener ışığını açıp kapatma.

## Kontroller
| Tuş | İşlev |
|---|---|
| Sol çubuk | Yürü |
| Sağ çubuk | Bak (sağa/sola döner, yukarı/aşağı bakar) |
| **RT** | Silah elindeyken: ateş (basılı tut) · Fener elindeyken: ışığı aç/kapat |
| **RB** | Silah ↔ el feneri |
| LB | Sıradaki silah (birden fazla silah varsa) |
| LT (basılı) | Gözünü kapat (kamerasız modda) |
| A | Menüde başla (misafir girişi / kamerasız başlat) |
| B | Yere düştüğünde: pes et, lobiye dön |

Fenerde ışık her seferinde açık başlar; RB ile silaha dönüp tekrar fenere geçince yine açık olur.

## Xbox'ta çalıştırma
ES modülleri kullandığı için dosya olarak değil, bir web adresinden açılmalıdır.
1. Klasörü bir web sunucusuna koy (GitHub Pages, Netlify vb.) ya da PC'de: `python3 -m http.server 8000`
2. Xbox'ta **Microsoft Edge**'i aç, adrese git (PC ile aynı ağda `http://PC-IP:8000`).
3. Kontrolcü bağlıyken sayfada herhangi bir tuşa bas, menüde **A**'ya bas.

Değişen dosyalar: `js/sim.js` (fener ışığı durumu), `js/main.js` (gamepad girdisi), `index.html` (ipucu satırı).

## Düşmanlar
Android sürümüyle aynı üç düşman: **Koşucu Canavar** (en hızlısı), **İblis** ve **Sıska Canavar**. Üçü de iskeletle canlandırılır; modeller `models/models.json` içindedir ve `gozkirpma/tools/bake-*.mjs` araçlarıyla üretilip buraya kopyalanır.

## Yere düşme ve canlandırma (çevrim içi)
Android sürümüyle aynı: çevrim içi odada yakalanınca lobiye dönülmez, yere düşülür. Odadaki bir arkadaş 3 sn yanında durursa kalkarsın (3 sn gölgeler donar). 45 sn içinde kimse gelmezse ya da odada ayakta kimse kalmazsa oyun biter. Yerdeyken sağ çubukla etrafa bakabilirsin, **B** ile pes edersin. Sayılar `js/rules.js` → `revive`.

## Yukarı/aşağı bakış
Sağ çubuğu yukarı/aşağı itince yukarı/aşağı bakılır (sınır `rules.player.pitchMax` ≈43°, hız `pitchKeys`). Görüntü gerçek baş eğimi gibi perspektifle düzeltilir (`pitchWarp`), büyüteç/gerilme etkisi olmaz. Klavyede Z yukarı, X aşağı; dokunmatikte sağ yarıda parmağı yukarı/aşağı sürükle. Ateş ve vuruş hâlâ yatay düzlemde.

## Tavan yok
Android sürümündeki gibi tavan kaldırıldı: duvarlar yukarı doğru uzayıp karanlığa karışır, üstte sonsuz karanlık bir boşluk var (`rules.view.wallFade`, `voidHaze`). Yukarı bakınca bu boşluk görünür.

## Koşucu Canavar'ın saldırısı
Android sürümüyle aynı: Koşucu Canavar yakalayınca üstümüze atlayıp bizi devirir, ağzını açıp ısırır, ekran kararır; 0.5 sn karanlıktan sonra "Buraya kadar mıydı? / Cidden pes mi edeceksin?" yazar. Ayarlar `js/rules.js` → `scare`.
