// Saf oyun mantığı: DOM yok, çizim yok. Node'da ve tarayıcıda aynı çalışır.
// Sabit adımlı step(g, dt, input). Çizim katmanı g'yi okur ve g.events'i boşaltır.
import { RULES } from "./rules.js";

export function rng(seed) {                      // mulberry32
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];

// ---------- Labirent ----------
function genMaze(n, rand) {
  const S = n * 2 + 1;
  const m = new Uint8Array(S * S).fill(1);
  const seen = new Uint8Array(n * n);
  const stack = [[0, 0]];
  seen[0] = 1;
  m[1 * S + 1] = 0;
  while (stack.length) {
    const [cx, cy] = stack[stack.length - 1];
    const opts = [];
    for (const [dx, dy] of DIRS) {
      const nx = cx + dx, ny = cy + dy;
      if (nx >= 0 && ny >= 0 && nx < n && ny < n && !seen[ny * n + nx]) opts.push([dx, dy, nx, ny]);
    }
    if (!opts.length) { stack.pop(); continue; }
    const [dx, dy, nx, ny] = opts[Math.floor(rand() * opts.length)];
    seen[ny * n + nx] = 1;
    m[(2 * cy + 1 + dy) * S + (2 * cx + 1 + dx)] = 0;
    m[(2 * ny + 1) * S + (2 * nx + 1)] = 0;
    stack.push([nx, ny]);
  }
  // Döngüler aç: donmuş bir gölge koridoru tıkamasın, kaçış yolu hep olsun
  let extra = Math.floor(n * n * 0.3);
  for (let tries = 0; extra > 0 && tries < 600; tries++) {
    const x = 1 + Math.floor(rand() * (S - 2));
    const y = 1 + Math.floor(rand() * (S - 2));
    if (m[y * S + x] !== 1 || (x + y) % 2 === 0) continue;
    const ok = x % 2 === 0
      ? m[y * S + x - 1] === 0 && m[y * S + x + 1] === 0
      : m[(y - 1) * S + x] === 0 && m[(y + 1) * S + x] === 0;
    if (ok) { m[y * S + x] = 0; extra--; }
  }
  return { map: m, S };
}

export function bfs(map, S, sx, sy) {
  const d = new Int16Array(S * S).fill(-1);
  const q = [sy * S + sx];
  d[q[0]] = 0;
  for (let i = 0; i < q.length; i++) {
    const c = q[i], x = c % S, y = (c / S) | 0;
    for (const [dx, dy] of DIRS) {
      const nx = x + dx, ny = y + dy, nc = ny * S + nx;
      if (nx < 0 || ny < 0 || nx >= S || ny >= S || map[nc] || d[nc] >= 0) continue;
      d[nc] = d[c] + 1;
      q.push(nc);
    }
  }
  return d;
}

function wallNeighbors(map, S, x, y) {
  const w = [];
  for (const [dx, dy] of DIRS) if (map[(y + dy) * S + (x + dx)]) w.push([dx, dy]);
  return w;
}

