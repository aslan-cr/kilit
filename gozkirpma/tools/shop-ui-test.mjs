// Dükkan arayüz testi (LOBİDE): yaklaşınca panel otomatik açılır, satın alma çalışır, satın alınan ve kalan para kalıcıdır (yenileyince de durur).
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";
const srv = await serve(5990), b = await chromium.launch({ args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const p = await b.newPage({ viewport: { width: 1280, height: 720 } }); const errs = []; p.on("pageerror", (e) => errs.push(e.message));
let bad = 0; const ok = (c, m, d = "") => { console.log((c ? "GEÇTİ " : "KALDI ") + m, d); if (!c) bad++; };
await p.goto("http://localhost:5990/index.html?lobby&shop=80"); await p.waitForFunction(() => window.__ready === true); await p.waitForTimeout(800);
ok(await p.isVisible("#shop"), "dükkana yaklaşınca panel kendiliğinden açılır");
await p.click("#shopList .row:nth-child(1) button"); await p.waitForTimeout(900);
ok((await p.textContent("#lobbyInfo")).includes("🪙 50"), "para düştü (80-30), lobi çubuğunda görünür", await p.textContent("#lobbyInfo"));
ok((await p.textContent("#shopList .row:nth-child(1)")).includes("sende"), "alınan eşya 'sende' görünür");
await p.goto("http://localhost:5990/index.html?lobby"); await p.waitForFunction(() => window.__ready === true); await p.waitForTimeout(800);
const w = await p.evaluate(() => JSON.parse(localStorage.getItem("gk_guest_wallet") || "null"));
ok(w && w.money === 50 && w.lights.join() === "fl1", "cüzdan kalıcı (yenileyince de durur)", JSON.stringify(w));
ok(errs.length === 0, "sayfa hatası yok", errs.join());
await b.close(); srv.close(); console.log(bad ? "\nKALDI" : "\nHEPSİ GEÇTİ"); process.exit(bad ? 1 : 0);
