// Giriş ekranı testi (headless Chromium): hesap oluştur, çıkış, giriş, misafir, kalıcı oturum, yazarken oyun tuşları.
//   node tools/auth-ui-test.mjs [ekran_görüntüsü_klasörü]
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
import { serve } from "./serve.mjs";

const shots = process.argv[2];
const port = 6000 + Math.floor(Math.random() * 90);
const srv = await serve(port);
const b = await chromium.launch();
const ctx = await b.newContext({ viewport: { width: 820, height: 380 } });
const p = await ctx.newPage();
const errs = []; p.on("pageerror", (e) => errs.push(e.message));
const url = `http://localhost:${port}/index.html?nolobby`;
const results = [];
const check = (n, ok, x = "") => { results.push(ok); console.log((ok ? "GEÇTİ " : "KALDI ") + n + (x ? "  " + x : "")); };
const vis = (id) => p.evaluate((i) => !document.getElementById(i).classList.contains("hidden"), id);
const ready = async () => { await p.waitForFunction(() => window.__ready === true); await p.waitForTimeout(250); };

await p.goto(url); await ready();
check("açılışta giriş ekranı görünür, menü gizli", (await vis("loginView")) && !(await vis("mainView")));
if (shots) await p.screenshot({ path: shots + "/auth-login.png" });

await p.fill("#user", "Burak"); await p.fill("#pass", "yanlis1");
await p.click("#authBtn"); await p.waitForTimeout(600);
check("kayıtsız kullanıcıyla giriş reddedilir", /yanlış/.test(await p.textContent("#authMsg")) && (await vis("loginView")));

await p.click("#tabReg"); await p.waitForTimeout(100);
await p.fill("#user", "Bu rak"); await p.fill("#pass", "gizli123"); await p.fill("#pass2", "gizli123");
await p.click("#authBtn"); await p.waitForTimeout(400);
check("geçersiz kullanıcı adı (boşluklu) reddedilir", /3-16/.test(await p.textContent("#authMsg")));
await p.fill("#user", "Burak_6A"); await p.fill("#pass2", "farkli123");
await p.click("#authBtn"); await p.waitForTimeout(400);
check("şifreler uyuşmazsa reddedilir", /aynı değil/.test(await p.textContent("#authMsg")));
if (shots) await p.screenshot({ path: shots + "/auth-register.png" });
await p.fill("#pass2", "gizli123");
await p.click("#authBtn"); await p.waitForFunction(() => !document.getElementById("mainView").classList.contains("hidden"), null, { timeout: 8000 });
check("hesap oluşturulunca ana menü açılır, adı görünür", (await p.textContent("#who")) === "Burak_6A");
if (shots) await p.screenshot({ path: shots + "/auth-menu.png" });

await p.reload(); await ready();
check("sayfa yenilenince oturum korunur", (await vis("mainView")) && (await p.textContent("#who")) === "Burak_6A");

await p.click("#logout"); await p.waitForTimeout(150);
check("çıkış yapınca giriş ekranına dönülür", await vis("loginView"));
await p.fill("#user", "burak_6a"); await p.fill("#pass", "gizli123");
await p.click("#authBtn"); await p.waitForFunction(() => !document.getElementById("mainView").classList.contains("hidden"), null, { timeout: 8000 });
check("doğru şifreyle giriş yapılır (büyük/küçük harf fark etmez)", (await p.textContent("#who")) === "Burak_6A");

await p.click("#logout"); await p.waitForTimeout(100);
await p.click("#guestBtn"); await p.waitForTimeout(150);
check("misafir olarak devam edilir", (await vis("mainView")) && (await p.textContent("#who")) === "Misafir");

// yazı alanında oyun tuşları çalışmaz
await p.click("#logout"); await p.waitForTimeout(100);
await p.focus("#user"); await p.keyboard.type("fire r w space");
const typed = await p.inputValue("#user");
check("kullanıcı adı alanına F/R/W/boşluk yazılabilir", typed.startsWith("fire r w") || typed.length >= 8, JSON.stringify(typed));

// oyuna başla (misafir) ve oyun tuşlarının çalıştığını doğrula
await p.click("#guestBtn"); await p.waitForTimeout(100);
await p.click("#keyboard"); await p.waitForTimeout(400);
const before = await p.evaluate(() => window.GAME.g.shells);
await p.keyboard.down("KeyF"); await p.waitForTimeout(80); await p.keyboard.up("KeyF");
await p.waitForTimeout(150);
check("giriş sonrası oyun başlar, F ateş eder", (await p.evaluate(() => window.GAME.g.shells)) === before - 1);
check("sayfa hatası yok", errs.length === 0, errs.join(" | "));
await b.close(); srv.close();
process.exit(results.every(Boolean) ? 0 : 1);