// ---------- Dünya kurulumu ----------
export function createGame(seed = 1, rules = RULES) {
  const R = rules;
  const rand = rng(seed);
  const { map, S } = genMaze(R.maze.cells, rand);
  const n = R.maze.cells;
  const distStart = bfs(map, S, 1, 1);
  const cells = [];
  for (let cy = 0; cy < n; cy++) for (let cx = 0; cx < n; cx++) cells.push([2 * cx + 1, 2 * cy + 1]);
  const shuffled = cells.slice().sort(() => rand() - 0.5);
  const used = [];                                    // doldurulmuş hücreler (üst üste binmesin)
  const taken = (x, y, r) => used.some(([ux, uy]) => Math.hypot(ux - x, uy - y) < r);
  const mark = (x, y) => used.push([x, y]);
  mark(1, 1);

  const types = Object.keys(R.enemies.types);
  const enemies = [];
  const addEnemy = (x, y) => {
    const type = types[enemies.length % types.length];
    enemies.push({ id: enemies.length, type, x: x + 0.5, y: y + 0.5, hp: R.enemies.types[type].hp, stun: 0, alive: true, respawn: 0,
      tx: 0, ty: 0, has: false, chase: false, yaw: rand() * 6.28, walk: rand() * 6, hit: 0 });
    mark(x, y);
  };
  for (const [x, y] of shuffled) {
    if (enemies.length >= R.enemies.count) break;
    if (distStart[y * S + x] < R.enemies.startMinDist) continue;
    if (enemies.some((e) => Math.hypot(e.x - (x + 0.5), e.y - (y + 0.5)) < 5)) continue;
    addEnemy(x, y);
  }
  for (const [x, y] of shuffled.slice().sort((a, b) => distStart[b[1] * S + b[0]] - distStart[a[1] * S + a[0]])) {
    if (enemies.length >= R.enemies.count) break;
    if (!enemies.some((e) => e.x === x + 0.5 && e.y === y + 0.5)) addEnemy(x, y);
  }

  const place = (count, minStart, spacing, mk, list) => {
    for (const [x, y] of shuffled) {
      if (list.length >= count) break;
      if (distStart[y * S + x] < minStart) continue;
      if (taken(x, y, spacing)) continue;
      list.push(mk(x + 0.5, y + 0.5)); mark(x, y);
    }
  };
  const flies = [];
  place(R.goal.flies, R.flies.minStartDist, R.flies.minSpacing, (x, y) => ({ x, y, taken: false, ph: rand() * 6 }), flies);
  for (const [x, y] of shuffled) {                    // yer bulunamazsa gevşet
    if (flies.length >= R.goal.flies) break;
    if (!flies.some((o) => o.x === x + 0.5 && o.y === y + 0.5) && distStart[y * S + x] >= 4) flies.push({ x: x + 0.5, y: y + 0.5, taken: false, ph: rand() * 6 });
  }
  const boxes = [];
  place(R.ammo.boxes, 3, 2.5, (x, y) => ({ x, y, taken: false, ph: rand() * 6 }), boxes);
  const gunItems = [];
  const foundList = R.weapons.found.slice();
  place(foundList.length, 5, 4, (x, y) => ({ x, y, taken: false, ph: rand() * 6, weapon: foundList[gunItems.length] }), gunItems);

  // Dekor
  const props = [];
  const wallKinds = Object.entries(R.props.wall);
  const wallTotal = wallKinds.reduce((a, [, w]) => a + w, 0);
  const pickKind = () => { let r = rand() * wallTotal; for (const [k, w] of wallKinds) { r -= w; if (r <= 0) return k; } return wallKinds[0][0]; };
  const deadEnds = [];
  for (let y = 1; y < S - 1; y++) for (let x = 1; x < S - 1; x++) {
    if (map[y * S + x]) continue;
    const wn = wallNeighbors(map, S, x, y);
    if (wn.length === 3 && distStart[y * S + x] >= R.props.minStartDist) deadEnds.push([x, y, wn]);
  }
  deadEnds.sort(() => rand() - 0.5);
  deadEnds.forEach(([x, y], i) => {
    if (taken(x, y, 0.5)) return;
    const kind = R.props.deadEnd[i % R.props.deadEnd.length];
    props.push({ kind, x: x + 0.5, y: y + 0.5, yaw: rand() * 6.28, big: true });
  });
  for (let y = 1; y < S - 1; y++) for (let x = 1; x < S - 1; x++) {
    if (map[y * S + x] || distStart[y * S + x] < R.props.minStartDist) continue;
    if (rand() > R.props.density) continue;
    if (props.some((p) => Math.hypot(p.x - x - 0.5, p.y - y - 0.5) < 0.6)) continue;
    const wn = wallNeighbors(map, S, x, y);
    if (!wn.length) continue;
    const [dx, dy] = wn[Math.floor(rand() * wn.length)];
    const along = (rand() - 0.5) * 0.4;
    const kind = pickKind();
    props.push({ kind, x: x + 0.5 + dx * 0.33 + (dy ? along : 0), y: y + 0.5 + dy * 0.33 + (dx ? along : 0), yaw: Math.atan2(-dy, -dx) + (rand() - 0.5) * 0.8 });
  }
  const lights = props.filter((p) => R.props.lights[p.kind]).map((p) => ({ x: p.x, y: p.y, ...R.props.lights[p.kind] }));

  let yaw = 0;
  if (map[1 * S + 2] === 0) yaw = 0; else if (map[2 * S + 1] === 0) yaw = Math.PI / 2;

  return {
    rules: R, seed, rand, map, S, distStart,
    px: 1.5, py: 1.5, yaw, bob: 0, moving: 0,
    enemies, flies, boxes, gunItems, props, lights, players: [],      // players: diğer oyuncular (çok oyunculu için), {id,name,x,y,yaw,walk,moving}
    shells: R.ammo.start, owned: [R.weapons.start], cur: R.weapons.start, cooldown: 0, recoil: 0, flash: 0,
    slot: "gun", sw: null, raise: 1, lightOn: false, flashModel: R.flashlight.models[seed % R.flashlight.models.length],   // elde: silah ya da fener; sw = geçiş animasyonu
    collected: 0, time: 0, kills: 0, shots: 0, hits: 0,
    eyesClosed: false, forced: 0, dry: 0, danger: 0,
    state: "play", killer: -1, events: [],
  };
}

