// Lobi testi (headless Chromium, gerçek sunucu): iki oyuncu lobiye girer, odaya girer, oyun başlar; dolu oda reddedilir.
//   node tools/lobby-ui-test.mjs [ekran_görüntüsü_klasörü]
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";
import { createServer } from "../server/server.mjs";
import { RULES } from "../src/main/assets/js/rules.js";
import { cabin } from "../src/main/assets/js/rooms.js";

const shots = process.argv[2];
const port = 6100 + Math.floor(Math.random() * 90);
const web = await serve(port);
const srv = createServer({ port: 0, sendHz: 20, rules: { ...RULES, lobby: { ...RULES.lobby, countdown: 4 } } });
const sport = await srv.listen();
const b = await chromium.launch();
const results = [], errs = [];
const check = (n, ok, x = "") => { results.push(ok); console.log((ok ? "GEÇTİ " : "KALDI ") + n + (x ? "  " + x : "")); };
const url = `http://localhost:${port}/index.html?lobby&server=127.0.0.1:${sport}`;

async function player(name) {
  const ctx = await b.newContext({ viewport: { width: 820, height: 380 } });
  const p = await ctx.newPage();
  p.on("pageerror", (e) => errs.push(name + ": " + e.message));
  await p.addInitScript((n) => { try { localStorage.setItem("gk_t", "1"); } catch { /* */ } }, name);
  await p.goto(url);
  await p.waitForFunction(() => window.__ready === true, null, { timeout: 15000 });
  await p.waitForTimeout(500);
  return p;
}
const st = (p) => p.evaluate(() => ({ phase: GAME.ui.phase, room: GAME.mp.room, others: GAME.g.players.length, rooms: GAME.mp.snap && GAME.mp.snap.rooms.map((r) => r.n), t: GAME.mp.snap && GAME.mp.snap.rooms[0].t, bar: document.getElementById("lobbyInfo").textContent }));
const walkToRoom = async (p, i) => {
  const c = cabin(RULES, i);
  await p.evaluate(([x, y]) => { const g = GAME.g; g.px = x; g.py = 9; g.yaw = -Math.PI / 2; GAME.ui.keys.w = true; }, [c.cx, 0]);
  await p.waitForFunction((i) => GAME.mp.room === i, i, { timeout: 8000 });
  await p.evaluate(() => { GAME.ui.keys.w = false; });
};

const A = await player("A"), B = await player("B");
let s = await st(A);
check("A lobiye girdi", s.phase === "lobby", JSON.stringify(s));
await A.waitForFunction(() => GAME.g.players.length === 1, null, { timeout: 5000 });
check("A, B'yi görüyor", (await st(A)).others === 1);
if (shots) await A.screenshot({ path: shots + "/lobby-hall.png" });

await walkToRoom(A, 0); await walkToRoom(B, 0);
await A.waitForFunction(() => GAME.mp.snap && GAME.mp.snap.rooms[0].n === 2, null, { timeout: 5000 });
s = await st(A);
check("ikisi de oda 1'de (2 kişi)", s.room === 0 && s.rooms[0] === 2, JSON.stringify(s));
check("sayaç çalışıyor ve çubukta görünür", s.t > 0 && /sn sonra başlıyor/.test(s.bar), s.bar);
if (shots) await A.screenshot({ path: shots + "/lobby-room.png" });

await A.waitForFunction(() => GAME.ui.phase === "play", null, { timeout: 9000 });
await B.waitForFunction(() => GAME.ui.phase === "play", null, { timeout: 9000 });
const seeds = await Promise.all([A, B].map((p) => p.evaluate(() => GAME.g.seed)));
check("ikisi de aynı labirentte başladı", seeds[0] === seeds[1], seeds.join("/"));
await A.waitForFunction(() => GAME.g.players.length === 1, null, { timeout: 5000 });
check("oyunda birbirlerini görüyorlar", (await st(A)).others === 1 && (await st(B)).others === 1);
await A.waitForTimeout(400);
if (shots) await A.screenshot({ path: shots + "/lobby-game.png" });

