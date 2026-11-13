// İblis (iskeletsiz, duruk GLB) -> oyunun models.json'una "demon" karakteri olarak pişirir.
//   npm i meshoptimizer@0.22.0   (yalnızca bu araç için, oyuna girmez)
//   node tools/bake-demon.mjs <demon.glb> [üçgen hedefi=12000] [models.json]
// Modelde iskelet ve animasyon yoktur; ikisi de burada üretilir:
//   1) elle yerleştirilmiş 16 kemik, köşe ağırlıkları kemik doğru parçalarına uzaklıktan
//   2) kodla üretilen yürüme döngüsü (bacak/kol salınımı, diz bükme, gövde dönmesi, baş sallama)
//   3) yüz belli olsun diye: göz çukurları koyulaştırılır, içine parlayan göz küreleri eklenir
// Çıktı biçimi bake-runner.mjs ile aynıdır (skin.frames = kare başına eklem 3x4 matrisleri), çizici değişmeden oynatır.
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { MeshoptSimplifier } from "meshoptimizer";

const [glbPath, targetArg, outArg] = process.argv.slice(2);
if (!glbPath) { console.error("kullanım: node tools/bake-demon.mjs <model.glb> [üçgen hedefi] [models.json]"); process.exit(1); }
const TARGET_TRIS = Number(targetArg) || 12000;
const outPath = outArg || new URL("../src/main/assets/models/models.json", import.meta.url).pathname;
const FRAMES = 24;

// ---- GLB oku ----
const buf = fs.readFileSync(glbPath);
const jl = buf.readUInt32LE(12), J = JSON.parse(buf.slice(20, 20 + jl).toString("utf8"));
const binOff = 20 + jl, BIN = buf.slice(binOff + 8, binOff + 8 + buf.readUInt32LE(binOff));
function acc(i) {
  const a = J.accessors[i], bv = J.bufferViews[a.bufferView];
  const n = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[a.type], size = { 5126: 4, 5125: 4, 5123: 2, 5121: 1 }[a.componentType];
  const base = (bv.byteOffset || 0) + (a.byteOffset || 0), stride = bv.byteStride || n * size;
  const out = a.componentType === 5126 ? new Float32Array(a.count * n) : new Uint32Array(a.count * n);
  for (let k = 0; k < a.count; k++) for (let c = 0; c < n; c++) {
    const o = base + k * stride + c * size;
    out[k * n + c] = a.componentType === 5126 ? BIN.readFloatLE(o) : a.componentType === 5125 ? BIN.readUInt32LE(o) : a.componentType === 5123 ? BIN.readUInt16LE(o) : BIN[o];
  }
  return out;
}
const prim = J.meshes[0].primitives[0];
const POS = acc(prim.attributes.POSITION), UV = acc(prim.attributes.TEXCOORD_0), IDX = acc(prim.indices);

// ---- Seyreltme ----
// Bu modelin doku haritası çok parçalı (neredeyse her üçgen ayrı ada): doku dikişleri seyreltmeyi kilitler.
// Bu yüzden köşeler konuma göre kaynaştırılır, doku üçgen başına düz renge pişirilir (çizici zaten düşük çözünürlüklü).
const key = (i) => Math.round(POS[i * 3] * 5e4) + "," + Math.round(POS[i * 3 + 1] * 5e4) + "," + Math.round(POS[i * 3 + 2] * 5e4);
const uniq = new Map(), wPos = [], wIdx = new Uint32Array(IDX.length);
for (let t = 0; t < IDX.length; t++) { const v = IDX[t], kk = key(v); let u = uniq.get(kk); if (u === undefined) { u = wPos.length / 3; uniq.set(kk, u); wPos.push(POS[v * 3], POS[v * 3 + 1], POS[v * 3 + 2]); } wIdx[t] = u; }
const WP = new Float32Array(wPos);
await MeshoptSimplifier.ready;
MeshoptSimplifier.useExperimentalFeatures = true;
const simp = MeshoptSimplifier.simplify(wIdx, WP, 3, TARGET_TRIS * 3, 0.05, ["Prune"]);
const remap = new Int32Array(WP.length / 3).fill(-1), keep = [], idx = [];
for (const v of simp[0]) { if (remap[v] < 0) { remap[v] = keep.length; keep.push(v); } idx.push(remap[v]); }
console.log(`seyreltme: ${IDX.length / 3} -> ${idx.length / 3} üçgen, ${keep.length} köşe, hata ${simp[1].toFixed(4)}`);
const POSK = WP;      // keep[] bu dizinin köşelerini gösterir