// Çok oyunculu için: diğer oyuncuyu dünyaya ekler/günceller (sim hareketini ağ katmanı sürer)
export function setPlayer(g, p) {
  const i = g.players.findIndex((q) => q.id === p.id);
  if (i >= 0) Object.assign(g.players[i], p); else g.players.push({ yaw: 0, walk: 0, moving: 0, ...p });
}

// ---------- Yardımcılar ----------
export function blocked(g, x, y, r) {
  const m = g.map, S = g.S;
  return m[((y - r) | 0) * S + ((x - r) | 0)] || m[((y - r) | 0) * S + ((x + r) | 0)] ||
         m[((y + r) | 0) * S + ((x - r) | 0)] || m[((y + r) | 0) * S + ((x + r) | 0)];
}

// (x,y)'den (dx,dy) yönüne duvara kadar uzaklık (DDA)
export function rayWall(g, x, y, dx, dy, maxD = 30) {
  const S = g.S, map = g.map;
  let mx = x | 0, my = y | 0;
  const ddx = dx === 0 ? 1e30 : Math.abs(1 / dx), ddy = dy === 0 ? 1e30 : Math.abs(1 / dy);
  let sx, sy, sdx, sdy;
  if (dx < 0) { sx = -1; sdx = (x - mx) * ddx; } else { sx = 1; sdx = (mx + 1 - x) * ddx; }
  if (dy < 0) { sy = -1; sdy = (y - my) * ddy; } else { sy = 1; sdy = (my + 1 - y) * ddy; }
  let d = 0;
  for (let i = 0; i < 80; i++) {
    if (sdx < sdy) { d = sdx; sdx += ddx; mx += sx; } else { d = sdy; sdy += ddy; my += sy; }
    if (mx < 0 || my < 0 || mx >= S || my >= S || map[my * S + mx]) return Math.min(d, maxD);
    if (d > maxD) return maxD;
  }
  return maxD;
}

export function hasLine(g, ax, ay, bx, by) {
  const d = Math.hypot(bx - ax, by - ay);
  if (d < 1e-6) return true;
  return rayWall(g, ax, ay, (bx - ax) / d, (by - ay) / d, d + 1) >= d - 1e-3;
}

export function nearestEnemyDist(g) {
  let nearest = 99;
  for (const e of g.enemies) if (e.alive) nearest = Math.min(nearest, Math.hypot(e.x - g.px, e.y - g.py));
  return nearest;
}

function emit(g, e) { g.events.push(e); }

