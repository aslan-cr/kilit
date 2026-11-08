import test from "node:test";
import assert from "node:assert/strict";
import { RULES } from "../src/main/assets/js/rules.js";
import { createHub, hubJoin, hubLeave, hubMove, hubTick, hubBack, hubView, cabin, roomAt } from "../src/main/assets/js/rooms.js";
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

test("dört oda toplam 40 kişi alır, 41. kişi hiçbir odaya giremez (lobi sınırı bu testte yükseltildi)", () => {
  const hub = createHub({ ...R, lobby: { ...R.lobby, maxPlayers: 80 } }); joinN(hub, 41);
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

test("odaya girince 50 sn sayaç başlar; bitince oyun otomatik başlar, odadakiler oyuna geçer", () => {
  assert.equal(R.lobby.countdown, 50);
  const hub = createHub(R); joinN(hub, 3);
  assert.equal(hubView(hub).rooms[1].t, null, "boş odada sayaç yok");
  hubMove(hub, 0, inCabin(1));
  assert.equal(hubView(hub).rooms[1].t, 50, "ilk kişi girince sayaç başlar");
  assert.deepEqual(hubTick(hub, 30), []);
  hubMove(hub, 1, inCabin(1));                                   // sayaç sürerken katılan sayacı sıfırlamaz
  assert.equal(hubView(hub).rooms[1].t, 20);
  assert.deepEqual(hubTick(hub, 19.5), []);
  const st = hubTick(hub, 1, () => 77);
  assert.equal(st.length, 1); assert.deepEqual(st[0].members, [0, 1]); assert.equal(st[0].seed, 77);
  assert.equal(hub.rooms[1].status, "playing");
  assert.ok(hub.players.get(0).inGame && hub.players.get(1).inGame && !hub.players.get(2).inGame);
  assert.match(hubMove(hub, 2, inCabin(1)).deny.reason, /oyunda/, "başlayan odaya yeni kişi giremez");
});

test("herkes çıkarsa sayaç durur; yeniden girince 50 sn'den başlar", () => {
  const hub = createHub(R); joinN(hub, 1);
  hubMove(hub, 0, inCabin(0)); hubTick(hub, 40);
  hubMove(hub, 0, { x: 13, y: 12 });
  assert.equal(hubView(hub).rooms[0].t, null);
  assert.deepEqual(hubTick(hub, 100), [], "boş oda başlamaz");
  hubMove(hub, 0, inCabin(0));
  assert.equal(hubView(hub).rooms[0].t, 50);
});

test("minPlayers 2 ise tek kişi sayacı başlatmaz", () => {
  const hub = createHub({ ...R, lobby: { ...R.lobby, minPlayers: 2 } }); joinN(hub, 2);
  hubMove(hub, 0, inCabin(0));
  assert.equal(hubView(hub).rooms[0].t, null);
  hubMove(hub, 1, inCabin(0));
  assert.equal(hubView(hub).rooms[0].t, 50);
});

test("odalar birbirinden bağımsız sayar; oyun bitince oda yeniden açılır", () => {
  const hub = createHub(R); joinN(hub, 2);
  hubMove(hub, 0, inCabin(0)); hubTick(hub, 20); hubMove(hub, 1, inCabin(2));
  const v = hubView(hub).rooms;
  assert.deepEqual([v[0].t, v[1].t, v[2].t], [30, null, 50]);
  hubTick(hub, 30);
  assert.equal(hub.rooms[0].status, "playing");
  hubBack(hub, 0);
  assert.equal(hub.rooms[0].status, "open");
  hubTick(hub, 0.1);
  assert.equal(hubView(hub).rooms[0].t, 50, "dönen oyuncu için yeni sayaç");
});

test("oyundayken konum labirent koordinatı olarak aktarılır, oda değişmez", () => {
  const hub = createHub(R); joinN(hub, 1);
  hubMove(hub, 0, inCabin(0)); hubTick(hub, 60);
  hubMove(hub, 0, { x: 9.5, y: 7.5, yaw: 1 });
  assert.equal(hub.players.get(0).room, 0); assert.equal(hub.players.get(0).x, 9.5);
});

test("anlık görüntüde oda doluluğu ve oyuncular var", () => {
  const hub = createHub(R); joinN(hub, 2); hubMove(hub, 0, inCabin(3));
  const v = hubView(hub);
  assert.equal(v.players.length, 2); assert.equal(v.rooms[3].n, 1); assert.equal(v.rooms[3].t, 50);
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
  g.rooms[0] = { n: 10, st: "open", t: 20 };
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

test("bir lobi en fazla 20 kişi alır (varsayılan kural)", () => {
  const hub = createHub(R); joinN(hub, 20);
  assert.equal(hubJoin(hub, 99, "fazla").ok, false);
});
