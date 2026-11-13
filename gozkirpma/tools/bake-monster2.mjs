// Sıska Canavar 2: eski pişmiş modeli (tools/data/monster-base.json) alır, baştan aşağı güzelleştirir.
//   npm i meshoptimizer@0.22.0   (yalnızca bu araç için, oyuna girmez)
//   node tools/bake-monster2.mjs [models.json]
// 1) Yüzey: deri, kollar ve boynuzlar kelebek (butterfly) alt bölmesiyle yuvarlatılır (köşeli tüp görüntüsü gider), sonra seyreltilir
// 2) Renk: üçgen başına boyama: benekli deri, damarlar, çamurlu ayaklar, kanlı eller ve ağız, sararmış kemik, halkalı boynuz
// 3) İskelet: 27 kemik (omurga, boyun, baş, çene, dil, saç, kollar, bacaklar, kuyruk)
// 4) Animasyon: sinsi yürüyüş döngüsü: bacak adımları, öne uzanan pençeler, yana yatan baş, şaklayan çene, sallanan dil/saç/kuyruk
// Çıktı biçimi bake-runner.mjs / bake-demon.mjs ile aynıdır.
import fs from "node:fs";
import { MeshoptSimplifier } from "meshoptimizer";

const here = new URL(".", import.meta.url).pathname;
const outPath = process.argv[2] || here + "../src/main/assets/models/models.json";
const base = JSON.parse(fs.readFileSync(here + "data/monster-base.json", "utf8"));
const FRAMES = 32;
await MeshoptSimplifier.ready;
MeshoptSimplifier.useExperimentalFeatures = true;

// ---------- yardımcılar ----------
function weld(pos, idx) {
  const m = new Map(), P = [], I = [];
  for (const v of idx) { const k = Math.round(pos[v * 3] * 2e4) + "," + Math.round(pos[v * 3 + 1] * 2e4) + "," + Math.round(pos[v * 3 + 2] * 2e4); let u = m.get(k); if (u === undefined) { u = P.length / 3; m.set(k, u); P.push(pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]); } I.push(u); }
  const O = []; for (let t = 0; t < I.length; t += 3) if (I[t] !== I[t + 1] && I[t + 1] !== I[t + 2] && I[t] !== I[t + 2]) O.push(I[t], I[t + 1], I[t + 2]);
  return { P, I: O };
}
// Değiştirilmiş kelebek alt bölmesi: eski köşeler yerinde kalır (şekil incelmez), yeni kenar noktaları yüzeyi yuvarlatır
function butterfly({ P, I }) {
  const ek = (a, b) => (a < b ? a + "_" + b : b + "_" + a);
  const edges = new Map();
  for (let t = 0; t < I.length; t += 3) for (let e = 0; e < 3; e++) { const a = I[t + e], b = I[t + (e + 1) % 3], c = I[t + (e + 2) % 3], k = ek(a, b); let E = edges.get(k); if (!E) edges.set(k, (E = { a, b, opp: [] })); E.opp.push(c); }
  const opp = (a, b, not) => { const E = edges.get(ek(a, b)); if (!E || E.opp.length !== 2) return -1; return E.opp[0] === not ? E.opp[1] : E.opp[0]; };
  const NP = P.slice(), mid = new Map();
  for (const [k, E] of edges) {
    const { a, b } = E, o = [0, 0, 0];
    let ok = E.opp.length === 2, w = [];
    if (ok) { const [c, d] = E.opp; w = [opp(a, c, b), opp(c, b, a), opp(a, d, b), opp(d, b, a)]; ok = w.every((x) => x >= 0); }
    for (let q = 0; q < 3; q++) {
      let v = (P[a * 3 + q] + P[b * 3 + q]) / 2;
      if (ok) { const [c, d] = E.opp; v += (P[c * 3 + q] + P[d * 3 + q]) / 8 - (P[w[0] * 3 + q] + P[w[1] * 3 + q] + P[w[2] * 3 + q] + P[w[3] * 3 + q]) / 16; }
      o[q] = v;
    }
    // aşırı taşmayı sınırla (düzensiz köşelerde kelebek sivrilebilir)
    const L = Math.hypot(P[a * 3] - P[b * 3], P[a * 3 + 1] - P[b * 3 + 1], P[a * 3 + 2] - P[b * 3 + 2]), mx = [(P[a * 3] + P[b * 3]) / 2, (P[a * 3 + 1] + P[b * 3 + 1]) / 2, (P[a * 3 + 2] + P[b * 3 + 2]) / 2];
    const dd = Math.hypot(o[0] - mx[0], o[1] - mx[1], o[2] - mx[2]), lim = L * 0.22;
    if (dd > lim) for (let q = 0; q < 3; q++) o[q] = mx[q] + (o[q] - mx[q]) * (lim / dd);
    mid.set(k, NP.length / 3); NP.push(...o);
  }
  const NI = [];
  for (let t = 0; t < I.length; t += 3) { const a = I[t], b = I[t + 1], c = I[t + 2], ab = mid.get(ek(a, b)), bc = mid.get(ek(b, c)), ca = mid.get(ek(c, a)); NI.push(a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca); }
  return { P: NP, I: NI };
}
function decimate({ P, I }, tris) {
  if (I.length / 3 <= tris) return { P, I };
  const [s] = MeshoptSimplifier.simplify(new Uint32Array(I), new Float32Array(P), 3, tris * 3, 0.02, []);
  const rm = new Map(), NP = [], NI = [];
  for (const v of s) { let u = rm.get(v); if (u === undefined) { u = NP.length / 3; rm.set(v, u); NP.push(P[v * 3], P[v * 3 + 1], P[v * 3 + 2]); } NI.push(u); }
  return { P: NP, I: NI };
}
const hash3 = (x, y, z) => { const s = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return s - Math.floor(s); };
function noise3(x, y, z) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z), f = [x - xi, y - yi, z - zi].map((t) => t * t * (3 - 2 * t));
  let o = 0;
  for (let a = 0; a < 2; a++) for (let b = 0; b < 2; b++) for (let c = 0; c < 2; c++) o += hash3(xi + a, yi + b, zi + c) * (a ? f[0] : 1 - f[0]) * (b ? f[1] : 1 - f[1]) * (c ? f[2] : 1 - f[2]);
  return o;
}
const fbm = (x, y, z) => noise3(x, y, z) * 0.6 + noise3(x * 2.3 + 5, y * 2.3 + 9, z * 2.3 + 2) * 0.4;
const sstep = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const mix = (A, B, t) => [A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t];