// dolu oda: 10 sahte bağlantı oda 2'yi doldurur
const fakes = [];
for (let i = 0; i < 10; i++) {
  const ws = new WebSocket(`ws://127.0.0.1:${sport}`);
  await new Promise((r) => { ws.onopen = r; });
  ws.send(JSON.stringify({ t: "hello", name: "f" + i }));
  await new Promise((r) => setTimeout(r, 60));
  const c = cabin(RULES, 1); ws.send(JSON.stringify({ t: "pos", x: c.cx, y: c.cy }));
  fakes.push(ws);
}
await new Promise((r) => setTimeout(r, 400));
const C = await player("C");
await C.waitForFunction(() => GAME.mp.snap && GAME.mp.snap.rooms[1].n === 10, null, { timeout: 5000 });
const c1 = cabin(RULES, 1);
await C.evaluate(([x]) => { const g = GAME.g; g.px = x; g.py = 9; g.yaw = -Math.PI / 2; GAME.ui.keys.w = true; }, [c1.cx]);
await C.waitForTimeout(2500);
s = await st(C);
check("dolu odaya (10/10) girilemez, salonda kalır", s.room === -1 && s.rooms[1] === 10, JSON.stringify(s));
if (shots) await C.screenshot({ path: shots + "/lobby-full.png" });
check("sayfa hatası yok", errs.length === 0, errs.join(" | "));

// Oyun açılınca doğrudan lobi (sunucu adresi yok -> çevrimdışı lobi); kamera yoksa kamerasız moda düşer
{
  const ctx = await b.newContext({ viewport: { width: 820, height: 380 } });
  const p = await ctx.newPage();
  p.on("pageerror", (e) => errs.push("offline: " + e.message));
  await p.addInitScript(() => { try { localStorage.setItem("gk_guest", "1"); localStorage.setItem("gk_cam", "0"); } catch { /* */ } });
  await p.goto(`http://localhost:${port}/index.html?r.lobby.countdown=3`);
  await p.waitForFunction(() => window.__ready === true && GAME.ui.phase === "lobby", null, { timeout: 15000 });
  const o = await p.evaluate(() => ({ local: !!GAME.mp.net.local, net: document.getElementById("netState").textContent, menuHidden: document.getElementById("menu").classList.contains("off") }));
  check("açılınca doğrudan lobi, menü gizli", o.menuHidden && o.local, JSON.stringify(o));
  const c = cabin(RULES, 2);
  await p.evaluate(([x]) => { const g = GAME.g; g.px = x; g.py = 9; g.yaw = -Math.PI / 2; GAME.ui.keys.w = true; }, [c.cx]);
  await p.waitForFunction(() => GAME.mp.room === 2, null, { timeout: 8000 });
  await p.evaluate(() => { GAME.ui.keys.w = false; });
  const t = await p.evaluate(() => GAME.mp.snap.rooms[2].t);
  check("çevrimdışı lobide odaya girince sayaç başlar", t > 0, "t=" + t);
  await p.waitForFunction(() => GAME.ui.phase === "play", null, { timeout: 12000 });
  check("sayaç bitince oyun otomatik başlar (tek kişi)", true);
  if (shots) await p.screenshot({ path: shots + "/lobby-offline-game.png" });
  await ctx.close();
  // kamera açık ama cihaz yok: kamerasıza düşer, lobi yine açılır
  const ctx2 = await b.newContext({ viewport: { width: 820, height: 380 } });
  const p2 = await ctx2.newPage();
  await p2.addInitScript(() => { try { localStorage.setItem("gk_guest", "1"); localStorage.setItem("gk_cam", "1"); } catch { /* */ } });
  await p2.goto(`http://localhost:${port}/index.html`);
  await p2.waitForFunction(() => GAME.ui && GAME.ui.phase === "lobby", null, { timeout: 40000 });
  const m = await p2.evaluate(() => ({ mode: GAME.ui.mode, cam: document.getElementById("camState").textContent }));
  check("kamera açılamazsa kamerasız modda lobiye girer", m.mode === "keyboard" && /açılamadı/.test(m.cam), JSON.stringify(m));
  await ctx2.close();
}
fakes.forEach((w) => w.close()); await b.close(); srv.close(); web.close();
console.log(results.every(Boolean) ? "\nHEPSİ GEÇTİ" : "\nBAZILARI KALDI");
process.exit(results.every(Boolean) ? 0 : 1);
