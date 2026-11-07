// Bütün oyun sayıları burada. Mantık (sim.js) bunları okur; denge kurmak = buradaki sayıyı değiştirmek.
// Tarayıcıda ?r.enemies.count=6 gibi URL parametreleriyle de değiştirilebilir (bkz. main.js).

export const RULES = {
  maze: { cells: 12 },                       // 12x12 hücre -> 25x25 karo
  player: {
    speed: 2.4,                              // karo/sn
    radius: 0.2,
    model: "hazmat",                         // oyuncu karakteri (diğer oyuncular bunu görür; birinci şahısta kendini görmezsin)
    scale: 0.27,                             // Hazmat boyu 2.43 birim -> duvar yüksekliğinin ~0.66'sı
    eyeHeight: 0.42,                         // kurbağa göz hizası (duvar yüksekliği = 1)
    lookSens: 0.0055,                        // rad/piksel (dokunmatik bakış)
    turnKeys: 2.0,                           // rad/sn (klavye ok tuşları)
  },
  eyes: {
    closeAt: 0.5,                            // kameradan göz kapanma değeri bunu aşınca kapalı (düşük hassasiyet; eskiden 0.32)
    openAt: 0.3,                             // bunun altına inince açık (eskiden 0.18)
    dryWarn: 4,                              // sn: gözler bu kadar açık kalırsa görüş kararıp titremeye başlar
    dryMax: 6.5,                               // sn: bu kadar açık kalırsa göz kendiliğinden kapanır (kırpma zorunlu)
    forcedBlink: 0.5,                        // sn: zorunlu kırpmanın süresi (gölgeler bu sürede hareket eder)
    recover: 6,                              // gözler kapalıyken "kuruluk" sayacı saniyede bu kadar azalır
  },
  goal: { flies: 6 },                        // toplanacak ışık böceği
  enemies: {
    count: 6,
    baseSpeed: 1.9,                          // karo/sn (göz kapalıyken)
    speedPerFly: 0.3,                        // her böcek için hızlanma
    catchDist: 0.5,                          // bu kadar yaklaşınca yakalar
    stunSec: 1.6,                            // vurulunca bu kadar süre gözler kapalı olsa bile kıpırdamaz
    knockback: 0.45,                         // vuruşta geri savrulma (karo)
    respawnSec: 12,                          // öldükten sonra yeniden doğma süresi
    respawnMinDist: 12,                      // yeniden doğarken oyuncuya en az bu kadar adım uzakta
    startMinDist: 10,                        // başlangıçta oyuncuya en az bu kadar adım uzakta
    types: {
      jack:  { name: "Kabak Kafa", speed: 1.0,  hp: 2, radius: 0.30, scale: 0.46 },
      witch: { name: "Cadı",       speed: 0.85, hp: 3, radius: 0.30, scale: 0.42 },
    },
  },
  ammo: {
    start: 3,
    max: 12,
    boxes: 6,                                // labirentteki mermi kutusu sayısı
    perBox: 2,                               // kutu başına mermi
    pickupRadius: 0.55,
  },
  weapons: {
    // pellets: saçma sayısı, damage: saçma başı hasar, spread: yarım koni açısı (rad), range: karo,
    // cooldown: atışlar arası sn, shells: atış başına harcanan mermi
    pump:      { name: "Pompalı",         model: "pump",      pellets: 8,  damage: 0.40, spread: 0.10, range: 8,  cooldown: 0.90, shells: 1, kick: 0.6 },
    sawed:     { name: "Kısa Çifte",      model: "sawed",     pellets: 10, damage: 0.50, spread: 0.24, range: 4,  cooldown: 1.10, shells: 1, kick: 0.9 },
    double:    { name: "Çifte Namlu",     model: "double",    pellets: 14, damage: 0.45, spread: 0.13, range: 7,  cooldown: 1.60, shells: 2, kick: 1.2 },
    overUnder: { name: "Üst Üste Çifte",  model: "overUnder", pellets: 9,  damage: 0.45, spread: 0.07, range: 10, cooldown: 0.55, shells: 1, kick: 0.7 },
    start: "pump",
    found: ["sawed", "double", "overUnder"], // labirentte bir kez bulunur
    pickupRadius: 0.55,
  },
  flies: { pickupRadius: 0.55, minStartDist: 6, minSpacing: 4 },
  props: {
    density: 0.26,                           // açık karoların kabaca bu kadarına dekor konur
    minStartDist: 3,
    // Model ölçekleri (KayKit birimi -> oyun birimi, duvar yüksekliği = 1). Ölçülerden hesaplandı.
    scale: {
      gravestone: 0.20, treeA_graveyard: 0.30, treeB_graveyard: 0.32, treeC_graveyard: 0.33, treeD_graveyard: 0.30,
      pumpkinLarge: 0.20, pumpkinSmall: 0.22, jackolantern_big: 0.24, jackolantern_small: 0.22,
      candleBundle: 0.25, candleLarge: 0.22, candleSmall: 0.24, lampPost: 0.30, coffinA_bottom: 0.28, coffinB_bottom: 0.28,
      cauldron: 0.30, shrine: 0.33, detail_graveyard: 0.30, fenceSingle: 0.27, candyBucket: 0.22,
    },
    // Duvar kenarına dizilen dekorlar (ağırlık: sık/seyrek) ve çıkmaz sokakta durup oyuncuyu bekleyen büyük dekorlar
    wall: { gravestone: 5, treeA_graveyard: 2, treeB_graveyard: 2, treeC_graveyard: 2, treeD_graveyard: 2, pumpkinLarge: 3,
            pumpkinSmall: 3, jackolantern_small: 2, candleBundle: 2, candleLarge: 2, candleSmall: 2, fenceSingle: 3, detail_graveyard: 2 },
    deadEnd: ["shrine", "coffinA_bottom", "cauldron", "lampPost", "jackolantern_big", "coffinB_bottom"],
    // Işık veren dekorlar: renk (r,g,b 0-1), yarıçap (karo), şiddet
    lights: {
      jackolantern_small: { c: [1.0, 0.55, 0.15], r: 2.2, k: 0.9 }, jackolantern_big: { c: [1.0, 0.55, 0.15], r: 3.0, k: 1.2 },
      candleBundle: { c: [1.0, 0.8, 0.45], r: 2.0, k: 0.8 }, candleLarge: { c: [1.0, 0.8, 0.45], r: 1.8, k: 0.7 },
      candleSmall: { c: [1.0, 0.8, 0.45], r: 1.5, k: 0.6 }, lampPost: { c: [0.9, 1.0, 0.6], r: 3.6, k: 1.3 },
    },
  },
  danger: { range: 8 },                      // bu kadar yakında düşman varsa kalp atışı hızlanır
  scare: { seconds: 3.0 },                   // yakalanma sahnesi süresi (karanlık + saldırı + kararma)
};

// URL'den kural değiştirme: ?r.enemies.count=6
export function applyOverrides(rules, search) {
  const out = JSON.parse(JSON.stringify(rules));
  for (const [k, v] of new URLSearchParams(search)) {
    if (!k.startsWith("r.")) continue;
    const path = k.slice(2).split(".");
    let o = out;
    for (let i = 0; i < path.length - 1; i++) { o = o[path[i]]; if (o == null) break; }
    const last = path[path.length - 1];
    if (o != null && last in o && typeof o[last] === "number") o[last] = Number(v);
  }
  return out;
}