// ---- Renk: her üçgen için asıl dokudan örnekle (en yakın asıl köşenin UV'si) ----
const TS = 1024, texImg = J.images[J.textures[J.materials[prim.material].pbrMetallicRoughness.baseColorTexture.index].source], tbv = J.bufferViews[texImg.bufferView];
const tmpJ = path.join(path.dirname(outPath), "_demon_src.jpg"), tmpR = path.join(path.dirname(outPath), "_demon_src.rgb");
fs.writeFileSync(tmpJ, BIN.slice(tbv.byteOffset || 0, (tbv.byteOffset || 0) + tbv.byteLength));
execFileSync("convert", [tmpJ, "-resize", `${TS}x${TS}!`, "-depth", "8", "rgb:" + tmpR]);
const RGB = fs.readFileSync(tmpR); fs.unlinkSync(tmpJ); fs.unlinkSync(tmpR);
const CELL = 0.012, grid = new Map(), gk = (x, y, z) => Math.floor(x / CELL) + "," + Math.floor(y / CELL) + "," + Math.floor(z / CELL);
for (let v = 0; v < POS.length / 3; v++) { const kk = gk(POS[v * 3], POS[v * 3 + 1], POS[v * 3 + 2]); let g = grid.get(kk); if (!g) grid.set(kk, (g = [])); g.push(v); }
function sample(x, y, z) {
  let best = -1, bd = 1e9; const cx0 = Math.floor(x / CELL), cy0 = Math.floor(y / CELL), cz0 = Math.floor(z / CELL);
  for (let r = 1; r <= 3 && best < 0; r++) for (let a = -r; a <= r; a++) for (let b = -r; b <= r; b++) for (let c = -r; c <= r; c++) {
    const g = grid.get((cx0 + a) + "," + (cy0 + b) + "," + (cz0 + c)); if (!g) continue;
    for (const v of g) { const d = (POS[v * 3] - x) ** 2 + (POS[v * 3 + 1] - y) ** 2 + (POS[v * 3 + 2] - z) ** 2; if (d < bd) { bd = d; best = v; } } }
  if (best < 0) return [60, 60, 70];
  const px = Math.min(TS - 1, Math.max(0, Math.floor(UV[best * 2] * TS))), py = Math.min(TS - 1, Math.max(0, Math.floor(UV[best * 2 + 1] * TS))), o = (py * TS + px) * 3;
  return [RGB[o], RGB[o + 1], RGB[o + 2]];
}
const col = [];
for (let t = 0; t < idx.length; t += 3) {
  const P3 = [0, 1, 2].map((q) => { const v = keep[idx[t + q]]; return [POSK[v * 3], POSK[v * 3 + 1], POSK[v * 3 + 2]]; });
  const acc3 = [0, 0, 0];
  for (const w of [[1 / 3, 1 / 3, 1 / 3], [0.6, 0.2, 0.2], [0.2, 0.6, 0.2], [0.2, 0.2, 0.6]]) { const c = sample(...[0, 1, 2].map((a) => P3[0][a] * w[0] + P3[1][a] * w[1] + P3[2][a] * w[2])); for (let a = 0; a < 3; a++) acc3[a] += c[a] / 4; }
  col.push(...acc3.map(Math.round));
}

