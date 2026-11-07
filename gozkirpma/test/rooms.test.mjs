import test from "node:test";
import assert from "node:assert/strict";
import { RULES } from "../src/main/assets/js/rules.js";
import { createHub, hubJoin, hubLeave, hubMove, hubStart, hubBack, hubView, cabin, roomAt } from "../src/main/assets/js/rooms.js";
import { createLobby, stepLobby, applySnapshot } from "../src/main/assets/js/lobby.js";
import { blocked } from "../src/main/assets/js/sim.js";

const R = RULES;
const inCabin = (i) => ({ x: cabin(R, i).cx, y: cabin(R, i).cy });
const joinN = (hub, n, base = 0) => { for (let k = 0; k < n; k++) hubJoin(hub, base + k, "p" + (base + k)); };

test("4 oda var, her kabinin ortası kendi odasına çıkar; salon -1", () => {
  assert.equal(R.lobby.rooms, 4); assert.equal(R.lobby.maxPerRoom, 10);
  for (let i = 0; i < 4; i++) { const c = inCabin(i); assert.equal(roomAt(R, c.x, c.y), i); }
  assert.equal(roomAt(R, 13, 12), -1);
});

test("odaya girince üye olunur, çıkınca düşülür", () => {
  const hub = createHub(R); joinN(hub, 1);
  hubMove(hub, 0, { ...inCabin(2) });
  assert.equal(hub.rooms[2].members.length, 1); assert.equal(hub.rooms[2].host, 0);
  hubMove(hub, 0, { x: 13, y: 12 });
  assert.equal(hub.rooms[2].members.length, 0); assert.equal(hub.rooms[2].host, null);
});

test("bir oda en fazla 10 kişi: 11. kişi girmeye çalışınca reddedilir ve salonda kalır", () => {
  const hub = createHub(R); joinN(hub, 11);
  for (let k = 0; k < 10; k++) assert.deepEqual(hubMove(hub, k, inCabin(0)), {});
  assert.equal(hub.rooms[0].members.length, 10);
  const r = hubMove(hub, 10, inCabin(0));
  assert.equal(r.deny.room, 0); assert.match(r.deny.reason, /dolu/);
  assert.equal(hub.players.get(10).room, -1);
  assert.equal(hub.rooms[0].members.length, 10);
  assert.deepEqual(hubMove(hub, 10, inCabin(1)), {}, "başka odaya girebilir");
});

test("dört oda toplam 40 kişi alır, 41. kişi hiçbir odaya giremez", () => {
  const hub = createHub(R); joinN(hub, 41);
  for (let k = 0; k < 40; k++) assert.deepEqual(hubMove(hub, k, inCabin(k % 4)), {}, "kişi " + k);
  assert.deepEqual(hub.rooms.map((r) => r.members.length), [10, 10, 10, 10]);
  for (let i = 0; i < 4; i++) assert.ok(hubMove(hub, 40, inCabin(i)).deny);
});

test("biri çıkınca yer açılır; sahip çıkarsa sıradaki sahip olur", () => {
  const hub = createHub(R); joinN(hub, 11);
  for (let k = 0; k < 10; k++) hubMove(hub, k, inCabin(0));
  assert.equal(hub.rooms[0].host, 0);
  hubLeave(hub, 0);                                              // bağlantı koptu
  assert.equal(hub.rooms[0].host, 1); assert.equal(hub.rooms[0].members.length, 9);
  assert.deepEqual(hubMove(hub, 10, inCabin(0)), {});
});

test("aynı ad iki kez alınamaz (numara eklenir); geçersiz karakterler temizlenir", () => {
  const hub = createHub(R);
  assert.equal(hubJoin(hub, 1, "Burak").name, "Burak");
  assert.equal(hubJoin(hub, 2, "burak").name, "burak#2");
  assert.equal(hubJoin(hub, 3, "<b>x</b>").name, "bxb");
  assert.equal(hubJoin(hub, 4, "").name, "Oyuncu");
});