// ---------- Oyuncu ----------
export function movePlayer(g, dt, input) {
  const R = g.rules.player;
  g.yaw += (input.yaw || 0) + (input.turn || 0) * dt;
  let fwd = input.fwd || 0, str = input.str || 0;
  const len = Math.hypot(fwd, str);
  if (len > 1) { fwd /= len; str /= len; }
  const dirX = Math.cos(g.yaw), dirY = Math.sin(g.yaw);
  const vx = (dirX * fwd - dirY * str) * R.speed * dt;
  const vy = (dirY * fwd + dirX * str) * R.speed * dt;
  g.moving = Math.min(1, len);
  if (vx || vy) {
    if (!blocked(g, g.px + vx, g.py, R.radius)) g.px += vx;
    if (!blocked(g, g.px, g.py + vy, R.radius)) g.py += vy;
    g.bob += dt * 9 * g.moving;
  }
}

function updateEyes(g, dt, input) {
  const E = g.rules.eyes;
  if (g.forced > 0) g.forced -= dt;
  const closed = !!input.eyes || g.forced > 0;
  if (!closed) {
    g.dry += dt;
    if (g.dry >= E.dryMax) { g.forced = E.forcedBlink; g.dry = 0; emit(g, { t: "forcedBlink" }); }
  } else if (g.forced <= 0) {
    g.dry = Math.max(0, g.dry - dt * E.recover);
  }
  const now = !!input.eyes || g.forced > 0;
  if (now !== g.eyesClosed) { g.eyesClosed = now; emit(g, { t: now ? "close" : "open" }); }
}

// ---------- Düşmanlar ----------
export function enemySpeed(g, e) {
  const E = g.rules.enemies;
  let v = (E.baseSpeed + E.speedPerFly * g.collected) * E.types[e.type].speed;
  if (g.lightOn) {                                   // fener yanıkken menzildeki gölgeler ışığa koşar
    const F = g.rules.flashlight;
    if (Math.hypot(e.x - g.px, e.y - g.py) < F.range && hasLine(g, g.px, g.py, e.x, e.y)) v *= F.enemyBoost;
  }
  return v;
}

function moveEnemy(g, e, dt, dist) {
  let step = enemySpeed(g, e) * dt;
  const S = g.S, pcx = g.px | 0, pcy = g.py | 0;
  const ox = e.x, oy = e.y;
  for (let guard = 0; step > 1e-5 && guard < 6; guard++) {
    if (!e.has) {
      const cx = e.x | 0, cy = e.y | 0;
      if (cx === pcx && cy === pcy) { e.tx = g.px; e.ty = g.py; e.chase = true; e.has = true; }
      else {
        let best = dist[cy * S + cx], bx = cx, by = cy;
        for (const [dx, dy] of DIRS) {
          const nx = cx + dx, ny = cy + dy, nd = dist[ny * S + nx];
          if (nd >= 0 && !g.map[ny * S + nx] && nd < best) { best = nd; bx = nx; by = ny; }
        }
        if (bx === cx && by === cy) break;
        e.tx = bx + 0.5; e.ty = by + 0.5; e.chase = false; e.has = true;
      }
    }
    if (e.chase) { e.tx = g.px; e.ty = g.py; }
    const dx = e.tx - e.x, dy = e.ty - e.y, d = Math.hypot(dx, dy);
    if (d <= step) { e.x = e.tx; e.y = e.ty; step -= d; e.has = false; if (e.chase) break; }
    else { e.x += (dx / d) * step; e.y += (dy / d) * step; step = 0; }
  }
  const mvx = e.x - ox, mvy = e.y - oy, md = Math.hypot(mvx, mvy);
  if (md > 1e-4) { e.yaw = Math.atan2(mvy, mvx); e.walk += md * 5; }
}

function respawnEnemy(g, e) {
  const R = g.rules.enemies, S = g.S;
  const dist = bfs(g.map, S, g.px | 0, g.py | 0);
  const far = [];
  let best = null;
  for (let y = 1; y < S - 1; y += 2) for (let x = 1; x < S - 1; x += 2) {
    const d = dist[y * S + x];
    if (d < 0) continue;
    if (!best || d > best.d) best = { x, y, d };
    if (d >= R.respawnMinDist) far.push({ x, y });
  }
  const c = far.length ? far[Math.floor(g.rand() * far.length)] : best;
  e.x = c.x + 0.5; e.y = c.y + 0.5; e.hp = R.types[e.type].hp; e.stun = 0.8; e.alive = true; e.has = false; e.chase = false;
  emit(g, { t: "respawn", id: e.id });
}

