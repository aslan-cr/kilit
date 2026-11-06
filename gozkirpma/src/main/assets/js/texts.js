// Oyuncuya gösterilen her sayı ya da iddia rules.js'ten üretilir. Bunlar birer SÖZdür:
// test/promises.test.mjs her sözün gerçekten doğru olduğunu sim ile kontrol eder.
import { RULES } from "./rules.js";

export function ruleLines(R = RULES) {
  const w = R.weapons;
  return [
    "<b>Gözlerin açıkken</b> gölgeler donar, kıpırdayamaz.",
    "<b>Gözünü kapattığın an</b> yalnızca onlar hareket eder ve sana gelir.",
    `Gözlerini ${R.eyes.dryMax} sn'den uzun açık tutarsan göz <b>kendiliğinden kapanır</b>; ${R.eyes.dryWarn} sn'den sonra görüş kararır.`,
    `${R.goal.flies} ışık böceğini (🪰) topla, hayatta kal.`,
    `Pompalı tüfekle başlarsın, ${R.ammo.start} mermin var. Mermi kutusu +${R.ammo.perBox} mermi verir (en fazla ${R.ammo.max}).`,
    `Vurulan gölge ${R.enemies.stunSec} sn kıpırdayamaz; ölen gölge ${R.enemies.respawnSec} sn sonra uzakta yeniden doğar.`,
    `Labirentte ${w.found.length} silah daha var: ${w.found.map((k) => w[k].name).join(", ")}.`,
    "Sol yarı ekran: hareket. Sağ yarı ekran: sadece etrafa bakma (kısa dokunuş = ateş).",
  ];
}

export const HINT_FIRST = "Gözlerin açıkken gölgeler donar. Kırptığın an gelirler.";
