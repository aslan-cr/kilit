// Kişiye göre göz eşiği: gözü doğal olarak yarı açık olan kişi de oynayabilsin (açık hâli "kapalı" sayılmasın), gerçek kapanma yine algılansın.
import test from "node:test";
import assert from "node:assert/strict";
import { eyeLimits, updateBase } from "../src/main/assets/js/eyes.js";
import { RULES } from "../src/main/assets/js/rules.js";
const E = RULES.eyes;

function run(frames) {            // [skor,...] -> { states, base }
  let base = null, closed = false; const st = [];
  for (const s of frames) {
    base = updateBase(base, s, E);
    const lim = eyeLimits(base, E);
    if (!closed && s > lim.close) closed = true; else if (closed && s < lim.open) closed = false;
    st.push(closed);
  }
  return { st, base };
}

test("normal göz: açık ~0.05 kapalı sayılmaz, 0.9 kapanır, geri açılır", () => {
  const { st } = run([0.05, 0.06, 0.05, 0.9, 0.95, 0.1, 0.05]);
  assert.deepEqual(st, [false, false, false, true, true, false, false]);
});

test("gözü yarı açık kişi: açık hâli 0.35-0.4 olsa da sürekli kapalı sayılmaz, tam kapanma algılanır", () => {
  const open = Array.from({ length: 60 }, (_, i) => 0.36 + 0.03 * Math.sin(i));
  const { st, base } = run([...open, 0.85, 0.9, 0.9, 0.38, 0.37]);
  assert.ok(st.slice(0, 60).every((x) => !x), "açık göz kapalı sayıldı");
  assert.equal(st[61], true, "tam kapanma algılanmadı");
  assert.equal(st[st.length - 1], false, "göz açılınca açık olmalı");
  assert.ok(base > 0.3 && base <= E.baseMax, "taban " + base);
});

test("taban kapalı gözle şişmez; eşikler her zaman açılış < kapanış", () => {
  let base = 0.05; for (let i = 0; i < 300; i++) base = updateBase(base, 0.95, E);
  assert.ok(base < 0.1, "kapalı göz tabanı yükseltti: " + base);
  for (const b of [0, 0.1, 0.3, 0.45]) { const l = eyeLimits(b, E); assert.ok(l.open < l.close && l.close <= E.closeMax); }
});