// ---------- Silah ----------
export function weaponDef(g) { return g.rules.weapons[g.cur]; }

function fire(g) {
  const W = weaponDef(g);
  if (g.cooldown > 0 || g.state !== "play" || g.slot !== "gun" || g.sw) return;   // fener elindeyken ya da geçiş sırasında ateş yok
  if (g.shells < W.shells) { if (!g.dryClick || g.dryClick <= 0) { emit(g, { t: "empty" }); g.dryClick = 0.4; } return; }
  g.shells -= W.shells;
  g.cooldown = W.cooldown;
  g.recoil = 1; g.flash = 1; g.shots++;
  emit(g, { t: "fire", weapon: g.cur });
  const hitsBy = new Map();
  for (let p = 0; p < W.pellets; p++) {
    const a = g.yaw + (g.rand() + g.rand() - 1) * W.spread;
    const dx = Math.cos(a), dy = Math.sin(a);
    const wd = Math.min(W.range, rayWall(g, g.px, g.py, dx, dy, W.range));
    let best = null;
    for (const e of g.enemies) {
      if (!e.alive) continue;
      const rx = e.x - g.px, ry = e.y - g.py;
      const t = rx * dx + ry * dy;
      if (t < 0.1 || t > wd) continue;
      const off = Math.abs(rx * -dy + ry * dx);
      if (off < g.rules.enemies.types[e.type].radius && (!best || t < best.t)) best = { e, t };
    }
    if (best) hitsBy.set(best.e, (hitsBy.get(best.e) || 0) + W.damage);
  }
  for (const [e, dmg] of hitsBy) {
    e.hp -= dmg; e.hit = 1; g.hits++;
    e.stun = g.rules.enemies.stunSec;
    // geri savrul
    const rx = e.x - g.px, ry = e.y - g.py, d = Math.hypot(rx, ry) || 1;
    const nx = e.x + (rx / d) * g.rules.enemies.knockback, ny = e.y + (ry / d) * g.rules.enemies.knockback;
    if (!blocked(g, nx, ny, 0.25)) { e.x = nx; e.y = ny; e.has = false; e.chase = false; }
    if (e.hp <= 0.0001) {
      e.alive = false; e.respawn = g.rules.enemies.respawnSec; g.kills++;
      emit(g, { t: "kill", id: e.id, x: e.x, y: e.y });
    } else emit(g, { t: "hit", id: e.id, x: e.x, y: e.y, dmg });
  }
}

const ease = (x) => x * x * (3 - 2 * x);
// Geçiş: eski eşya iner (yarı süre), değişir, yenisi kalkar. to: { slot: "gun", weapon } ya da { slot: "light" }
function beginSwitch(g, to) {
  if (g.sw) return;
  if (to.slot === g.slot && (to.slot === "light" || to.weapon === g.cur)) return;
  g.sw = { t: 0, to, applied: false };
  emit(g, { t: "switchStart", slot: to.slot });
}
function updateSwitch(g, dt) {
  const sw = g.sw, S = g.rules.switch.seconds;
  if (!sw) { g.raise = 1; g.lightOn = g.slot === "light"; return; }
  sw.t += dt;
  if (!sw.applied && sw.t >= S / 2) {
    sw.applied = true; g.slot = sw.to.slot;
    if (sw.to.slot === "gun") { g.cur = sw.to.weapon; g.cooldown = Math.max(g.cooldown, 0.2); emit(g, { t: "switch", weapon: g.cur }); }
    else emit(g, { t: "lightSlot" });
  }
  if (sw.t >= S) { g.sw = null; g.raise = 1; }
  else { const p = sw.t / S; g.raise = p < 0.5 ? 1 - ease(p * 2) : ease((p - 0.5) * 2); }
  g.lightOn = g.slot === "light" && g.raise > 0.45;
}
function switchWeapon(g) {                           // R / SİLAH DEĞİŞ: fenerdeyken silaha döner, değilse sıradaki silaha geçer
  if (g.sw) return;
  if (g.slot === "light") return beginSwitch(g, { slot: "gun", weapon: g.cur });
  if (g.owned.length < 2) return;
  const i = g.owned.indexOf(g.cur);
  beginSwitch(g, { slot: "gun", weapon: g.owned[(i + 1) % g.owned.length] });
}
function toggleLight(g) {
  if (g.sw) return;
  beginSwitch(g, g.slot === "light" ? { slot: "gun", weapon: g.cur } : { slot: "light" });
}

