// Canlandırma testi (headless Chromium, gerçek sunucu): iki oyuncu aynı odada oyuna başlar; A yakalanır, yere düşer
// (lobiye dönmez); B yanına gidip birkaç sn durunca A ayağa kalkar.   node tools/revive-ui-test.mjs [ekran_görüntüsü_klasörü]
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";
import { createServer } from "../server/server.mjs";
import { RULES } from "../src/main/assets/js/rules.js";
import { cabin } from "../src/main/assets/js/rooms.js";

const shots = process.argv[2];
const port = 6200 + Math.floor(Math.random() * 90);
const web = await serve(port);
const srv = createServer({ port: 0, sendHz: 20, rules: { ...RULES, lobby: { ...RULES.lobby, countdown: 3 } } });
const sport = await srv.listen();
const b = await chromium.launch();
const results = [], errs = [];
const check = (n, ok, x = "") => { results.push(ok); console.log((ok ? "GEÇTİ " : "KALDI ") + n + (x ? "  " + x : "")); };
const url = `http://localhost:${port}/index.html?lobby&server=127.0.0.1:${sport}&r.lobby.countdown=3`;

async function player(name) {
  const ctx = await b.newContext({ viewport: { width: 820, height: 380 } });
  const p = await ctx.newPage();
  p.on("pageerror", (e) => errs.push(name + ": " + e.message));
  await p.addInitScript(() => { try { localStorage.setItem("gk_cam", "0"); } catch { /* */ } });
  await p.goto(url);
  await p.waitForFunction(() => window.__ready === true, null, { timeout: 15000 });
  await p.waitForTimeout(500);
  return p;
}
const walkToRoom = async (p, i) => {
  const c = cabin(RULES, i);
  await p.evaluate(([x]) => { const g = GAME.g; g.px = x; g.py = 9; g.yaw = -Math.PI / 2; GAME.ui.keys.w = true; }, [c.cx]);
  await p.waitForFunction((i) => GAME.mp.room === i, i, { timeout: 8000 });
  await p.evaluate(() => { GAME.ui.keys.w = false; });
};

try {
  const A = await player("A"), B = await player("B");
  await walkToRoom(A, 0); await walkToRoom(B, 0);
  await A.waitForFunction(() => GAME.ui.phase === "play", null, { timeout: 12000 });
  await B.waitForFunction(() => GAME.ui.phase === "play", null, { timeout: 12000 });
  await B.evaluate(() => { GAME.g.enemies.length = 0; });                  // B bu testte yakalanmasın
  await A.waitForFunction(() => GAME.g.players.length === 1, null, { timeout: 5000 });

  // A yakalanır: bir gölgeyi yanına getir, gözünü kapat
  await A.evaluate(() => { const g = GAME.g, e = g.enemies[0]; e.x = g.px + 0.3; e.y = g.py; e.stun = 0; GAME.ui.keys.eye = true; });
  await A.waitForFunction(() => GAME.ui.phase === "scare", null, { timeout: 3000 });
  await A.evaluate(() => { GAME.ui.keys.eye = false; });
  await A.waitForFunction(() => GAME.ui.phase === "down", null, { timeout: 12000 });
  check("A yakalanınca lobiye dönmedi, yere düştü", (await A.evaluate(() => GAME.g.state)) === "down");
  check("A hâlâ oyunda (lobi değil)", await A.evaluate(() => GAME.mp.inGame === true));
  check("yere düşme kutusu görünür", await A.evaluate(() => !document.getElementById("down").classList.contains("hidden") && /YERE DÜŞTÜN/.test(document.getElementById("downText").textContent)));
  await B.waitForFunction(() => GAME.g.players[0] && GAME.g.players[0].down === 1, null, { timeout: 4000 });
  check("B, A'yı yerde görüyor", true);
  if (shots) { await A.waitForTimeout(300); await A.screenshot({ path: shots + "/revive-down-self.png" }); }

  // B, A'nın yanına gider ve bakar
  const pos = await A.evaluate(() => ({ x: GAME.g.px, y: GAME.g.py }));
  await B.evaluate(({ x, y }) => { const g = GAME.g; g.px = x - 1.0; g.py = y; g.yaw = 0; g.pitch = -0.4; }, pos);
  await B.waitForTimeout(400);
  if (shots) await B.screenshot({ path: shots + "/revive-mate-view.png" });
  await B.evaluate(({ x, y }) => { const g = GAME.g; g.px = x - 0.5; g.py = y; }, pos);
  await B.waitForFunction(() => GAME.g.reviving && GAME.g.reviving.t > 1, null, { timeout: 3000 });
  if (shots) await B.screenshot({ path: shots + "/revive-progress.png" });
  await A.waitForFunction(() => GAME.ui.phase === "play" && GAME.g.state === "play", null, { timeout: 8000 });
  check("B yanında durunca A ayağa kalktı", true);
  check("A koruma süresinde", await A.evaluate(() => GAME.g.safe > 0));
  await B.waitForFunction(() => GAME.g.players[0] && !GAME.g.players[0].down, null, { timeout: 3000 });
  check("B, A'yı ayakta görüyor", true);

  // A tekrar düşer, bu sefer pes eder -> lobiye döner
  await A.waitForTimeout(3200);
  await A.evaluate(() => { const g = GAME.g, e = g.enemies.find((q) => q.alive); e.x = g.px + 0.3; e.y = g.py; e.stun = 0; GAME.ui.keys.eye = true; });
  await A.waitForFunction(() => GAME.ui.phase === "down", null, { timeout: 12000 });
  await A.evaluate(() => { GAME.ui.keys.eye = false; });
  await A.click("#giveUp");
  await A.waitForFunction(() => GAME.ui.phase === "lobby", null, { timeout: 4000 });
  check("pes edince lobiye döndü", true);
} catch (e) { check("beklenmeyen hata", false, e.message); }
check("sayfa hatası yok", errs.length === 0, errs.join(" | "));
await b.close(); srv.close(); web.close();
console.log(results.every(Boolean) ? "HEPSİ GEÇTİ" : "BAZILARI KALDI");
process.exit(results.every(Boolean) ? 0 : 1);
