// Headless ekran görüntüsü + hata/log okuyucu. Playwright (chromium) gerekir.
//   node tools/shot.mjs "?sim=30&seed=7" shots/t1.png [--size 1280x720] [--wait 600]
// Sayfa hatalarını ve #debuglog satırını yazdırır. Sonra PNG'yi AÇIP bakın.
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";

const args = process.argv.slice(2);
const [query, out] = args;
const opt = (n, d) => { const i = args.indexOf("--" + n); return i > 0 ? args[i + 1] : d; };
const [W, H] = opt("size", "1280x720").split("x").map(Number);
const port = 5800 + Math.floor(Math.random() * 100);
const srv = await serve(port);
const b = await chromium.launch({ args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const p = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
const errs = [];
p.on("pageerror", (e) => errs.push("pageerror: " + e.message));
p.on("console", (m) => { if (m.type() === "error") errs.push("console: " + m.text()); });
const t0 = Date.now();
await p.goto(`http://localhost:${port}/index.html${query || ""}`);
await p.waitForFunction(() => window.__ready === true, null, { timeout: 60000 }).catch(() => errs.push("hazır olmadı"));
await p.waitForTimeout(Number(opt("wait", 400)));
const log = await p.evaluate(() => document.getElementById("debuglog")?.textContent || "");
if (out) await p.screenshot({ path: out });
console.log(JSON.stringify({ ms: Date.now() - t0, log, errs }));
await b.close(); srv.close();
