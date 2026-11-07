// Lobi sahnesi: kuzeyde 4 kabin (oda kurma yeri), altında ortak salon. Oyun dünyasıyla aynı şekle sahiptir,
// böylece aynı çizici (render.js) ve aynı hareket kodu kullanılır. Saf mantık, DOM yok.
import { createGame, movePlayer } from "./sim.js";
import { cabin, roomAt, spawnPoint } from "./rooms.js";

export function createLobby(rules, seed = 7) {
  const R = rules, L = R.lobby, S = L.size;
  const g = createGame(seed, R);
  const map = new Uint8Array(S * S);
  const hallEnd = 1 + L.cubDepth + L.hallRows;                  // salonun son satırı (hariç)
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const border = x === 0 || y === 0 || x === S - 1 || y >= hallEnd;
    let wall = border;
    if (!border && y >= 1 && y < 1 + L.cubDepth) {                // kabinler arası bölme duvarları
      let inCab = false;
      for (let i = 0; i < L.rooms; i++) { const c = cabin(R, i); if (x >= c.x0 && x < c.x1) inCab = true; }
      if (!inCab) wall = true;
    }
    map[y * S + x] = wall ? 1 : 0;
  }
  // Salonda birkaç sütun
  for (const [x, y] of [[6, 9], [13, 9], [20, 9], [6, 13], [13, 13], [20, 13]]) map[y * S + x] = 1;

  const props = [], lights = [], signs = [];
  const add = (kind, x, y, yaw = 0) => { props.push({ kind, x, y, yaw }); if (R.props.lights[kind]) lights.push({ x, y, ...R.props.lights[kind] }); };
  for (let i = 0; i < L.rooms; i++) {
    const c = cabin(R, i);
    add("candleBundle", c.x0 + 0.5, c.y0 + 0.5, 0.7); add("candleBundle", c.x1 - 0.5, c.y0 + 0.5, 2.1);
    add("jackolantern_small", c.x0 + 0.5, c.y1 - 0.5, 0.4); add("jackolantern_small", c.x1 - 0.5, c.y1 - 0.5, -0.4);
    add("cauldron", c.cx, c.y0 + 0.9, 0);
    lights.push({ x: c.cx, y: c.cy, c: [1.0, 0.75, 0.4], r: 3.4, k: 1.0 });
    signs.push({ x: c.cx, y: c.y1 - 0.3, z: 0.86, room: i });
  }
  const hy0 = 1 + L.cubDepth;
  for (const [x, y, k] of [[2, hy0 + 1, "lampPost"], [S - 3, hy0 + 1, "lampPost"], [2, hallEnd - 2, "lampPost"], [S - 3, hallEnd - 2, "lampPost"]]) add(k, x + 0.5, y + 0.5);
  for (const [x, y, k] of [[1.6, hy0 + 5, "gravestone"], [S - 2.6, hy0 + 5, "gravestone"], [S / 2, hallEnd - 1.5, "shrine"], [9, hallEnd - 1.5, "candleLarge"], [17, hallEnd - 1.5, "candleLarge"], [4, hallEnd - 1.4, "pumpkinLarge"], [22, hallEnd - 1.4, "pumpkinLarge"]]) add(k, x, y, 3);

  const sp = spawnPoint(R, 0);
  Object.assign(g, { map, S, props, lights, signs, enemies: [], flies: [], boxes: [], gunItems: [], players: [], px: sp.x, py: sp.y, yaw: -Math.PI / 2, state: "lobby",
    rooms: Array.from({ length: L.rooms }, () => ({ n: 0, st: "open", host: null })), myRoom: -1, myId: null, lobbyEvents: [] });
  return g;
}

// input: { fwd, str, yaw, turn }. Dolu/oyundaki kabine girişi engellenir (sunucu da aynısını yapar).
export function stepLobby(g, dt, input = {}) {
  g.time += dt;
  movePlayer(g, dt, input);
  const R = g.rules, room = roomAt(R, g.px, g.py);
  if (room >= 0 && room !== g.myRoom) {
    const r = g.rooms[room], full = r.n >= R.lobby.maxPerRoom, playing = r.st === "playing";
    if (full || playing) {
      const c = cabin(R, room);
      g.px = c.cx; g.py = c.y1 + 0.7;
      g.lobbyEvents.push({ t: "denied", room, reason: playing ? "Oda oyunda." : "Oda dolu." });
      return;
    }
  }
  if (room !== g.myRoom) { g.myRoom = room; g.lobbyEvents.push({ t: room >= 0 ? "enter" : "exit", room }); }
}

// Sunucudan gelen anlık görüntüyü dünyaya işle (ben dışındakiler çizilir)
export function applySnapshot(g, snap, myId, keep = () => true) {
  g.myId = myId;
  g.rooms = snap.rooms;
  const seen = new Set();
  for (const p of snap.players) {
    if (p.id === myId || !keep(p)) continue;
    seen.add(p.id);
    const q = g.players.find((o) => o.id === p.id);
    if (q) Object.assign(q, { tx: p.x, ty: p.y, tyaw: p.yaw, moving: p.moving, name: p.name, room: p.room, ig: p.g });
    else g.players.push({ id: p.id, name: p.name, x: p.x, y: p.y, yaw: p.yaw, tx: p.x, ty: p.y, tyaw: p.yaw, walk: 0, moving: p.moving, room: p.room, ig: p.g });
  }
  g.players = g.players.filter((p) => seen.has(p.id));
}

// Diğer oyuncuları hedef konuma doğru yumuşakça kaydır (ağ 10 Hz, ekran 60 Hz)
export function smoothPlayers(g, dt) {
  const k = Math.min(1, dt * 12);
  for (const p of g.players) {
    if (p.tx === undefined) continue;
    const dx = p.tx - p.x, dy = p.ty - p.y;
    if (Math.hypot(dx, dy) > 4) { p.x = p.tx; p.y = p.ty; } else { p.x += dx * k; p.y += dy * k; }
    let da = p.tyaw - p.yaw; da = Math.atan2(Math.sin(da), Math.cos(da)); p.yaw += da * k;
    p.walk += dt * 9 * (p.moving || 0);
  }
}

// Kabin tabelası: yazı ve renk (r,g,b). Dolu = kırmızı, oyunda = gri, boş = yeşil, birileri var = sarı
export function updateSigns(g) {
  const max = g.rules.lobby.maxPerRoom;
  g.signs.forEach((sg, i) => {
    const r = g.rooms[i] || { n: 0, st: "open" };
    const state = r.st === "playing" ? " · OYUNDA" : r.n >= max ? " · DOLU" : "";
    sg.text = `ODA ${i + 1} · ${r.n}/${max}${state}`;
    sg.c = r.st === "playing" ? "170,170,170" : r.n >= max ? "255,110,90" : r.n ? "255,220,120" : "150,240,170";
  });
}