// ---------- Ana adım ----------
export function step(g, dt, input = {}) {
  if (g.state !== "play") return;
  g.time += dt;
  g.cooldown = Math.max(0, g.cooldown - dt);
  g.recoil = Math.max(0, g.recoil - dt * 3.2);
  g.flash = Math.max(0, g.flash - dt * 9);
  g.dryClick = Math.max(0, (g.dryClick || 0) - dt);

  updateEyes(g, dt, input);
  movePlayer(g, dt, input);
  updateSwitch(g, dt);
  if (input.switchWeapon) switchWeapon(g);
  if (input.light) toggleLight(g);
  if (input.fire) fire(g);

  // Gölgeler yalnızca gözler KAPALIYKEN ilerler
  if (g.eyesClosed) {
    const dist = bfs(g.map, g.S, g.px | 0, g.py | 0);
    for (const e of g.enemies) if (e.alive && e.stun <= 0) moveEnemy(g, e, dt, dist);
    g.stepT = (g.stepT || 0) - dt;
    if (g.stepT <= 0) { g.stepT = 0.32; emit(g, { t: "step", near: nearestEnemyDist(g) }); }
  }
  for (const e of g.enemies) {
    if (e.stun > 0) e.stun = Math.max(0, e.stun - dt);
    if (e.hit > 0) e.hit = Math.max(0, e.hit - dt * 5);
    if (!e.alive) { e.respawn -= dt; if (e.respawn <= 0) respawnEnemy(g, e); }
  }
  // Oyuncuya dönük bakış: göz kapalıyken yönü oyuncuya çevir (donmuşken pozu korur)
  g.danger = Math.max(0, Math.min(1, 1 - nearestEnemyDist(g) / g.rules.danger.range));

  // Toplananlar
  for (const o of g.flies) if (!o.taken && Math.hypot(o.x - g.px, o.y - g.py) < g.rules.flies.pickupRadius) {
    o.taken = true; g.collected++;
    emit(g, { t: "fly", n: g.collected });
    if (g.collected >= g.rules.goal.flies) { g.state = "won"; emit(g, { t: "win" }); return; }
  }
  for (const o of g.boxes) if (!o.taken && Math.hypot(o.x - g.px, o.y - g.py) < g.rules.ammo.pickupRadius && g.shells < g.rules.ammo.max) {
    o.taken = true; g.shells = Math.min(g.rules.ammo.max, g.shells + g.rules.ammo.perBox);
    emit(g, { t: "ammo", n: g.shells });
  }
  for (const o of g.gunItems) if (!o.taken && Math.hypot(o.x - g.px, o.y - g.py) < g.rules.weapons.pickupRadius) {
    o.taken = true;
    if (!g.owned.includes(o.weapon)) g.owned.push(o.weapon);
    g.cur = o.weapon; g.slot = "gun"; g.sw = null; g.raise = 1; g.lightOn = false;
    emit(g, { t: "gun", weapon: o.weapon });
  }
  // Yakalanma
  for (const e of g.enemies) {
    if (e.alive && Math.hypot(e.x - g.px, e.y - g.py) < g.rules.enemies.catchDist) {
      g.state = "dead"; g.killer = e.id; emit(g, { t: "caught", id: e.id }); return;
    }
  }
}
