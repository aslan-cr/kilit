// Gerçek WebSocket bağlantılarıyla sunucu testi (sunucu bu süreçte açılır).
import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "../server/server.mjs";
import { RULES } from "../src/main/assets/js/rules.js";
import { cabin } from "../src/main/assets/js/rooms.js";

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, ms = 3000) { const t = Date.now(); while (Date.now() - t < ms) { const v = fn(); if (v) return v; await wait(15); } throw new Error("zaman aşımı"); }

async function client(port, name) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const c = { ws, msgs: [], snap: null, welcome: null, closed: false };
  ws.onmessage = (e) => { const m = JSON.parse(e.data); c.msgs.push(m); if (m.t === "snap") c.snap = m; if (m.t === "welcome") c.welcome = m; };
  ws.onclose = () => { c.closed = true; };
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  ws.send(JSON.stringify({ t: "hello", name }));
  await until(() => c.welcome || c.msgs.find((m) => m.t === "err"));
  c.moveTo = (x, y) => ws.send(JSON.stringify({ t: "pos", x, y, yaw: 0, walk: 0, moving: 0 }));
  return c;
}

test("sunucu: 11 oyuncu bağlanır, 10'u odaya girer, 11'i reddedilir; başlatınca üyelere seed gider", async () => {
  const srv = createServer({ port: 0, sendHz: 40 });
  const port = await srv.listen();
  try {
    const cs = [];
    for (let i = 0; i < 11; i++) cs.push(await client(port, "oyuncu" + i));
    const c0 = cabin(RULES, 0);
    for (let i = 0; i < 10; i++) { cs[i].moveTo(c0.cx, c0.cy); await wait(50); }   // sunucu 40 ms'den sık konumu yok sayar
    await until(() => cs[0].snap && cs[0].snap.rooms[0].n === 10);
    cs[10].moveTo(c0.cx, c0.cy);
    const deny = await until(() => cs[10].msgs.find((m) => m.t === "deny"));
    assert.equal(deny.room, 0); assert.match(deny.reason, /dolu/);
    await wait(150);
    assert.equal(cs[10].snap.rooms[0].n, 10, "oda hâlâ 10 kişi");
    assert.equal(cs[0].snap.players.length, 11, "herkes birbirini görür");

    cs[3].ws.send(JSON.stringify({ t: "start" }));
    await until(() => cs[3].msgs.find((m) => m.t === "err"));                      // sahip değil
    cs[0].ws.send(JSON.stringify({ t: "start" }));
    const st = await until(() => cs[7].msgs.find((m) => m.t === "start"));
    assert.ok(st.seed > 0); assert.equal(st.room, 0);
    assert.ok(!cs[10].msgs.find((m) => m.t === "start"), "odada olmayan başlatma mesajı almaz");

    cs[1].ws.close();                                                              // bağlantı kopunca oyuncu listeden düşer
    await until(() => cs[0].snap.players.length === 10);
  } finally { srv.close(); }
});

test("sunucu: kötü veri ve hello olmadan mesajlar sunucuyu düşürmez; aynı ad numaralanır", async () => {
  const srv = createServer({ port: 0, sendHz: 40 });
  const port = await srv.listen();
  try {
    const raw = new WebSocket(`ws://127.0.0.1:${port}`);
    await new Promise((r) => { raw.onopen = r; });
    raw.send("bu json degil"); raw.send(JSON.stringify({ t: "pos", x: 1, y: 1 })); raw.send("null");
    const a = await client(port, "Ayse"), b = await client(port, "ayse");
    assert.equal(a.welcome.name, "Ayse"); assert.equal(b.welcome.name, "ayse#2");
    const health = await (await fetch(`http://127.0.0.1:${port}/health`)).json();
    assert.equal(health.ok, true);
    raw.close();
  } finally { srv.close(); }
});
