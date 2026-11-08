# Karanlık Bataklık — Xbox kontrolcü sürümü

`gozkirpma` oyununun kopyasıdır; ana oyun klasörü değiştirilmedi. Fark: Xbox kontrolcüsü (Gamepad API) desteği ve fener ışığını açıp kapatma.

## Kontroller
| Tuş | İşlev |
|---|---|
| Sol çubuk | Yürü |
| Sağ çubuk | Bak |
| **RT** | Silah elindeyken: ateş (basılı tut) · Fener elindeyken: ışığı aç/kapat |
| **RB** | Silah ↔ el feneri |
| LB | Sıradaki silah (birden fazla silah varsa) |
| LT (basılı) | Gözünü kapat (kamerasız modda) |
| A | Menüde başla (misafir girişi / kamerasız başlat) |

Fenerde ışık her seferinde açık başlar; RB ile silaha dönüp tekrar fenere geçince yine açık olur.

## Xbox'ta çalıştırma
ES modülleri kullandığı için dosya olarak değil, bir web adresinden açılmalıdır.
1. Klasörü bir web sunucusuna koy (GitHub Pages, Netlify vb.) ya da PC'de: `python3 -m http.server 8000`
2. Xbox'ta **Microsoft Edge**'i aç, adrese git (PC ile aynı ağda `http://PC-IP:8000`).
3. Kontrolcü bağlıyken sayfada herhangi bir tuşa bas, menüde **A**'ya bas.

Değişen dosyalar: `js/sim.js` (fener ışığı durumu), `js/main.js` (gamepad girdisi), `index.html` (ipucu satırı).
