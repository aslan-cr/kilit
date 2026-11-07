import test from "node:test";
import assert from "node:assert/strict";
import { RULES } from "../src/main/assets/js/rules.js";
import { connectLocal, normalizeUrl } from "../src/main/assets/js/net.js";
import { cabin } from "../src/main/assets/js/rooms.js";

test("adres düzeltme", () => {
  assert.equal(normalizeUrl("192.168.1.5:8080"), "ws://192.168.1.5:8080");
  assert.equal(normalizeUrl("https://x.com"), "wss://x.com");
  assert.equal(normalizeUrl(" wss://x.com/a "), "wss://x.com/a");
  assert.equal(normalizeUrl(""), "");
});

test("çevrimdışı lobi: odaya girince sayaç işler, bitince oyun başlar; çıkınca sayaç durur", () => {
  let tick, snaps = [], started = null, welcome = null;
  const rules = { ...RULES, lobby: { ...RULES.lobby, countdown: 2 } };
  const api = connectLocal(rules, "Bera", { onWelcome: (m) => { welcome = m; }, onSnap: (m) => snaps.push(m), onStart: (m) => { started = m; } },
    { tickMs: 500, setIntervalFn: (f) => { tick = f; return 1; }, clearIntervalFn: () => {} });
  assert.equal(welcome.name, "Bera"); assert.ok(api.local);
  tick(); assert.equal(snaps.at(-1).rooms[0].t, null);
  const c = cabin(rules, 0);
  api.send({ t: "pos", x: c.cx, y: c.cy });
  tick(); assert.equal(snaps.at(-1).rooms[0].n, 1); assert.equal(snaps.at(-1).rooms[0].t, 2, "ilk tik sayaçtan 0.5 düşmüştür ya da tam değer");
  api.send({ t: "pos", x: 13, y: 12 });                       // salona çık
  tick(); assert.equal(snaps.at(-1).rooms[0].t, null); assert.equal(started, null);
  api.send({ t: "pos", x: c.cx, y: c.cy });
  for (let i = 0; i < 6 && !started; i++) tick();
  assert.ok(started && started.room === 0 && started.seed > 0);
  api.send({ t: "back" }); tick();
  assert.equal(snaps.at(-1).rooms[0].st, "open");
  api.close(); assert.equal(api.open, false);
});

test("çevrimdışı lobi: dolu olmayan odaya girilir, reddedilme yok (tek oyuncu)", () => {
  let denied = false, tick;
  const api = connectLocal(RULES, "A", { onDeny: () => { denied = true; } }, { setIntervalFn: (f) => { tick = f; return 1; }, clearIntervalFn: () => {} });
  for (let i = 0; i < 4; i++) { const c = cabin(RULES, i); api.send({ t: "pos", x: c.cx, y: c.cy }); }
  assert.equal(denied, false);
});
