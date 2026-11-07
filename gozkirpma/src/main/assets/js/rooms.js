// Lobi + oda mantığı. DOM'suz ve ağsız: hem sunucu (server/server.mjs) hem tarayıcı aynı kodu kullanır.
// Kurallar: 4 oda kurma yeri, her oda en fazla 10 kişi. Oda üyeliği KONUMDAN hesaplanır: kabine girince odaya girersin.
import { RULES } from "./rules.js";

// Kabin i'nin x aralığı [x0, x1) ve y aralığı [1, 1+cubDepth)
export function cabin(R, i) {
  const L = R.lobby, x0 = 1 + i * (L.cubW + L.cubGap);
  return { x0, x1: x0 + L.cubW, y0: 1, y1: 1 + L.cubDepth, cx: x0 + L.cubW / 2, cy: 1 + L.cubDepth / 2 };
}
// (x,y) hangi kabinin içinde? -1 = salonda
export function roomAt(R, x, y) {
  for (let i = 0; i < R.lobby.rooms; i++) { const c = cabin(R, i); if (x >= c.x0 && x < c.x1 && y >= c.y0 && y < c.y1) return i; }
  return -1;
}
export function spawnPoint(R, n = 0) {              // salonun ortası, herkes biraz farklı yerde doğsun
  const L = R.lobby, midX = L.size / 2, y = 1 + L.cubDepth + 3;
  return { x: midX + ((n * 1.7) % 6) - 3, y: y + ((n * 0.9) % 3) };
}

export function createHub(rules = RULES) {
  const L = rules.lobby;
  return { R: rules, players: new Map(), rooms: Array.from({ length: L.rooms }, (_, i) => ({ i, members: [], host: null, status: "open", seed: 0 })), n: 0 };
}

const clean = (s) => String(s || "").normalize("NFC").replace(/[^A-Za-z0-9_ğüşıöçĞÜŞİÖÇ ]/g, "").trim().slice(0, 16);

// { ok, id, name } ya da { ok:false, error }
export function hubJoin(hub, id, name) {
  if (hub.players.size >= hub.R.lobby.maxPlayers) return { ok: false, error: "Sunucu dolu." };
  let base = clean(name) || "Oyuncu", nm = base, k = 2;
  const taken = (x) => [...hub.players.values()].some((p) => p.name.toLocaleLowerCase("tr") === x.toLocaleLowerCase("tr"));
  while (taken(nm)) nm = base.slice(0, 13) + "#" + k++;       // aynı ad varsa numara ekle
  const sp = spawnPoint(hub.R, hub.n++);
  hub.players.set(id, { id, name: nm, x: sp.x, y: sp.y, yaw: -Math.PI / 2, walk: 0, moving: 0, room: -1, inGame: false });
  return { ok: true, id, name: nm, x: sp.x, y: sp.y };
}

export function hubLeave(hub, id) {
  const p = hub.players.get(id);
  if (!p) return;
  if (p.room >= 0) leaveRoom(hub, p);
  hub.players.delete(id);
}

function leaveRoom(hub, p) {
  const r = hub.rooms[p.room];
  r.members = r.members.filter((m) => m !== p.id);
  if (r.host === p.id) r.host = r.members[0] ?? null;          // sahip çıkarsa sıradaki kişi sahip olur
  if (!r.members.length) { r.status = "open"; r.host = null; }
  else if (!r.members.some((m) => hub.players.get(m).inGame)) r.status = "open";
  p.room = -1; p.inGame = false;
}

// Konum güncelle. Odaya girmek/çıkmak konumdan çıkar. Dolu/oyundaki odaya girilemez: { deny: { room, reason, x, y } } döner.
export function hubMove(hub, id, m) {
  const p = hub.players.get(id);
  if (!p) return {};
  const L = hub.R.lobby, lim = L.size - 0.5;
  const num = (v, d) => (Number.isFinite(v) ? v : d);
  if (p.inGame) {                                              // oyundayken konum labirent koordinatıdır, sadece aktarılır
    Object.assign(p, { x: num(m.x, p.x), y: num(m.y, p.y), yaw: num(m.yaw, p.yaw), walk: num(m.walk, 0), moving: num(m.moving, 0) });
    return {};
  }
  const x = Math.max(0.5, Math.min(lim, num(m.x, p.x))), y = Math.max(0.5, Math.min(lim, num(m.y, p.y)));
  const to = roomAt(hub.R, x, y);
  if (to !== p.room) {
    if (to >= 0) {
      const r = hub.rooms[to];
      const why = r.status === "playing" ? "Oda oyunda." : r.members.length >= L.maxPerRoom ? "Oda dolu." : "";
      if (why) { const c = cabin(hub.R, to); return { deny: { room: to, reason: why, x: c.cx, y: c.y1 + 0.7 } }; }
    }
    if (p.room >= 0) leaveRoom(hub, p);
    if (to >= 0) { const r = hub.rooms[to]; r.members.push(id); if (r.host === null) r.host = id; p.room = to; }
  }
  Object.assign(p, { x, y, yaw: num(m.yaw, p.yaw), walk: num(m.walk, 0), moving: num(m.moving, 0) });
  return {};
}

// Oda sahibi oyunu başlatır. { ok, room, seed, members } ya da { ok:false, error }
export function hubStart(hub, id, seed) {
  const p = hub.players.get(id);
  if (!p || p.room < 0) return { ok: false, error: "Önce bir odaya gir." };
  const r = hub.rooms[p.room];
  if (r.host !== id) return { ok: false, error: "Oyunu yalnızca oda sahibi başlatabilir." };
  if (r.status === "playing") return { ok: false, error: "Oyun zaten başladı." };
  r.status = "playing"; r.seed = seed;
  for (const m of r.members) { const q = hub.players.get(m); q.inGame = true; q.x = 1.5; q.y = 1.5; }
  return { ok: true, room: r.i, seed, members: r.members.slice() };
}

// Oyuncu oyunu bitirdi/bıraktı: odanın kabinine geri döner
export function hubBack(hub, id) {
  const p = hub.players.get(id);
  if (!p || !p.inGame) return;
  p.inGame = false;
  const c = cabin(hub.R, p.room);
  p.x = c.cx; p.y = c.cy;
  const r = hub.rooms[p.room];
  if (!r.members.some((m) => hub.players.get(m).inGame)) r.status = "open";
}

// İstemcilere gidecek anlık görüntü
export function hubView(hub) {
  return {
    players: [...hub.players.values()].map((p) => ({ id: p.id, name: p.name, x: +p.x.toFixed(2), y: +p.y.toFixed(2), yaw: +p.yaw.toFixed(2), walk: +p.walk.toFixed(1), moving: +p.moving.toFixed(2), room: p.room, g: p.inGame ? 1 : 0 })),
    rooms: hub.rooms.map((r) => ({ n: r.members.length, st: r.status, host: r.host })),
  };
}
