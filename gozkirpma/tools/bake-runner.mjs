// Koşucu Canavar (iskeletli + "Run" animasyonlu GLB) -> oyunun models.json'una "runner" karakteri olarak pişirir.
//   npm i meshoptimizer@0.22.0   (yalnızca bu araç için, oyuna girmez)
//   node tools/bake-runner.mjs <fantasy_monster.glb> [üçgen hedefi=12000] [models.json]
// Çıktı: chars.runner = { tex, parts:[{ name, pos, uv, idx, j, w }], skin:{ frames, nj, dur, stride }, bb }
//   skin.frames[f][joint] = 3x4 matris (oyun uzayında, bağlama pozu -> f. kare). Çizici köşeleri her karede kendisi deriler.
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { MeshoptSimplifier } from "meshoptimizer";

const [glbPath, targetArg, outArg] = process.argv.slice(2);
if (!glbPath) { console.error("kullanım: node tools/bake-runner.mjs <model.glb> [üçgen hedefi] [models.json]"); process.exit(1); }
const TARGET_TRIS = Number(targetArg) || 12000;
const outPath = outArg || new URL("../src/main/assets/models/models.json", import.meta.url).pathname;
const texDir = path.join(path.dirname(outPath), "tex");
const FRAMES = 24;                  // animasyondan örneklenen kare sayısı (döngü)
const TEX = 512;                    // doku boyu (yazılım çizici için yeterli)

// ---- GLB oku ----
const buf = fs.readFileSync(glbPath);
const jl = buf.readUInt32LE(12), J = JSON.parse(buf.slice(20, 20 + jl).toString("utf8"));
const binOff = 20 + jl, BIN = buf.slice(binOff + 8, binOff + 8 + buf.readUInt32LE(binOff));
function acc(i) {
  const a = J.accessors[i], bv = J.bufferViews[a.bufferView];
  const n = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[a.type], size = { 5126: 4, 5125: 4, 5123: 2, 5121: 1 }[a.componentType];
  const base = (bv.byteOffset || 0) + (a.byteOffset || 0), stride = bv.byteStride || n * size;
  const out = a.componentType === 5126 ? new Float32Array(a.count * n) : new Uint32Array(a.count * n);
  for (let k = 0; k < a.count; k++) for (let c = 0; c < n; c++) {
    const o = base + k * stride + c * size;
    out[k * n + c] = a.componentType === 5126 ? BIN.readFloatLE(o) : a.componentType === 5125 ? BIN.readUInt32LE(o) : a.componentType === 5123 ? BIN.readUInt16LE(o) : BIN[o];
  }
  return out;
}
const prim = J.meshes[0].primitives[0];
const POS = acc(prim.attributes.POSITION), UV = acc(prim.attributes.TEXCOORD_0);
const JNT = acc(prim.attributes.JOINTS_0), WGT = acc(prim.attributes.WEIGHTS_0), IDX = acc(prim.indices);
const nv = POS.length / 3;

// ---- Seyreltme (köşeler aynı kalır, yalnızca bazıları atılır: derileme verisi bozulmaz) ----
await MeshoptSimplifier.ready;
MeshoptSimplifier.useExperimentalFeatures = true;
const uvAttr = new Float32Array(UV);
const simp = MeshoptSimplifier.simplifyWithAttributes(IDX, POS, 3, uvAttr, 2, [0.5], null, TARGET_TRIS * 3, 0.05, []);
const sIdx = simp[0];
const remap = new Int32Array(nv).fill(-1), keep = [];
const idx = [];
for (const v of sIdx) { if (remap[v] < 0) { remap[v] = keep.length; keep.push(v); } idx.push(remap[v]); }
console.log(`seyreltme: ${IDX.length / 3} -> ${sIdx.length / 3} üçgen, ${nv} -> ${keep.length} köşe, hata ${simp[1].toFixed(4)}`);