// ---- İskelet (model uzayı: y yukarı, +z ileri, boy ~1). [ad, ebeveyn, baş, uç] ----
const BONES = [
  ["hips", -1, [0, 0.44, -0.09], [0, 0.52, -0.06]],
  ["spine", 0, [0, 0.52, -0.06], [0, 0.63, 0.0]],
  ["chest", 1, [0, 0.63, 0.0], [-0.02, 0.72, 0.1]],
  ["head", 2, [-0.03, 0.73, 0.14], [-0.035, 0.78, 0.36]],
  ["armL", 2, [-0.24, 0.68, 0.0], [-0.35, 0.47, -0.02]],
  ["foreL", 4, [-0.35, 0.47, -0.02], [-0.38, 0.22, 0.08]],
  ["handL", 5, [-0.38, 0.22, 0.08], [-0.37, 0.07, 0.1]],
  ["armR", 2, [0.24, 0.66, 0.0], [0.31, 0.47, -0.03]],
  ["foreR", 7, [0.31, 0.47, -0.03], [0.37, 0.22, 0.06]],
  ["handR", 8, [0.37, 0.22, 0.06], [0.36, 0.08, 0.12]],
  ["thighL", 0, [-0.11, 0.42, -0.12], [-0.125, 0.26, -0.13]],
  ["shinL", 10, [-0.125, 0.26, -0.13], [-0.21, 0.08, -0.35]],
  ["footL", 11, [-0.21, 0.08, -0.35], [-0.25, 0.0, -0.24]],
  ["thighR", 0, [0.11, 0.42, -0.07], [0.10, 0.26, 0.02]],
  ["shinR", 13, [0.10, 0.26, 0.02], [0.14, 0.07, -0.02]],
  ["footR", 14, [0.14, 0.07, -0.02], [0.17, 0.0, 0.12]],
];
const B = Object.fromEntries(BONES.map((b, i) => [b[0], i]));
// ağırlık için ek doğru parçaları (omuz kütlesi göğse bağlansın)
const SEGS = BONES.map((b, i) => [i, b[2], b[3]]).concat([[B.chest, [0, 0.67, 0], [-0.24, 0.68, 0]], [B.chest, [0, 0.67, 0], [0.24, 0.66, 0]], [B.head, [-0.03, 0.8, 0.2], [-0.03, 0.95, 0.1]]]);
function segDist(p, a, b) {
  const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], ap = [p[0] - a[0], p[1] - a[1], p[2] - a[2]];
  const t = Math.max(0, Math.min(1, (ap[0] * ab[0] + ap[1] * ab[1] + ap[2] * ab[2]) / (ab[0] ** 2 + ab[1] ** 2 + ab[2] ** 2)));
  return Math.hypot(ap[0] - ab[0] * t, ap[1] - ab[1] * t, ap[2] - ab[2] * t);
}
const jj = [], ww = [];
for (const v of keep) {
  const p = [POSK[v * 3], POSK[v * 3 + 1], POSK[v * 3 + 2]];
  const best = new Map();
  for (const [bi, a, b] of SEGS) { const d = segDist(p, a, b); if (!best.has(bi) || d < best.get(bi)) best.set(bi, d); }
  let L = [...best.entries()].sort((x, y) => x[1] - y[1]).slice(0, 3).map(([bi, d]) => [bi, 1 / (d * d + 2e-4) ** 2]);
  const s = L.reduce((a, x) => a + x[1], 0);
  L = L.map(([bi, w]) => [bi, w / s]).filter((x) => x[1] > 0.04);
  const s2 = L.reduce((a, x) => a + x[1], 0);
  for (let c = 0; c < 4; c++) { jj.push(L[c] ? L[c][0] : 0); ww.push(L[c] ? Math.round((L[c][1] / s2) * 1000) / 1000 : 0); }
}