// ---------- 1) Yüzey ----------
const TARGET = { monster_Skin: 6400, monster_SkinArmLeft: 2300, monster_SkinArmRight: 2300, monster_Horn: 900 };
const kindOf = (n) => n.replace("monster_", "").replace(/Arm(Left|Right)/, "");
const meshes = [];
for (const p of base.parts) {
  let m = weld(p.pos, p.idx);
  if (TARGET[p.name]) m = decimate(butterfly(m), TARGET[p.name]);
  meshes.push({ name: p.name, kind: kindOf(p.name), side: /ArmLeft/.test(p.name) ? 1 : /ArmRight/.test(p.name) ? -1 : 0, ...m });
}

// ---------- 3) İskelet: [ad, ebeveyn, baş, uç] (model uzayı: y yukarı, +z ileri, boy 2.18; +x = "sol") ----------
const BONES = [
  ["pelvis", -1, [0, 0.97, -0.13], [0, 1.05, -0.13]],
  ["spine", 0, [0, 1.05, -0.13], [0, 1.25, -0.05]],
  ["chest", 1, [0, 1.25, -0.05], [0, 1.55, 0.18]],
  ["neck1", 2, [0, 1.55, 0.2], [0, 1.7, 0.36]],
  ["neck2", 3, [0, 1.7, 0.36], [0, 1.75, 0.56]],
  ["head", 4, [0, 1.75, 0.56], [0, 1.62, 0.92]],
  ["jaw", 5, [0, 1.6, 0.6], [0, 1.4, 0.82]],
  ["tongue1", 6, [0, 1.45, 0.72], [0, 1.25, 0.7]],
  ["tongue2", 7, [0, 1.25, 0.7], [0, 1.08, 0.66]],
  ["hair1", 5, [0, 1.72, 0.5], [0, 1.38, 0.5]],
  ["hair2", 9, [0, 1.38, 0.5], [0, 0.97, 0.5]],
  ["armL", 2, [0.16, 1.52, 0.18], [0.25, 1.0, 0.08]],
  ["foreL", 11, [0.25, 1.0, 0.08], [0.22, 0.4, 0.39]],
  ["handL", 12, [0.22, 0.4, 0.39], [0.23, 0.03, 0.57]],
  ["armR", 2, [-0.16, 1.52, 0.18], [-0.25, 1.0, 0.08]],
  ["foreR", 14, [-0.25, 1.0, 0.08], [-0.22, 0.4, 0.39]],
  ["handR", 15, [-0.22, 0.4, 0.39], [-0.23, 0.03, 0.57]],
  ["thighL", 0, [0.11, 0.92, -0.07], [0.16, 0.6, 0.07]],
  ["shinL", 17, [0.16, 0.6, 0.07], [0.13, 0.25, -0.14]],
  ["footL", 18, [0.13, 0.25, -0.14], [0.15, 0.02, 0.2]],
  ["thighR", 0, [-0.11, 0.92, -0.07], [-0.16, 0.6, 0.07]],
  ["shinR", 20, [-0.16, 0.6, 0.07], [-0.13, 0.25, -0.14]],
  ["footR", 21, [-0.13, 0.25, -0.14], [-0.15, 0.02, 0.2]],
  ["tail1", 0, [0, 0.9, -0.2], [0, 0.6, -0.5]],
  ["tail2", 23, [0, 0.6, -0.5], [0, 0.33, -0.76]],
  ["tail3", 24, [0, 0.33, -0.76], [0, 0.14, -1.02]],
  ["tail4", 25, [0, 0.14, -1.02], [0, 0.05, -1.27]],
];
const B = Object.fromEntries(BONES.map((b, i) => [b[0], i]));
function segDist(p, a, b) {
  const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], ap = [p[0] - a[0], p[1] - a[1], p[2] - a[2]];
  const t = Math.max(0, Math.min(1, (ap[0] * ab[0] + ap[1] * ab[1] + ap[2] * ab[2]) / (ab[0] ** 2 + ab[1] ** 2 + ab[2] ** 2)));
  return Math.hypot(ap[0] - ab[0] * t, ap[1] - ab[1] * t, ap[2] - ab[2] * t);
}
const byDist = (p, names, pow = 2) => { let L = names.map((n) => [B[n], 1 / (segDist(p, BONES[B[n]][2], BONES[B[n]][3]) ** 2 + 4e-4) ** pow]).sort((x, y) => y[1] - x[1]).slice(0, 2); return L; };
const isJaw = (p) => p[2] > 0.6 && p[1] < 1.555 - (p[2] - 0.6) * 0.37;        // ağız çizgisinin altı = alt çene
const blendY = (y, stops) => {          // [[y, kemik], ...] yukarıdan aşağı; arada yumuşak geçiş
  for (let i = 0; i < stops.length - 1; i++) if (y <= stops[i][0] && y >= stops[i + 1][0]) { const t = (stops[i][0] - y) / (stops[i][0] - stops[i + 1][0]); return [[B[stops[i][1]], 1 - t], [B[stops[i + 1][1]], t]]; }
  return [[B[y > stops[0][0] ? stops[0][1] : stops[stops.length - 1][1]], 1]];
};
function weightsOf(m, p) {
  if (m.side) { const s = m.side > 0 ? "L" : "R"; return byDist(p, ["arm" + s, "fore" + s, "hand" + s], 3); }
  switch (m.kind) {
    case "Horn": case "Eye": return [[B.head, 1]];
    case "Tooth": case "Dark": return [[isJaw(p) ? B.jaw : B.head, 1]];
    case "Tongue": return blendY(p[1], [[1.46, "jaw"], [1.36, "tongue1"], [1.2, "tongue2"], [1.08, "tongue2"]]);
    case "Hair": return blendY(p[1], [[1.68, "head"], [1.5, "hair1"], [1.25, "hair2"], [0.97, "hair2"]]);
    case "Bone": return byDist(p, ["pelvis", "spine", "chest", "neck1", "neck2", "head"], 2);
    default: {
      if (p[2] > 0.56 && p[1] > 1.3) return [[isJaw(p) ? B.jaw : B.head, 1]];
      const s = p[0] > 0 ? "L" : "R";
      return byDist(p, ["pelvis", "spine", "chest", "neck1", "neck2", "head", "thigh" + s, "shin" + s, "foot" + s, "tail1", "tail2", "tail3", "tail4"], 2);
    }
  }
}