// ---- Düğüm dönüşümleri ve animasyon ----
const mat = {
  trs(t = [0, 0, 0], q = [0, 0, 0, 1], s = [1, 1, 1]) {    // sütun öncelikli 4x4
    const [x, y, z, w] = q;
    const m = [1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0, 2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0, 2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0, t[0], t[1], t[2], 1];
    for (let i = 0; i < 3; i++) { m[i] *= s[0]; m[4 + i] *= s[1]; m[8 + i] *= s[2]; }
    return m;
  },
  mul(a, b) { const o = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k]; return o; },
};
const skin = J.skins[0], joints = skin.joints, IBM = acc(skin.inverseBindMatrices);
const anim = J.animations.find((a) => /run/i.test(a.name)) || J.animations[0];
const tracks = anim.channels.map((c) => { const s = anim.samplers[c.sampler]; return { node: c.target.node, path: c.target.path, t: acc(s.input), v: acc(s.output) }; });
const dur = Math.max(...tracks.map((k) => k.t[k.t.length - 1]));
const parent = []; J.nodes.forEach((n, i) => (n.children || []).forEach((c) => (parent[c] = i)));
function sample(k, t) {
  const T = k.t, n = k.path === "rotation" ? 4 : 3;
  let i = 0; while (i < T.length - 2 && T[i + 1] < t) i++;
  const a = Math.max(0, Math.min(1, (t - T[i]) / ((T[i + 1] - T[i]) || 1)));
  const A = Array.from(k.v.slice(i * n, i * n + n)), B = Array.from(k.v.slice((i + 1) * n, (i + 1) * n + n));
  if (n === 4) { const d = A.reduce((s, x, q) => s + x * B[q], 0); if (d < 0) for (let q = 0; q < 4; q++) B[q] = -B[q];
    const o = A.map((x, q) => x + (B[q] - x) * a), l = Math.hypot(...o); return o.map((x) => x / l); }
  return A.map((x, q) => x + (B[q] - x) * a);
}
function worldAt(t) {
  const local = J.nodes.map((n, i) => {
    const tr = { translation: n.translation, rotation: n.rotation, scale: n.scale };
    for (const k of tracks) if (k.node === i) tr[k.path] = sample(k, t);
    return mat.trs(tr.translation, tr.rotation, tr.scale);
  });
  const W = [];
  const get = (i) => W[i] || (W[i] = parent[i] === undefined ? local[i] : mat.mul(get(parent[i]), local[i]));
  return J.nodes.map((_, i) => get(i));
}
// Kök kemiğin ileri kayması varsa (koşu yerinde değilse) çıkar: oyun yer değiştirmeyi kendisi yapar
const rootJ = joints[0], r0 = worldAt(0)[rootJ], r1 = worldAt(dur)[rootJ];
const drift = [r1[12] - r0[12], 0, r1[14] - r0[14]];
console.log("animasyon:", anim.name, dur + " sn,", tracks.length, "kanal, kök kayması", drift.map((x) => x.toFixed(3)).join(","));

function skinMats(t) {     // her eklem için (oyun uzayına çevirmeden önce) jointWorld * invBind
  const W = worldAt(t), f = t / dur;
  return joints.map((ji, k) => {
    const m = mat.mul(W[ji], Array.from(IBM.slice(k * 16, k * 16 + 16)));
    m[12] -= drift[0] * f; m[14] -= drift[2] * f;
    return m;
  });
}
const xf = (m, x, y, z) => [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13], m[2] * x + m[6] * y + m[10] * z + m[14]];

// ---- Ağırlıklar: en fazla 4 eklem, küçükleri at, yeniden normalle ----
const jj = [], ww = [];
for (const v of keep) {
  let L = []; for (let c = 0; c < 4; c++) if (WGT[v * 4 + c] > 0.02) L.push([JNT[v * 4 + c], WGT[v * 4 + c]]);
  if (!L.length) L = [[JNT[v * 4], 1]];
  const s = L.reduce((a, x) => a + x[1], 0);
  for (let c = 0; c < 4; c++) { jj.push(L[c] ? L[c][0] : 0); ww.push(L[c] ? Math.round((L[c][1] / s) * 1000) / 1000 : 0); }
}
function skinAt(M) {
  const out = new Float32Array(keep.length * 3);
  keep.forEach((v, i) => {
    const x = POS[v * 3], y = POS[v * 3 + 1], z = POS[v * 3 + 2];
    for (let c = 0; c < 4; c++) { const w = ww[i * 4 + c]; if (!w) continue; const p = xf(M[jj[i * 4 + c]], x, y, z); out[i * 3] += p[0] * w; out[i * 3 + 1] += p[1] * w; out[i * 3 + 2] += p[2] * w; }
  });
  return out;
}

