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
    lookSens: 0.0055,
    pitchMax: 0.95,                          // yukarı/aşağı bakış sınırı (rad)
    pitchKeys: 1.6,                          // rad/sn (klavye Z/X)                        // rad/piksel (dokunmatik bakış)
    turnKeys: 2.0,                           // rad/sn (klavye ok tuşları)
  },
  eyes: {
    detectMs: 66,               // yüz algılama en sık bu aralıkla (ms) çalışır; küçültmek daha duyarlı ama daha yavaş
    // Kişiye göre ayarlı eşik (js/eyes.js): taban = o kişinin açık göz değeri (gözü yarı açık olanlarda yüksek çıkar)
    closeDelta: 0.28, openDelta: 0.14,       // kapanış = taban + closeDelta, açılış = taban + openDelta
    closeFloor: 0.45, openFloor: 0.3,        // taban ne kadar düşük olsa da eşikler bunların altına inmez (eski sabit eşikler)
    closeMax: 0.8,                           // kapanış eşiği bunu aşmaz (tam kapalı göz ~0.8-1.0 verir)
    baseMax: 0.45, baseRise: 0.01,           // taban en çok bu kadar; yukarı kayma hızı
    closeAt: 0.5, openAt: 0.3,               // (geriye uyum)
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
      runner: { name: "Koşucu Canavar", speed: 1.3, hp: 2, radius: 0.30, scale: 0.58, stride: 1.4 },   // en hızlısı; iskeletli koşu animasyonu (model boyu 1 birim x 0.58)
      monster: { name: "Sıska Canavar", speed: 0.85, hp: 3, radius: 0.30, scale: 0.42 },   // eski cadıyla aynı boy (model 2.177 birim x 0.42)
      demon: { name: "İblis", speed: 1.05, hp: 3, radius: 0.30, scale: 0.95, stride: 1.1 },   // kodla kurulmuş iskelet + yürüme döngüsü, parlayan kor gözler (model boyu 1 birim x 0.95)
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
    pump:      { name: "Pompalı",         model: "pump",      pellets: 8,  damage: 0.40, spread: 0.10, range: 8,  cooldown: 0.90, shells: 1, kick: 0.6, hold: { r: [-0.25, 0.075, 0], l: [0.08, 0.085, 0], handScale: 0.5, roll: 0 } },
    sawed:     { name: "Kısa Çifte",      model: "sawed",     pellets: 10, damage: 0.50, spread: 0.24, range: 4,  cooldown: 1.10, shells: 1, kick: 0.9, hold: { r: [-0.22, 0.08, 0], l: [0.0, 0.15, 0], handScale: 0.5, roll: 0 } },
    double:    { name: "Çifte Namlu",     model: "double",    pellets: 14, damage: 0.45, spread: 0.13, range: 7,  cooldown: 1.60, shells: 2, kick: 1.2, hold: { r: [-0.22, 0.09, 0], l: [0.05, 0.1, 0], handScale: 0.5, roll: 0 } },
    overUnder: { name: "Üst Üste Çifte",  model: "overUnder", pellets: 9,  damage: 0.45, spread: 0.07, range: 10, cooldown: 0.55, shells: 1, kick: 0.7, hold: { r: [-0.24, 0.075, 0], l: [0.05, 0.085, 0], handScale: 0.5, roll: 0 } },
    start: "pump",
    found: [],                               // labirentte silah bulunmaz (yerine para çıkar); doldurulursa o silahlar bir kez bulunur
    pickupRadius: 0.55,
  },
  // El feneri (FlashLight pack): L tuşu / FENER düğmesi. Elde fener varken ateş edilemez.
  flashlight: {
    range: 11,                               // ışık huzmesinin boyu (karo)
    coneCos: 0.80,                           // yarım açının kosinüsü (0.80 ≈ 37°); büyürse huzme daralır
    k: 2.2,                                  // huzme parlaklığı
    haloR: 2.2, haloK: 0.55,                 // oyuncunun etrafındaki yumuşak ışık
    color: [1.0, 0.93, 0.78],
    enemyBoost: 1.3,                         // fener yanıkken, ışık menzilindeki gölgeler bu kadar hızlı koşar (ışığa çekilirler)
    models: ["fl1", "fl2", "fl3"],
    stats: { fl1: { range: 8, k: 1.8 }, fl2: { range: 11, k: 2.2 }, fl3: { range: 14, k: 2.8 } },   // model başına menzil/parlaklık (range, k üsttekileri ezer)
    // Elde tutuş: grip = modeldeki sap konumu (el buraya gelir), scale = boyut, at = elde duruş kayması, lensY = mercek ucunun model y'si, handScale/roll = el boyu/dönüşü
    hold: {
      fl1: { grip: [0, -0.007, 0.039], scale: 1.7, at: [0.02, 0.0], hand: [0, 0, 0], lensY: 0.0472, handScale: 0.18, roll: 0 },
      fl2: { grip: [0, -0.018, 0.052], scale: 1.25, at: [0.02, 0.0], hand: [0, 0, 0], lensY: 0.07, handScale: 0.18, roll: 0 },
      fl3: { grip: [0, -0.015, 0.043], scale: 1.5, at: [0.02, 0.0], hand: [0, 0, 0], lensY: 0.0558, handScale: 0.18, roll: 0 },
    },
  },
  // Dükkan: labirentte bir yerde; yanına yaklaşınca (radius) otomatik açılır, uzaklaşınca kapanır. Fiyatlar para cinsinden (1 para = coins.value).
  // fener: model -> menzil (range, karo) ve parlaklık (k); satın alınan en son fener ele alınır. silah: rules.weapons anahtarı.
  shop: {
    radius: 1.7, minStartDist: 8, minFlyDist: 3,
    items: [
      { id: "fl1", kind: "light", price: 30 },
      { id: "sawed", kind: "gun", price: 45 },
      { id: "fl2", kind: "light", price: 60 },
      { id: "overUnder", kind: "gun", price: 60 },
      { id: "double", kind: "gun", price: 75 },
      { id: "fl3", kind: "light", price: 90 },
    ],
    names: { fl1: "Küçük Fener", fl2: "Orta Fener", fl3: "Güçlü Fener" },
    light: { c: [1.0, 0.75, 0.3], r: 3.4, k: 1.2 },
  },
  switch: { seconds: 0.55 },                 // silah/fener değiştirme animasyonu: eski eşya iner, yenisi kalkar
  // Para: labirentte rastgele yerlerde belirir; her biri `value` para verir. Beklemeye devam ettikçe yenileri rastgele yerlerde oluşur.
  coins: { value: 15, start: 3, max: 6, spawnEvery: 9, minPlayerDist: 4, minCoinDist: 3, pickupRadius: 0.55, scale: 0.16 },
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
  // Görüntü: tavan yok; duvarlar yukarı doğru wallFade birim uzar ve karanlığa karışır. voidHaze: boşluğun ufka yakın hafif sisi (0 = tam siyah)
  view: { wallFade: 2.6, voidHaze: 7 },
  danger: { range: 8 },                      // bu kadar yakında düşman varsa kalp atışı hızlanır
  scare: { seconds: 3.0 },                   // yakalanma sahnesi süresi (karanlık + saldırı + kararma)
  // Lobi: kuzey duvarında yan yana oda kurma yerleri (kabinler), altında ortak salon
  lobby: {
    rooms: 4,                                // oda kurma yeri sayısı
    countdown: 50,                           // sn: odaya ilk kişi girince sayaç başlar, bitince oyun OTOMATİK başlar
    minPlayers: 1,                           // sayaç için odada en az bu kadar kişi olmalı (2 yapılırsa tek kişi bekler)
    maxPerRoom: 10,                          // bir odadaki en fazla kişi
    maxPlayers: 20,                          // BİR LOBİDEKİ en fazla kişi; dolunca sunucu yeni lobi açar
    maxLobbies: 50,                          // sunucudaki en fazla lobi sayısı
    size: 26,                                // harita kenarı (karo)
    cubW: 5, cubGap: 1, cubDepth: 4,         // kabin genişliği, kabinler arası duvar, kabin derinliği
    hallRows: 11,                            // kabinlerin altındaki salon satırı
    sendHz: 10,                              // konumumu sunucuya yollama sıklığı
    net: { url: "https://kilit-sunucu.onrender.com" },   // varsayılan sunucu adresi (ws://… ya da wss://…); boşsa oyuncu girer
  },
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
