// Yakalanma sahnelerinin seslerini WAV dosyasına kaydeder (OfflineAudioContext, headless chromium). Kulakla ve spektrogramla denetim için.
//   node tools/sfx-render.mjs <çıktı klasörü> [tackle stab snap]
// Her sahne: görüntü + 0.5 sn karanlık + iki satır yazı vuruşu (main.js'teki zamanlamayla).
import fs from "node:fs";
import { createRequire } from "node:module";
import { serve } from "./serve.mjs";
const { chromium } = createRequire(import.meta.url)("playwright");
const [outDir = ".", ...names] = process.argv.slice(2);
const list = names.length ? names : ["tackle", "stab", "snap"];
const port = 5900 + Math.floor(Math.random() * 90);
const srv = await serve(port);
const b = await chromium.launch();
const p = await b.newPage();
const errs = []; p.on("pageerror", (e) => errs.push(e.message));
await p.goto(`http://localhost:${port}/index.html?scare=0.1`);
fs.mkdirSync(outDir, { recursive: true });
for (const name of list) {
  const res = await p.evaluate(async (name) => {
    const { makeSfx } = await import("/js/sfx.js");
    const Rn = await import("/js/render.js"), { RULES } = await import("/js/rules.js");
    const T = { tackle: Rn.TACKLE, stab: Rn.STAB, snap: Rn.SNAP }[name], S = RULES.scare;
    const txt = T.end + S.black, dur = txt + S.text + 1, sr = 44100;
    const ctx = new OfflineAudioContext(2, Math.ceil(sr * dur), sr);
    const fx = makeSfx(ctx, ctx.destination);
    fx.scene(name, T); fx.text(1, txt); fx.text(2, txt + S.line2);
    const buf = await ctx.startRendering();
    const L = buf.getChannelData(0), Rr = buf.getChannelData(1);
    let peak = 0; for (let i = 0; i < L.length; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(Rr[i]));
    const pcm = new Int16Array(L.length * 2);
    for (let i = 0; i < L.length; i++) { pcm[i * 2] = Math.max(-1, Math.min(1, L[i])) * 32767; pcm[i * 2 + 1] = Math.max(-1, Math.min(1, Rr[i])) * 32767; }
    return { sr, peak, data: Array.from(new Uint8Array(pcm.buffer)) };
  }, name);
  const data = Buffer.from(res.data), h = Buffer.alloc(44);
  h.write("RIFF", 0); h.writeUInt32LE(36 + data.length, 4); h.write("WAVE", 8); h.write("fmt ", 12); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22); h.writeUInt32LE(res.sr, 24); h.writeUInt32LE(res.sr * 4, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(16, 34);
  h.write("data", 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(`${outDir}/${name}.wav`, Buffer.concat([h, data]));
  console.log(name, "tepe", res.peak.toFixed(3));
}
console.log(errs.length ? errs : "hata yok");
await b.close(); srv.close();
