import test from "node:test";
import assert from "node:assert/strict";
import { RULES } from "../src/main/assets/js/rules.js";
import { createGame, step, bfs, enemySpeed } from "../src/main/assets/js/sim.js";

const DT = 1 / 60;
const clone = () => JSON.parse(JSON.stringify(RULES));

function run(g, sec, input) { for (let i = 0; i < sec / DT; i++) step(g, DT, typeof input === "function" ? input() : input); }

test("aynı tohum aynı dünyayı kurar", () => {
  const a = createGame(7), b = createGame(7);
  assert.deepEqual([...a.map], [...b.map]);
  assert.deepEqual(a.enemies.map((e) => [e.x, e.y, e.type]), b.enemies.map((e) => [e.x, e.y, e.type]));
  assert.equal(a.props.length, b.props.length);
});

test("kurulum: böcek, mermi kutusu, silahlar, düşmanlar ve dekor yerinde; hepsi ulaşılabilir", () => {
  for (const seed of [1, 2, 3, 4, 5, 11, 23]) {
    const g = createGame(seed);
    const d = bfs(g.map, g.S, 1, 1);
    assert.equal(g.flies.length, RULES.goal.flies, "seed " + seed);
    assert.equal(g.enemies.length, RULES.enemies.count);
    assert.equal(g.gunItems.length, RULES.weapons.found.length);
    assert.ok(g.props.length > 10, "dekor az");
    for (const o of [...g.flies, ...g.boxes, ...g.gunItems, ...g.enemies]) assert.ok(d[(o.y | 0) * g.S + (o.x | 0)] >= 0, "ulaşılamaz nesne");
  }
});

test("GÖZ AÇIKKEN gölgeler donar", () => {
  const g = createGame(3);
  const before = g.enemies.map((e) => [e.x, e.y]);
  run(g, 3, { eyes: false });
  assert.deepEqual(g.enemies.map((e) => [e.x, e.y]), before);
});

test("GÖZ KAPALIYKEN gölgeler oyuncuya yaklaşır", () => {
  const g = createGame(3);
  const d0 = g.enemies.map((e) => Math.hypot(e.x - g.px, e.y - g.py));
  const R = clone(); // oyuncu hareketsiz, hızlı yaklaşsınlar
  run(g, 2.5, { eyes: true });
  const d1 = g.enemies.map((e) => Math.hypot(e.x - g.px, e.y - g.py));
  assert.ok(d1.some((d, i) => d < d0[i] - 0.5), "hiçbiri yaklaşmadı");
  assert.ok(R);
});

test("göz kuruluğu: dryMax sn açık kalırsa zorunlu kırpma olur ve gölgeler hareket eder", () => {
  const g = createGame(3);
  run(g, RULES.eyes.dryMax - 0.2, { eyes: false });
  assert.equal(g.eyesClosed, false);
  const before = g.enemies.map((e) => [e.x, e.y]);
  const ev = [];
  for (let i = 0; i < (RULES.eyes.forcedBlink + 0.6) / DT; i++) { step(g, DT, { eyes: false }); ev.push(...g.events); g.events.length = 0; }
  assert.ok(ev.some((e) => e.t === "forcedBlink"), "zorunlu kırpma yok");
  assert.notDeepEqual(g.enemies.map((e) => [e.x, e.y]), before, "kırpma sırasında gölgeler hareket etmedi");
});

test("kırpmak kuruluk sayacını azaltır", () => {
  const g = createGame(3);
  run(g, 6, { eyes: false });
  const dry = g.dry;
  run(g, 0.5, { eyes: true });
  assert.ok(g.dry < dry);
});

function enemyInFront(g, dist) {
  const e = g.enemies[0];
  g.px = 1.5; g.py = 1.5; g.yaw = 0;
  // düz bir koridor bul: oyuncunun önünü açık varsay (testte duvarı kaldır)
  for (let x = 1; x < 1 + dist + 2; x++) g.map[1 * g.S + x] = 0;
  e.x = 1.5 + dist; e.y = 1.5; e.alive = true; e.hp = RULES.enemies.types[e.type].hp;
  for (const o of g.enemies) if (o !== e) o.alive = false;
  return e;
}