test("sunucu doluysa yeni oyuncu alınmaz", () => {
  const hub = createHub({ ...R, lobby: { ...R.lobby, maxPlayers: 3 } }); joinN(hub, 3);
  assert.equal(hubJoin(hub, 99, "x").ok, false);
});

test("yalnızca oda sahibi başlatır; başlayınca oda 'oyunda' olur ve yeni kişi giremez", () => {
  const hub = createHub(R); joinN(hub, 3);
  hubMove(hub, 0, inCabin(1)); hubMove(hub, 1, inCabin(1));
  assert.equal(hubStart(hub, 1, 5).ok, false, "sahip değil");
  assert.equal(hubStart(hub, 2, 5).ok, false, "odada değil");
  const s = hubStart(hub, 0, 5);
  assert.deepEqual(s.members, [0, 1]); assert.equal(hub.rooms[1].status, "playing");
  assert.match(hubMove(hub, 2, inCabin(1)).deny.reason, /oyunda/);
  hubBack(hub, 0); assert.equal(hub.rooms[1].status, "playing", "biri hâlâ oyunda");
  hubBack(hub, 1); assert.equal(hub.rooms[1].status, "open");
});

test("oyundayken konum labirent koordinatı olarak aktarılır, oda değişmez", () => {
  const hub = createHub(R); joinN(hub, 1);
  hubMove(hub, 0, inCabin(0)); hubStart(hub, 0, 1);
  hubMove(hub, 0, { x: 9.5, y: 7.5, yaw: 1 });
  assert.equal(hub.players.get(0).room, 0); assert.equal(hub.players.get(0).x, 9.5);
});

test("anlık görüntüde oda doluluğu ve oyuncular var", () => {
  const hub = createHub(R); joinN(hub, 2); hubMove(hub, 0, inCabin(3));
  const v = hubView(hub);
  assert.equal(v.players.length, 2); assert.equal(v.rooms[3].n, 1); assert.equal(v.rooms[3].host, 0);
});

test("lobi haritası: kabinler açık, bölmeler dolu, spawn serbest, oyuncu kabine yürüyebilir", () => {
  const g = createLobby(R);
  for (let i = 0; i < 4; i++) { const c = inCabin(i); assert.ok(!blocked(g, c.x, c.y, 0.2), "kabin " + i); }
  assert.ok(blocked(g, 6.5, 2.5, 0.2), "kabinler arası duvar");
  assert.ok(!blocked(g, g.px, g.py, 0.2));
  g.yaw = -Math.PI / 2;                                         // kuzeye (−y) bak
  g.px = cabin(R, 0).cx; g.py = 8;
  for (let k = 0; k < 120 && g.myRoom !== 0; k++) stepLobby(g, 1 / 60, { fwd: 1 });
  assert.equal(g.myRoom, 0, "kabine girdi");
});

test("dolu odaya yürümeye çalışan oyuncu istemcide de geri itilir", () => {
  const g = createLobby(R);
  g.rooms[0] = { n: 10, st: "open", host: 3 };
  g.px = cabin(R, 0).cx; g.py = 8; g.yaw = -Math.PI / 2;
  for (let k = 0; k < 200; k++) stepLobby(g, 1 / 60, { fwd: 1 });
  assert.equal(g.myRoom, -1);
  assert.ok(g.lobbyEvents.some((e) => e.t === "denied"));
});

test("anlık görüntü diğer oyuncuları ekler, çıkanları siler, beni çizmez", () => {
  const g = createLobby(R);
  const snap = (ids) => ({ rooms: g.rooms, players: ids.map((id) => ({ id, name: "o" + id, x: 5, y: 12, yaw: 0, moving: 0, room: -1, g: 0 })) });
  applySnapshot(g, snap([1, 2, 3]), 1);
  assert.deepEqual(g.players.map((p) => p.id), [2, 3]);
  applySnapshot(g, snap([1, 3]), 1);
  assert.deepEqual(g.players.map((p) => p.id), [3]);
});
