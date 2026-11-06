// Bot dengesi: node test/balance.mjs [seed sayısı] [kural=değer ...]  örn: node test/balance.mjs 40 enemies.count=6
import { RULES } from "../src/main/assets/js/rules.js";
import { createGame, step, rng } from "../src/main/assets/js/sim.js";
import { makeBot } from "../src/main/assets/js/bot.js";

const N = Number(process.argv[2] || 40);
const R = JSON.parse(JSON.stringify(RULES));
for (const a of process.argv.slice(3)) { const [k, v] = a.split("="); const p = k.split("."); let o = R; for (let i = 0; i < p.length - 1; i++) o = o[p[i]]; o[p.at(-1)] = Number(v); }

export function playOne(seed, rules = R, maxSec = 600) {
  const g = createGame(seed, rules);
  const bot = makeBot(g, { rand: rng(seed * 7919 + 1) });
  const DT = 1 / 60;
  let forced = 0;
  while (g.state === "play" && g.time < maxSec) {
    step(g, DT, bot(DT));
    for (const e of g.events) if (e.t === "forcedBlink") forced++;
    g.events.length = 0;
  }
  return { seed, state: g.state === "play" ? "timeout" : g.state, time: g.time, flies: g.collected, kills: g.kills, shots: g.shots, hits: g.hits, forced };
}

if (process.argv[1].endsWith("balance.mjs")) {
  const res = [];
  for (let s = 1; s <= N; s++) res.push(playOne(s));
  const won = res.filter((r) => r.state === "won"), dead = res.filter((r) => r.state === "dead"), to = res.filter((r) => r.state === "timeout");
  const avg = (a, f) => (a.length ? (a.reduce((x, r) => x + f(r), 0) / a.length).toFixed(1) : "-");
  console.log(`Seed: ${N}  kazanma %${((100 * won.length) / N).toFixed(0)}  ölüm %${((100 * dead.length) / N).toFixed(0)}  zaman aşımı %${((100 * to.length) / N).toFixed(0)}`);
  console.log(`Kazananlarda ort. süre ${avg(won, (r) => r.time)} sn, ort. öldürme ${avg(won, (r) => r.kills)}, ort. atış ${avg(won, (r) => r.shots)}, zorunlu kırpma ${avg(won, (r) => r.forced)}`);
  console.log(`Kaybedenlerde ort. böcek ${avg(dead, (r) => r.flies)}/${R.goal.flies}, ort. süre ${avg(dead, (r) => r.time)} sn`);
  const hist = {}; for (const r of dead) hist[r.flies] = (hist[r.flies] || 0) + 1;
  console.log("Ölümler (toplanan böcek sayısına göre):", JSON.stringify(hist));
}
