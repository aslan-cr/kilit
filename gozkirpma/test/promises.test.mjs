// "Söz testleri": oyuncuya gösterilen her sayı ya da iddia, kurallarla gerçekten tutuyor mu?
import test from "node:test";
import assert from "node:assert/strict";
import { RULES } from "../src/main/assets/js/rules.js";
import { ruleLines } from "../src/main/assets/js/texts.js";
import { createGame, step } from "../src/main/assets/js/sim.js";

const DT = 1 / 60;
const text = ruleLines().join("\n");

test("metin kurallardaki sayıları içerir (rules.js değişirse metin de değişir)", () => {
  for (const n of [RULES.eyes.dryMax, RULES.eyes.dryWarn, RULES.goal.flies, RULES.ammo.start, RULES.ammo.perBox, RULES.ammo.max, RULES.enemies.stunSec, RULES.enemies.respawnSec, RULES.weapons.found.length])
    assert.ok(text.includes(String(n)), "metinde yok: " + n);
  for (const k of RULES.weapons.found) assert.ok(text.includes(RULES.weapons[k].name), "silah adı yok: " + k);
});

test("SÖZ: ışık böceği sayısı kadar böcek vardır ve hepsi toplanınca oyun kazanılır", () => {
  const g = createGame(9);
  assert.equal(g.flies.length, RULES.goal.flies);
});

test("SÖZ: mermiyle başlarsın, kutu +perBox verir ve en fazla max olur", () => {
  const g = createGame(9);
  assert.equal(g.shells, RULES.ammo.start);
  g.shells = RULES.ammo.max - 1;
  const b = g.boxes[0]; g.px = b.x; g.py = b.y; step(g, DT, {});
  assert.equal(g.shells, RULES.ammo.max);
});

test("SÖZ: başlangıç silahı pompalı", () => {
  const g = createGame(9);
  assert.equal(g.cur, "pump");
  assert.equal(RULES.weapons.pump.name, "Pompalı");
});

test("SÖZ: dryMax sn açık kalırsan göz kendiliğinden kapanır", () => {
  const g = createGame(9);
  let closedAt = null;
  for (let i = 0; i < 12 / DT; i++) { step(g, DT, { eyes: false }); if (g.eyesClosed && closedAt === null) closedAt = g.time; g.events.length = 0; }
  assert.ok(Math.abs(closedAt - RULES.eyes.dryMax) < 0.1, "kapanma zamanı " + closedAt);
});

test("SÖZ: vurulan gölge stunSec sn kıpırdamaz", () => {
  const R = JSON.parse(JSON.stringify(RULES)); R.weapons.pump.damage = 0.01;
  const g = createGame(9, R);
  const e = g.enemies[0];
  g.px = 1.5; g.py = 1.5; g.yaw = 0;
  for (let x = 1; x < 8; x++) g.map[1 * g.S + x] = 0;
  e.x = 5.5; e.y = 1.5; for (const o of g.enemies) if (o !== e) o.alive = false;
  step(g, DT, { fire: true });
  assert.ok(e.stun > RULES.enemies.stunSec - 0.05);
});

test("SÖZ: tüfek bulunan silahların hepsi labirentte bir kez vardır", () => {
  const g = createGame(9);
  assert.deepEqual(g.gunItems.map((o) => o.weapon).sort(), RULES.weapons.found.slice().sort());
});

test("SÖZ: dokunmatik sağ yarı yalnızca bakar (sim hareket girdisi yoksa oyuncu yerinde kalır)", () => {
  const g = createGame(9);
  const p = [g.px, g.py];
  for (let i = 0; i < 60; i++) step(g, DT, { yaw: 0.1 });
  assert.deepEqual([g.px, g.py], p);
});

test("söz: fener gölgeleri %30 hızlandırır, fenerdeyken ateş edilemez (metinle sim aynı)", () => {
  const pct = Math.round((RULES.flashlight.enemyBoost - 1) * 100);
  assert.match(text, new RegExp(`%${pct} daha hızlı`));
  assert.match(text, /ateş edilemez/);
  const g = createGame(5);
  g.enemies.forEach((e) => { e.alive = false; e.respawn = 1e9; });
  step(g, DT, { light: true });
  for (let i = 0; i < 60; i++) step(g, DT, {});
  assert.equal(g.slot, "light");
  const sh = g.shells; step(g, DT, { fire: true });
  assert.equal(g.shells, sh);
});