// ---- Gözler: yüz belli olsun. Çukur dokuda koyulaşır, içine parlayan küre gelir (baş kemiğine bağlı) ----
const EYES = [[-0.075, 0.765, 0.342], [0.003, 0.765, 0.347]], EYE_R = 0.016;
let sockets = 0;
for (let t = 0; t < idx.length; t += 3) {
  const c = [0, 0, 0]; for (let q = 0; q < 3; q++) { const v = keep[idx[t + q]]; c[0] += POSK[v * 3] / 3; c[1] += POSK[v * 3 + 1] / 3; c[2] += POSK[v * 3 + 2] / 3; }
  const d = Math.min(...EYES.map((e) => Math.hypot(c[0] - e[0], (c[1] - e[1]) * 1.3, (c[2] - e[2]) * 0.6)));
  if (d < 0.034) { const f = d < 0.024 ? 0.12 : 0.45; for (let a = 0; a < 3; a++) col[t + a] = Math.round(col[t + a] * f); sockets++; }
}
const eyePos = [], eyeIdx = [], eJ = [], eW = [];
for (const e of EYES) {
  const base = eyePos.length / 3, W = 8, H = 6;
  for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) { const u = (x / W) * 2 * Math.PI, v = (y / H) * Math.PI;
    eyePos.push(e[0] + EYE_R * Math.cos(u) * Math.sin(v), e[1] + EYE_R * 0.8 * Math.cos(v), e[2] - 0.004 + EYE_R * Math.sin(u) * Math.sin(v)); eJ.push(B.head, 0, 0, 0); eW.push(1, 0, 0, 0); }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const a = base + y * (W + 1) + x, b = a + W + 1; eyeIdx.push(a, b, a + 1, b, b + 1, a + 1); }
}

// ---- Matrisler (sütun öncelikli 4x4) ----
const mul = (a, b) => { const o = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k]; return o; };
const T = (x, y, z) => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];
const RX = (a) => { const c = Math.cos(a), s = Math.sin(a); return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1]; };   // +a: aşağı sarkan uzuv geriye (-z) gider
const RY = (a) => { const c = Math.cos(a), s = Math.sin(a); return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1]; };
const about = (p, R) => mul(T(p[0], p[1], p[2]), mul(R, T(-p[0], -p[1], -p[2])));
const xf = (m, x, y, z) => [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13], m[2] * x + m[6] * y + m[10] * z + m[14]];

// ---- Yürüme döngüsü: ph 0..1. Duruk poz zaten bir adım ortası (sol bacak geride, sağ önde); salınım ortalaması simetrik olsun diye ±0.37 rad kaydırılır ----
function pose(ph) {
  const s = Math.sin(ph * 2 * Math.PI), c = Math.cos(ph * 2 * Math.PI), c2 = Math.cos(ph * 4 * Math.PI), s2 = Math.sin(ph * 4 * Math.PI);
  const up = (x) => Math.pow(Math.max(0, x), 1.5);
  const kL = 0.85 * up(c) - 0.15, kR = 0.85 * up(-c) + 0.2;      // diz: bacak öne savrulurken bükülür
  const L = {
    hips: mul(T(0, 0.016 * c2 - 0.01, 0), mul(RY(0.09 * s), RX(-0.05))),
    spine: mul(RY(-0.1 * s), RX(-0.03 * c2)), chest: RY(-0.09 * s),
    head: mul(RY(0.1 * s), RX(0.05 * s2)),
    thighL: RX(-(0.37 + 0.5 * s)), shinL: RX(kL), footL: RX(-kL * 0.35),
    thighR: RX(0.37 + 0.5 * s), shinR: RX(kR), footR: RX(-kR * 0.35),
    armL: RX(-(0.3 - 0.4 * s)), foreL: RX(-(0.45 - 0.25 * s)), handL: RX(-0.15),
    armR: RX(-(0.3 + 0.4 * s)), foreR: RX(-(0.45 + 0.25 * s)), handR: RX(-0.15),
  };
  const W = [];
  BONES.forEach(([name, par, head], i) => { const loc = about(head, L[name]); W[i] = par < 0 ? loc : mul(W[par], loc); });
  return W;
}
function skinAt(M) {
  const out = new Float32Array(keep.length * 3);
  keep.forEach((v, i) => { const x = POSK[v * 3], y = POSK[v * 3 + 1], z = POSK[v * 3 + 2];
    for (let c = 0; c < 4; c++) { const w = ww[i * 4 + c]; if (!w) continue; const p = xf(M[jj[i * 4 + c]], x, y, z); out[i * 3] += p[0] * w; out[i * 3 + 1] += p[1] * w; out[i * 3 + 2] += p[2] * w; } });
  return out;
}