// ---- Oyun uzayı: ayaklar 0'da, boy 1 birim, xz merkezde (oyunda RULES ölçeğiyle büyür) ----
let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
for (let f = 0; f < FRAMES; f++) {
  const P = skinAt(skinMats((f / FRAMES) * dur));
  for (let i = 0; i < P.length; i += 3) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], P[i + a]); mx[a] = Math.max(mx[a], P[i + a]); }
}
const k = 1 / (mx[1] - mn[1]), cx = (mn[0] + mx[0]) / 2, cz = (mn[2] + mx[2]) / 2;
const N = [k, 0, 0, 0, 0, k, 0, 0, 0, 0, k, 0, -cx * k, -mn[1] * k, -cz * k, 1];
const r5 = (v) => Math.round(v * 1e5) / 1e5, r4 = (v) => Math.round(v * 1e4) / 1e4;
const Ninv = [1 / k, 0, 0, 0, 0, 1 / k, 0, 0, 0, 0, 1 / k, 0, cx, mn[1], cz, 1];   // köşeler oyun uzayında saklanır: M = N * eklem * N^-1
const frames = [];
for (let f = 0; f < FRAMES; f++) {
  const M = skinMats((f / FRAMES) * dur).map((m) => mat.mul(N, mat.mul(m, Ninv)));
  frames.push(M.flatMap((m) => [m[0], m[4], m[8], m[12], m[1], m[5], m[9], m[13], m[2], m[6], m[10], m[14]].map(r5)));   // satır öncelikli 3x4
}
const pos = [], uv = [];
for (const v of keep) { pos.push(...xf(N, POS[v * 3], POS[v * 3 + 1], POS[v * 3 + 2]).map(r4)); uv.push(r4(UV[v * 2]), r4(1 - UV[v * 2 + 1])); }   // çizici v'yi ters okur
const bb = { min: [(mn[0] - cx) * k, 0, (mn[2] - cz) * k].map(r4), max: [(mx[0] - cx) * k, (mx[1] - mn[1]) * k, (mx[2] - cz) * k].map(r4) };

// ---- Doku: taban rengi -> 512x512 jpg ----
const img = J.images[J.textures[J.materials[prim.material].pbrMetallicRoughness.baseColorTexture.index].source];
const bv = J.bufferViews[img.bufferView];
fs.mkdirSync(texDir, { recursive: true });
const rawTex = path.join(texDir, "_runner_src.jpg");
fs.writeFileSync(rawTex, BIN.slice(bv.byteOffset || 0, (bv.byteOffset || 0) + bv.byteLength));
execFileSync("convert", [rawTex, "-resize", `${TEX}x${TEX}!`, "-quality", "88", path.join(texDir, "Runner_base.jpg")]);
fs.unlinkSync(rawTex);

const json = JSON.parse(fs.readFileSync(outPath, "utf8"));
json.chars.runner = {
  mats: [{ n: "Runner", c: [255, 255, 255], d: 0, e: 0 }], tex: "models/tex/Runner_base.jpg",
  parts: [{ name: "body", pivot: [0, 0, 0], mat: 0, pos, uv, idx, j: jj, w: ww }],
  skin: { nj: joints.length, dur: r4(dur), frames }, bb,
};
fs.writeFileSync(outPath, JSON.stringify(json));
console.log(`koşucu pişirildi: ${idx.length / 3} üçgen, ${keep.length} köşe, ${FRAMES} kare, bb ${JSON.stringify(bb)}`);