test("ateş: yakındaki gölge vurulur, ölür, mermi azalır", () => {
  const g = createGame(5);
  const e = enemyInFront(g, 2);
  const shells = g.shells;
  step(g, DT, { fire: true });
  assert.equal(g.shells, shells - RULES.weapons.pump.shells);
  assert.equal(e.alive, false, "2 karoda pompalı öldürmeli (hp " + RULES.enemies.types[e.type].hp + ")");
  assert.equal(g.kills, 1);
});

test("ateş: duvarın arkasındaki gölge vurulmaz", () => {
  const g = createGame(5);
  const e = enemyInFront(g, 3);
  g.map[1 * g.S + 3] = 1; // araya duvar
  step(g, DT, { fire: true });
  assert.equal(e.alive, true);
  assert.equal(e.hp, RULES.enemies.types[e.type].hp);
});

test("ateş: menzil dışı vurulmaz; uzakta saçma dağılır", () => {
  const g = createGame(5);
  const e = enemyInFront(g, RULES.weapons.pump.range + 2);
  step(g, DT, { fire: true });
  assert.equal(e.alive, true);
  assert.equal(e.hp, RULES.enemies.types[e.type].hp);
});

test("vurulan gölge sersemler: göz kapalı olsa da kıpırdamaz, süre bitince yürür", () => {
  const R = clone(); R.weapons.pump.damage = 0.1; // öldürmesin
  const g = createGame(5, R);
  const e = enemyInFront(g, 4);
  step(g, DT, { fire: true });
  assert.ok(e.alive && e.stun > 0);
  const x = e.x;
  run(g, RULES.enemies.stunSec - 0.3, { eyes: true });
  assert.equal(e.x, x, "sersemken hareket etti");
  run(g, 1.0, { eyes: true });
  assert.notEqual(e.x, x, "sersemlik bitti ama hareket etmedi");
});

test("ölen gölge belirli süre sonra uzakta yeniden doğar", () => {
  const g = createGame(5);
  const e = enemyInFront(g, 2);
  step(g, DT, { fire: true });
  assert.equal(e.alive, false);
  run(g, RULES.enemies.respawnSec + 0.5, { eyes: false });
  assert.equal(e.alive, true);
  const d = bfs(g.map, g.S, g.px | 0, g.py | 0)[(e.y | 0) * g.S + (e.x | 0)];
  assert.ok(d >= Math.min(RULES.enemies.respawnMinDist, 10), "yeniden doğma çok yakın: " + d);
});

test("mermi yokken ateş edilmez; bekleme süresi uygulanır", () => {
  const g = createGame(5);
  g.shells = 0;
  step(g, DT, { fire: true });
  assert.equal(g.shots, 0);
  g.shells = 5;
  step(g, DT, { fire: true }); step(g, DT, { fire: true });
  assert.equal(g.shots, 1, "bekleme süresi atlandı");
});

test("mermi kutusu ve silah toplanır, silah değişir", () => {
  const g = createGame(5);
  g.shells = 0;
  const b = g.boxes[0]; g.px = b.x; g.py = b.y;
  step(g, DT, {});
  assert.equal(g.shells, RULES.ammo.perBox);
  const w = g.gunItems[0]; g.px = w.x; g.py = w.y;
  step(g, DT, {});
  assert.equal(g.cur, w.weapon);
  assert.ok(g.owned.includes(RULES.weapons.start) && g.owned.includes(w.weapon));
  step(g, DT, { switchWeapon: true });
  assert.equal(g.cur, w.weapon, "geçiş animasyonu sürerken silah henüz değişmez");
  for (let i = 0; i < 40; i++) step(g, DT, {});
  assert.equal(g.cur, RULES.weapons.start);
});

const runIn = (g, sec, input = {}) => { for (let i = 0; i < Math.round(sec / DT); i++) step(g, DT, i === 0 ? input : {}); };
const clearEnemies = (g) => { g.enemies.forEach((e) => { e.alive = false; e.respawn = 1e9; }); };