// ---------- 2) Renk ----------
const EYES = [[-0.0518, 1.7043, 0.838], [0.0518, 1.7043, 0.838]];
function colorOf(m, c, n) {
  const [x, y, z] = c, N = fbm(x * 9, y * 9, z * 9), big = fbm(x * 2.6 + 3, y * 2.6, z * 2.6 + 7);
  switch (m.kind) {
    case "Skin": {
      let col = mix([138, 146, 134], [166, 170, 152], big);                              // soluk gri-yeşil, büyük lekeler
      col = col.map((v) => v * (0.84 + 0.26 * N));                                         // benek
      const vein = Math.abs(fbm(x * 5.5 + 11, y * 5.5 + 4, z * 5.5) - 0.5);                // damar: gürültünün sıfır çizgisi
      if (vein < 0.022) col = mix(col, [70, 82, 104], 0.6 * (1 - vein / 0.022));
      col = col.map((v) => v * (0.8 + 0.2 * Math.max(0, n[1] * 0.5 + 0.5)));               // alta bakan yüzler koyu (sahte gölge)
      if (m.side) {                                                                         // eller: kana bulanmış pençeler
        const k = sstep(0.62, 0.12, y) * (0.55 + 0.6 * N); col = mix(col, [104, 14, 16], Math.min(0.92, k));
        if (y < 0.1) col = mix(col, [28, 8, 8], 0.6);
      } else {
        const mud = sstep(0.42, 0.04, y) * (0.5 + 0.6 * N) * (z > -0.5 ? 1 : 0.6); col = mix(col, [52, 44, 36], Math.min(0.9, mud));     // çamurlu ayaklar, kuyruk ucu
        if (z > 0.58 && y > 1.3) {                                                         // baş: ağız çevresi kanlı, göz çukurları kararmış
          const mouth = 1 - sstep(0.0, 0.11, Math.abs(y - (1.555 - (z - 0.6) * 0.37)));
          col = mix(col, [112, 12, 16], Math.min(0.9, mouth * (0.5 + 0.7 * N)));
          const de = Math.min(...EYES.map((e) => Math.hypot(x - e[0], y - e[1], (z - e[2]) * 0.6)));
          col = mix(col, [8, 6, 8], 1 - sstep(0.03, 0.075, de));
        }
        const spine = z < 0.5 && y > 0.95 && Math.abs(x) < 0.03 && n[2] < -0.2 ? 0.35 : 0; col = mix(col, [84, 92, 96], spine);   // sırt çizgisi
      }
      return col;
    }
    case "Bone": { let col = mix([232, 222, 192], [176, 150, 108], sstep(0.45, 0.8, N)); col = mix(col, [120, 24, 22], sstep(0.62, 0.9, big) * 0.7); return col.map((v) => v * (0.78 + 0.22 * Math.max(0, n[1] * 0.5 + 0.5))); }
    case "Horn": { const t = sstep(1.82, 2.18, y); let col = mix([104, 88, 70], [238, 230, 206], t); return col.map((v) => v * (0.9 + 0.1 * Math.sin(y * 110)) * (0.9 + 0.2 * N)); }
    case "Hair": { const h = hash3(Math.round(x * 60), 0, Math.round(z * 60)); return mix([10, 10, 14], [44, 40, 50], h * h * 0.8 + 0.1 * N); }
    case "Dark": return mix([10, 4, 5], [84, 12, 16], sstep(0.3, 0.9, N));
    case "Tooth": { let col = mix([244, 236, 208], [196, 170, 110], sstep(0.4, 0.9, N)); return mix(col, [150, 24, 24], hash3(Math.round(x * 90), Math.round(y * 30), Math.round(z * 90)) > 0.72 ? 0.65 : 0); }
    case "Tongue": return mix([168, 50, 66], [96, 18, 34], sstep(1.45, 1.08, y) * 0.8 + 0.2 * N);
    default: return [255, 176, 64];
  }
}

