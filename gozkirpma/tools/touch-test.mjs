// Dokunmatik kontrol testi (headless Chromium, gerçek dokunma olayları).
//   node tools/touch-test.mjs   -> hepsi geçerse çıkış kodu 0
// Kurallar: sol yarı = joystick (parmak neredeyse orada, sınırsız mesafe), sağ yarı = sadece bakış, kısa dokunuş = ateş.
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";

const port = 5900 + Math.floor(Math.random() * 90);
const srv = await serve(port);
const b = await chromium.launch();
const c = await b.newContext({ viewport: { width: 900, height: 420 }, hasTouch: true, isMobile: true });
const p = await c.newPage();
const errs = [];
p.on("pageerror", (e) => errs.push(e.message));
await p.goto(`http://localhost:${port}/index.html?play&seed=3`);
await p.waitForFunction(() => window.__ready === true);
const cdp = await c.newCDPSession(p);
const T = (type, pts) => cdp.send("Input.dispatchTouchEvent", { type, touchPoints: pts });
const st = () => p.evaluate(() => { const g = window.GAME.g; return { x: g.px, y: g.py, yaw: g.yaw, shells: g.shells, eyes: g.eyesClosed, cd: g.cooldown, enemies: g.enemies.map((e) => [e.x, e.y]) }; });
const joyBox = () => p.evaluate(() => { const j = document.getElementById("joy"); return { on: j.classList.contains("on"), left: j.style.left, top: j.style.top }; });
const wait = (ms) => p.waitForTimeout(ms);
const results = [];
const check = (name, ok, extra = "") => { results.push(ok); console.log((ok ? "GEÇTİ " : "KALDI ") + name + (extra ? "  " + extra : "")); };

await wait(300);
// 1) Sağ yarı sürükle: yalnızca döner
let s0 = await st();
await T("touchStart", [{ x: 600, y: 200, id: 1 }]);
for (let i = 1; i <= 12; i++) { await T("touchMove", [{ x: 600 + i * 18, y: 200 - i * 6, id: 1 }]); await wait(16); }
await T("touchEnd", []);
await wait(100);
let s1 = await st();
check("sağ yarı sürükleme ekranı döndürür", Math.abs(s1.yaw - s0.yaw) > 0.2, `yaw ${s0.yaw.toFixed(2)} -> ${s1.yaw.toFixed(2)}`);
check("sağ yarı sürükleme oyuncuyu hareket ettirmez", Math.hypot(s1.x - s0.x, s1.y - s0.y) < 1e-6);

// 2) Sol yarı: joystick parmak neredeyse orada belirir; hareket eder, ekran dönmez
await T("touchStart", [{ x: 40, y: 380, id: 2 }]);
await wait(50);
const jb = await joyBox();
check("joystick parmağın değdiği yerde belirir (ekranın sol-alt köşesi)", jb.on && jb.left === "40px" && jb.top === "380px", JSON.stringify(jb));
let a0 = await st();
for (let i = 1; i <= 6; i++) { await T("touchMove", [{ x: 40 + i * 12, y: 380, id: 2 }]); await wait(16); }   // 72 px: tam hız
await wait(500);
let a1 = await st();
await T("touchEnd", []);
await wait(50);
// 3) Aynı yön, çok daha uzak (sonsuz mesafe): hız aynı kalmalı
let b0 = await st();
await T("touchStart", [{ x: 20, y: 300, id: 3 }]);
for (let i = 1; i <= 12; i++) { await T("touchMove", [{ x: 20 + i * 36, y: 300, id: 3 }]); await wait(16); }   // 432 px: ekranın sağ yarısına kadar taşar
await wait(500);
let b1 = await st();
await T("touchEnd", []);
const d1 = Math.hypot(a1.x - a0.x, a1.y - a0.y), d2 = Math.hypot(b1.x - b0.x, b1.y - b0.y);
check("sol joystick oyuncuyu hareket ettirir", d1 > 0.2, `mesafe ${d1.toFixed(2)}`);
check("sol parmak ne kadar uzaklaşsa da ekran dönmez", Math.abs(a1.yaw - a0.yaw) < 1e-6 && Math.abs(b1.yaw - b0.yaw) < 1e-6);
check("uzaklık sınırsız: çok uzak parmak da hareket ettirir", d2 > 0.2, `mesafe ${d2.toFixed(2)} (yakın: ${d1.toFixed(2)})`);

// 4) Sağdan başlayıp sol yarıya geçen parmak dönmez
await wait(300);
let c0 = await st();
await T("touchStart", [{ x: 500, y: 200, id: 4 }]);
for (let i = 1; i <= 10; i++) { await T("touchMove", [{ x: 500 - i * 30, y: 200, id: 4 }]); await wait(16); }
await T("touchEnd", []);
let c1 = await st();
const crossed = c1.yaw - c0.yaw;
check("sağ yarıdan sol yarıya geçen parmak sol yarıda dönmez", Math.abs(crossed) < 0.31 * 1.2, `yaw değişimi ${crossed.toFixed(3)} (yalnızca sağ yarıdaki ~0..450px ≈ ilk ${Math.floor((500 - 450) / 30) + 1} adım)`);

// 5) Kısa dokunuş (sağ yarı) ateş eder
await wait(1200);
let f0 = await st();
await T("touchStart", [{ x: 700, y: 200, id: 5 }]); await wait(60); await T("touchEnd", []);
await wait(150);
let f1 = await st();
check("sağ yarıya kısa dokunuş ateş eder", f1.shells === f0.shells - 1, `mermi ${f0.shells} -> ${f1.shells}`);

// 6) Ateş düğmesi
await wait(1500);
let g0 = await st();
const fb = await p.locator("#fireBtn").boundingBox();
await T("touchStart", [{ x: fb.x + fb.width / 2, y: fb.y + fb.height / 2, id: 6 }]); await wait(80); await T("touchEnd", []);
await wait(150);
let g1 = await st();
check("ateş düğmesi ateş eder ve ekranı döndürmez", g1.shells === g0.shells - 1 && Math.abs(g1.yaw - g0.yaw) < 1e-6, `mermi ${g0.shells} -> ${g1.shells}`);

// 7) Göz düğmesi: basılıyken göz kapalı ve gölgeler hareket eder, bırakınca durur
const eb = await p.locator("#eyeBtn").boundingBox();
let h0 = await st();
await T("touchStart", [{ x: eb.x + eb.width / 2, y: eb.y + eb.height / 2, id: 7 }]);
await wait(700);
let h1 = await st();
await T("touchEnd", []);
await wait(100);
let h2 = await st(); await wait(500); let h3 = await st();
const moved = (A, B) => A.enemies.some((e, i) => Math.hypot(e[0] - B.enemies[i][0], e[1] - B.enemies[i][1]) > 0.05);
check("göz düğmesi basılıyken göz kapalı, gölgeler hareket eder", h1.eyes && moved(h0, h1));
check("göz açılınca gölgeler donar", !h3.eyes && !moved(h2, h3));

check("sayfa hatası yok", errs.length === 0, errs.join(" | "));
await b.close(); srv.close();
process.exit(results.every(Boolean) ? 0 : 1);