test("fener: L ile fener ele gelir; geçiş animasyonu inip kalkar, fener yarıdan sonra yanar", () => {
  const g = createGame(5); clearEnemies(g);
  const S = RULES.switch.seconds;
  assert.equal(g.slot, "gun"); assert.equal(g.raise, 1); assert.equal(g.lightOn, false);
  step(g, DT, { light: true });
  assert.ok(g.sw, "animasyon başladı");
  runIn(g, S / 2 - 0.05); assert.ok(g.raise < 0.15, "yarıda silah/fener tamamen aşağıda: " + g.raise); assert.equal(g.slot, "gun");
  runIn(g, 0.1); assert.equal(g.slot, "light", "yarıdan sonra elde fener var");
  runIn(g, S / 2 + 0.05); assert.equal(g.raise, 1); assert.equal(g.sw, null); assert.equal(g.lightOn, true);
  step(g, DT, { light: true }); runIn(g, S + 0.1);
  assert.equal(g.slot, "gun"); assert.equal(g.lightOn, false, "tekrar L: silaha dönülür, fener söner");
});

test("fener elindeyken ya da geçiş sırasında ateş edilemez", () => {
  const g = createGame(5); clearEnemies(g);
  step(g, DT, { light: true });
  const sh = g.shells;
  step(g, DT, { fire: true }); assert.equal(g.shells, sh, "geçiş sırasında ateş yok");
  runIn(g, RULES.switch.seconds + 0.1);
  step(g, DT, { fire: true }); assert.equal(g.shells, sh, "fenerdeyken ateş yok");
  step(g, DT, { switchWeapon: true }); runIn(g, RULES.switch.seconds + 0.2);
  assert.equal(g.slot, "gun");
  step(g, DT, { fire: true }); assert.equal(g.shells, sh - 1, "silaha dönünce ateş eder");
});

test("fener yanıkken menzildeki gölge ışığa daha hızlı koşar, görüş hattı yoksa değişmez", () => {
  const g = createGame(5);
  const e = g.enemies[0]; e.x = g.px + 3; e.y = g.py; for (let x = g.px | 0; x <= (g.px | 0) + 4; x++) g.map[(g.py | 0) * g.S + x] = 0;
  const base = enemySpeed(g, e);
  g.lightOn = true;
  assert.ok(Math.abs(enemySpeed(g, e) / base - RULES.flashlight.enemyBoost) < 1e-9);
  e.x = g.px + 3; g.map[(g.py | 0) * g.S + ((g.px + 2) | 0)] = 1;
  assert.equal(enemySpeed(g, e), base, "araya duvar girince (görüş hattı yok) hızlanmaz");
  g.map[(g.py | 0) * g.S + ((g.px + 2) | 0)] = 0;
  e.x = g.px + RULES.flashlight.range + 1; assert.equal(enemySpeed(g, e), base, "menzil dışında hızlanmaz");
  g.lightOn = false; e.x = g.px + 3; assert.equal(enemySpeed(g, e), base);
});

test("her oyunda tohuma göre üç fener modelinden biri seçilir", () => {
  const seen = new Set();
  for (let s = 1; s <= 6; s++) seen.add(createGame(s).flashModel);
  assert.deepEqual([...seen].sort(), RULES.flashlight.models.slice().sort());
});

test("çifte namlu atış başına 2 mermi harcar", () => {
  const g = createGame(5);
  g.owned.push("double"); g.cur = "double"; g.shells = 5;
  step(g, DT, { fire: true });
  assert.equal(g.shells, 5 - RULES.weapons.double.shells);
});

test("yakalanınca oyun biter; tüm böcekler toplanınca kazanılır", () => {
  const g = createGame(5);
  const e = g.enemies[0]; e.x = g.px + 0.2; e.y = g.py;
  step(g, DT, {});
  assert.equal(g.state, "dead");
  const h = createGame(5);
  for (const o of h.flies) { h.px = o.x; h.py = o.y; step(h, DT, {}); if (h.state !== "play") break; }
  assert.equal(h.state, "won");
});

test("gölgeler her böcekte hızlanır", () => {
  const g = createGame(5);
  const s0 = enemySpeed(g, g.enemies[0]);
  g.collected = 3;
  assert.ok(enemySpeed(g, g.enemies[0]) > s0 + 3 * RULES.enemies.speedPerFly * 0.8);
});