// ---------- birleştir: tek "body" parçası + ışıldayan "eyes" ----------
const body = { pos: [], idx: [], col: [], j: [], w: [] }, eyes = { pos: [], idx: [], j: [], w: [] };
for (const m of meshes) {
  const dst = m.kind === "Eye" ? eyes : body, off = dst.pos.length / 3;
  for (let v = 0; v < m.P.length; v += 3) {
    const p = [m.P[v], m.P[v + 1], m.P[v + 2]];
    let L = weightsOf(m, p); const s = L.reduce((a, q) => a + q[1], 0); L = L.map(([b, w]) => [b, w / s]).filter((q) => q[1] > 0.03);
    const s2 = L.reduce((a, q) => a + q[1], 0);
    dst.pos.push(...p);
    for (let c = 0; c < 4; c++) { dst.j.push(L[c] ? L[c][0] : 0); dst.w.push(L[c] ? Math.round((L[c][1] / s2) * 1000) / 1000 : 0); }
  }
  for (let t = 0; t < m.I.length; t += 3) {
    const a = m.I[t] * 3, b = m.I[t + 1] * 3, c = m.I[t + 2] * 3, P = m.P;
    dst.idx.push(m.I[t] + off, m.I[t + 1] + off, m.I[t + 2] + off);
    if (dst === body) {
      const cen = [(P[a] + P[b] + P[c]) / 3, (P[a + 1] + P[b + 1] + P[c + 1]) / 3, (P[a + 2] + P[b + 2] + P[c + 2]) / 3];
      const e1 = [P[b] - P[a], P[b + 1] - P[a + 1], P[b + 2] - P[a + 2]], e2 = [P[c] - P[a], P[c + 1] - P[a + 1], P[c + 2] - P[a + 2]];
      let n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]; const nl = Math.hypot(...n) || 1; n = n.map((q) => q / nl);
      body.col.push(...colorOf(m, cen, n).map((q) => Math.max(0, Math.min(255, Math.round(q)))));
    }
  }
}

