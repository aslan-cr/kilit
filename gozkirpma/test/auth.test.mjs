import test from "node:test";
import assert from "node:assert/strict";
import { createAuth, memoryStore, validateUsername, validatePassword } from "../src/main/assets/js/auth.js";

const mk = (extra = {}) => { const store = memoryStore(); let t = 1000; const clock = { t }; return { store, clock, auth: createAuth({ store, iter: 1000, now: () => clock.t, ...extra }) }; };

test("hesap oluştur, çıkış yap, doğru şifreyle gir", async () => {
  const { auth } = mk();
  assert.equal(auth.current(), null);
  const r = await auth.register("Burak_1", "gizli123", "gizli123");
  assert.ok(r.ok, r.error);
  assert.deepEqual(auth.current(), { name: "Burak_1", guest: false });
  auth.logout();
  assert.equal(auth.current(), null);
  assert.ok((await auth.login("burak_1", "gizli123")).ok, "büyük/küçük harf fark etmez");
  assert.equal(auth.current().name, "Burak_1");
});

test("yanlış şifre ve olmayan kullanıcı aynı hatayı verir", async () => {
  const { auth } = mk();
  await auth.register("Ayse", "dogru-sifre");
  auth.logout();
  const a = await auth.login("Ayse", "yanlis"), b = await auth.login("YokBoyle", "yanlis");
  assert.equal(a.ok, false); assert.equal(b.ok, false);
  assert.equal(a.error, b.error);
  assert.equal(auth.current(), null);
});

test("aynı kullanıcı adı iki kez alınamaz; geçersiz ad/şifre reddedilir", async () => {
  const { auth } = mk();
  assert.ok((await auth.register("Kaan", "123456")).ok);
  assert.equal((await auth.register("kaan", "654321")).ok, false);
  assert.match((await auth.register("a", "123456")).error, /3-16/);
  assert.match((await auth.register("Gecerli", "123")).error, /en az 6/);
  assert.match((await auth.register("Gecerli", "123456", "123457")).error, /aynı değil/);
  assert.notEqual(validateUsername("ab c"), "");
  assert.equal(validateUsername("Çağrı_9"), "");
  assert.equal(validatePassword("123456"), "");
});

test("şifre düz metin saklanmaz", async () => {
  const { auth, store } = mk();
  await auth.register("Zeynep", "cok-gizli-parola");
  const raw = store.get("gk_users");
  assert.ok(!raw.includes("cok-gizli-parola"));
  const u = JSON.parse(raw).zeynep;
  assert.ok(u.salt && u.hash && u.hash.length > 20);
});

test("5 yanlış denemeden sonra 30 sn kilit; süre geçince açılır", async () => {
  const { auth, clock } = mk();
  await auth.register("Mert", "dogru-sifre"); auth.logout();
  for (let i = 0; i < 5; i++) assert.equal((await auth.login("Mert", "x" + i)).ok, false);
  const locked = await auth.login("Mert", "dogru-sifre");
  assert.equal(locked.ok, false); assert.match(locked.error, /bekle/);
  clock.t += 31000;
  assert.ok((await auth.login("Mert", "dogru-sifre")).ok);
});

test("misafir girişi; istatistikler hesap başına ayrı tutulur", async () => {
  const { auth } = mk();
  auth.guest();
  assert.deepEqual(auth.current(), { name: "Misafir", guest: true });
  auth.recordGame({ win: true, time: 80, kills: 3 });
  assert.equal(auth.stats().best, 80);
  await auth.register("Ece", "parola123");
  assert.equal(auth.stats().games, 0, "yeni hesap sıfırdan başlar");
  auth.recordGame({ win: true, time: 60, kills: 2, coins: 30 });
  auth.recordGame({ win: true, time: 90, kills: 1, coins: 15 });
  auth.recordGame({ win: false, time: 20, kills: 0 });
  assert.deepEqual(auth.stats(), { games: 3, wins: 2, deaths: 1, kills: 3, best: 60, coins: 45 });
  auth.logout(); auth.guest();
  assert.equal(auth.stats().best, 80, "misafir istatistiği korunur");
});

test("oturum kalıcıdır (aynı depolama, yeni nesne)", async () => {
  const { auth, store } = mk();
  await auth.register("Deniz", "parola123");
  const again = createAuth({ store, iter: 1000 });
  assert.equal(again.current().name, "Deniz");
});