// ---- Oyun uzayı: ayaklar 0'da (karelerin en alçak noktası), boy 1 birim ----
let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9]; const lows = [];
for (let f = 0; f < FRAMES; f++) { const P = skinAt(pose(f / FRAMES)); let lo = 1e9;
  for (let i = 0; i < P.length; i += 3) { for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], P[i + a]); mx[a] = Math.max(mx[a], P[i + a]); } lo = Math.min(lo, P[i + 1]); } lows.push(lo); }
const k = 1 / (mx[1] - mn[1]), cx = 0, cz = (mn[2] + mx[2]) / 2;
const r5 = (v) => Math.round(v * 1e5) / 1e5, r4 = (v) => Math.round(v * 1e4) / 1e4;
const frames = [];
for (let f = 0; f < FRAMES; f++) {
  const N = [k, 0, 0, 0, 0, k, 0, 0, 0, 0, k, 0, -cx * k, -lows[f] * k, -cz * k, 1];     // her karede basan ayak yere değsin
  const Ninv = [1 / k, 0, 0, 0, 0, 1 / k, 0, 0, 0, 0, 1 / k, 0, cx, mn[1], cz, 1];
  frames.push(pose(f / FRAMES).flatMap((m0) => { const m = mul(N, mul(m0, Ninv)); return [m[0], m[4], m[8], m[12], m[1], m[5], m[9], m[13], m[2], m[6], m[10], m[14]].map(r5); }));
}
const N0 = [k, 0, 0, 0, 0, k, 0, 0, 0, 0, k, 0, -cx * k, -mn[1] * k, -cz * k, 1];
const pos = [];
for (const v of keep) pos.push(...xf(N0, POSK[v * 3], POSK[v * 3 + 1], POSK[v * 3 + 2]).map(r4));
const ePos = []; for (let i = 0; i < eyePos.length; i += 3) ePos.push(...xf(N0, eyePos[i], eyePos[i + 1], eyePos[i + 2]).map(r4));
const eyes = EYES.map((e) => xf(N0, e[0], e[1], e[2] + 0.02).map(r4));
const bb = { min: [mn[0] * k, 0, (mn[2] - cz) * k].map(r4), max: [mx[0] * k, 1, (mx[2] - cz) * k].map(r4) };

const json = JSON.parse(fs.readFileSync(outPath, "utf8"));
json.chars.demon = {
  mats: [{ n: "Demon", c: [255, 255, 255], d: 0, e: 0 }, { n: "Eye_flame", c: [255, 96, 24], d: 0, e: 1 }],
  parts: [{ name: "body", pivot: [0, 0, 0], mat: 0, pos, idx, col, j: jj, w: ww }, { name: "eyes", pivot: [0, 0, 0], mat: 1, pos: ePos, idx: eyeIdx, j: eJ, w: eW }],
  skin: { nj: BONES.length, dur: 0.9, frames }, eyes, bb,
};
fs.writeFileSync(outPath, JSON.stringify(json));
console.log(`iblis pişirildi: ${idx.length / 3} + ${eyeIdx.length / 3} üçgen, ${keep.length} köşe, ${FRAMES} kare, göz çukuru ${sockets} üçgen, gözler ${JSON.stringify(eyes)}, bb ${JSON.stringify(bb)}`);