// ---------- 4) Animasyon ----------
const mul = (a, b) => { const o = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k]; return o; };
const T = (x, y, z) => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];
const RX = (a) => { const c = Math.cos(a), s = Math.sin(a); return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1]; };   // +a: aşağı sarkan uzuv geriye (-z); öndeki uç aşağı
const RY = (a) => { const c = Math.cos(a), s = Math.sin(a); return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1]; };
const RZ = (a) => { const c = Math.cos(a), s = Math.sin(a); return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]; };
const R3 = (x = 0, y = 0, z = 0) => mul(RZ(z), mul(RY(y), RX(x)));
const about = (p, R) => mul(T(p[0], p[1], p[2]), mul(R, T(-p[0], -p[1], -p[2])));
const xf = (m, x, y, z) => [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13], m[2] * x + m[6] * y + m[10] * z + m[14]];
function pose(ph) {
  const w = ph * 2 * Math.PI, s = Math.sin(w), c = Math.cos(w), sn = (k, o = 0) => Math.sin(w * k + o);
  const up = (x) => Math.pow(Math.max(0, x), 1.4);
  const snap = Math.pow(Math.max(0, sn(2, 0.9)), 8);                     // çene: döngüde iki kez aniden kapanır
  const kL = up(c), kR = up(-c);                                         // bacak öne savrulurken diz/bilek bükülür
  const L = {
    pelvis: mul(T(0.02 * s, 0.025 * sn(2, 1.2), 0), R3(-0.04, 0.1 * s, 0.05 * s)),
    spine: R3(0.05 * sn(2), -0.07 * s, -0.04 * s), chest: R3(0.04 * sn(2, 0.5), -0.1 * s, -0.05 * s),
    neck1: R3(0.07 * sn(2, 1.0), 0.05 * s, 0.07 * sn(1, 0.5)), neck2: R3(0.06 * sn(2, 1.5), 0.04 * s, 0.1 * sn(1, 0.9)),
    head: R3(0.06 * sn(2, 2.0), 0.08 * s, 0.2 * sn(1, 1.3)),             // baş bir yana yatar, döner
    jaw: R3(-(0.34 * snap) + 0.1 * (1 - snap) * (0.5 + 0.5 * sn(2, 2.4))),
    tongue1: R3(0.3 * sn(2, 0.2), 0, 0.12 * sn(1, 0.4)), tongue2: R3(0.4 * sn(2, -0.6), 0, 0.2 * sn(1, -0.3)),
    hair1: R3(0.1 * sn(2, 0.8), 0, -0.12 * sn(1, 0.9)), hair2: R3(0.16 * sn(2, 0.1), 0, -0.14 * sn(1, 0.3)),
    thighL: R3(-0.5 * s - 0.05), shinL: R3(0.75 * kL), footL: R3(-0.55 * kL - 0.15 * Math.max(0, -s)),
    thighR: R3(0.5 * s - 0.05), shinR: R3(0.75 * kR), footR: R3(-0.55 * kR - 0.15 * Math.max(0, s)),
    // kollar: karşı bacakla birlikte öne uzanır, pençe havada kavrar
    armL: R3(-(0.34 - 0.42 * s), 0, -0.06), foreL: R3(-(0.3 - 0.3 * s)), handL: R3(-(0.25 + 0.3 * up(-s))),
    armR: R3(-(0.34 + 0.42 * s), 0, 0.06), foreR: R3(-(0.3 + 0.3 * s)), handR: R3(-(0.25 + 0.3 * up(s))),
    tail1: R3(-0.12 + 0.05 * sn(2), 0.22 * sn(1, 0.0)), tail2: R3(-0.1, 0.3 * sn(1, -0.8)), tail3: R3(-0.08, 0.36 * sn(1, -1.6)), tail4: R3(0, 0.4 * sn(1, -2.4)),
  };
  const W = [];
  BONES.forEach(([name, par, head], i) => { const loc = about(head, L[name]); W[i] = par < 0 ? loc : mul(W[par], loc); });
  return W;
}
// her karede basan ayak yere değsin: yalnızca ayak kemiklerine bağlı köşelerin en alçağı
const footV = []; for (let v = 0; v < body.pos.length / 3; v++) { const j = body.j[v * 4]; if ((j === B.footL || j === B.footR) && body.w[v * 4] > 0.6) footV.push(v); }
const r5 = (v) => Math.round(v * 1e5) / 1e5, r4 = (v) => Math.round(v * 1e4) / 1e4;
const frames = [];
for (let f = 0; f < FRAMES; f++) {
  const W = pose(f / FRAMES); let lo = 1e9;
  for (const v of footV) lo = Math.min(lo, xf(W[body.j[v * 4]], body.pos[v * 3], body.pos[v * 3 + 1], body.pos[v * 3 + 2])[1]);
  frames.push(W.flatMap((m0) => { const m = mul(T(0, -lo, 0), m0); return [m[0], m[4], m[8], m[12], m[1], m[5], m[9], m[13], m[2], m[6], m[10], m[14]].map(r5); }));
}

const json = JSON.parse(fs.readFileSync(outPath, "utf8"));
json.chars.monster = {
  mats: [{ n: "Monster", c: [255, 255, 255], d: 1, e: 0 }, { n: "Eye_flame", c: [255, 190, 60], d: 1, e: 1 }],
  parts: [{ name: "body", pivot: [0, 0, 0], mat: 0, pos: body.pos.map(r4), idx: body.idx, col: body.col, j: body.j, w: body.w },
    { name: "eyes", pivot: [0, 0, 0], mat: 1, pos: eyes.pos.map(r4), idx: eyes.idx, j: eyes.j, w: eyes.w }],
  skin: { nj: BONES.length, dur: 1.2, frames }, eyes: EYES.map((e) => [e[0], e[1], e[2] + 0.03]), eyeC: [255, 215, 70], eyeS: 0.05, bb: base.bb,
};
fs.writeFileSync(outPath, JSON.stringify(json));
console.log(`sıska canavar 2: ${body.idx.length / 3} + ${eyes.idx.length / 3} üçgen, ${body.pos.length / 3} köşe, ${BONES.length} kemik, ${FRAMES} kare; parçalar:`, meshes.map((m) => m.kind + (m.side || "") + ":" + m.I.length / 3).join(" "));
