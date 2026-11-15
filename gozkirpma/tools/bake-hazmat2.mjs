// Yeni Hazmat oyuncu karakteri: dosyadan değil, koddan üretilir (mesafe alanı + yüzey ağı) ve models.json içine
// chars.hazmat olarak yazılır. Parça adları, pivotlar ve "swing" değerleri eski Hazmat ile aynıdır; bu yüzden
// yürüme (kol/bacak sallama), yere düşme, lobi önizlemesi ve birinci şahıs eller hiçbir kod değişmeden çalışır.
// Doku yoktur: her üçgenin düz rengi vardır (col). Yazılım çizici için az üçgenlidir (~6 bin).
//   node tools/bake-hazmat2.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsonPath = path.join(here, "../src/main/assets/models/models.json");
const HEIGHT = 2.4232;                       // eski Hazmat ile aynı boy (model birimi); rules.player.scale değişmez
const r4 = (v) => Math.round(v * 10000) / 10000;

// ---- mesafe alanı yardımcıları (ölçüler metre, ayak tabanı y = 0, +z ileri, +x sol kol) ----
function cap(px, py, pz, ax, ay, az, bx, by, bz, ra, rb) {
  const dx = bx - ax, dy = by - ay, dz = bz - az; let qx = px - ax, qy = py - ay, qz = pz - az;
  let t = (qx * dx + qy * dy + qz * dz) / (dx * dx + dy * dy + dz * dz); t = t < 0 ? 0 : t > 1 ? 1 : t;
  qx -= dx * t; qy -= dy * t; qz -= dz * t;
  return Math.sqrt(qx * qx + qy * qy + qz * qz) - (ra + (rb - ra) * t);
}
const smin = (a, b, k) => { let h = 0.5 + (0.5 * (b - a)) / k; h = h < 0 ? 0 : h > 1 ? 1 : h; return b + (a - b) * h - k * h * (1 - h); };
const ss = (a, b, x) => { let t = (x - a) / (b - a); t = t < 0 ? 0 : t > 1 ? 1 : t; return t * t * (3 - 2 * t); };
const bump = (c, w, x) => Math.exp(-(((x - c) / w) ** 2));
const ell = (x, y, z, cx, cy, cz, rx, ry, rz) => (Math.hypot((x - cx) / rx, (y - cy) / ry, (z - cz) / rz) - 1) * Math.min(rx, ry, rz);
// Eksen yönlü yuvarlak silindir: merkez c, birim eksen a, yarıçap R, yarı boy L
const cyl = (x, y, z, c, a, R, L) => { const qx = x - c[0], qy = y - c[1], qz = z - c[2], h = qx * a[0] + qy * a[1] + qz * a[2]; const r = Math.hypot(qx - a[0] * h, qy - a[1] * h, qz - a[2] * h); return Math.max(r - R, Math.abs(h) - L) - 0.004; };
// Kumaş kırışıkları (bol tulum): eklem yerlerinde daha belirgin
function folds(x, y, z, limb) {
  let q1 = 1 - Math.abs(Math.sin(y * 22 + 3.5 * Math.sin(x * 6.3 + z * 5.1 + 1) + 2 * Math.sin(z * 11 + y * 3))); q1 = q1 * q1 * q1;
  let amp = 0.3 + 1.4 * bump(0.53, 0.1, y) + 1.0 * bump(0.98, 0.07, y) + (limb === "arm" ? 1.3 * bump(1.17, 0.08, y) : 0) + 0.6 * bump(1.5, 0.04, y);
  if (y > 1.56 || y < 0.3) amp *= 0.3;
  return 0.006 * amp * q1 + 0.002 * Math.sin(y * 17 + x * 9 + 0.5) * Math.sin(z * 13 + y * 6 + x * 4);
}
const YEL = [224, 172, 14], YEL2 = [196, 148, 10], BLK = [46, 46, 52], TAPE = [176, 172, 158], MASK = [34, 35, 38], LENS = [58, 92, 104], FIL = [84, 87, 94], FIL2 = [52, 54, 60];

// Gövde + başlık
function body(x, y, z) {
  const ax = Math.abs(x), k = 0.05;
  let d = cap(ax, y, z, 0, 0.95, 0, 0.055, 0.95, 0, 0.165, 0.165);
  d = smin(d, cap(ax, y, z, 0, 1.0, 0, 0, 1.36, -0.005, 0.2, 0.2), k);
  d = smin(d, cap(ax, y, z, 0, 1.36, 0.01, 0.1, 1.37, 0, 0.15, 0.15), k);
  d = smin(d, cap(ax, y, z, 0, 1.47, -0.01, 0.2, 1.462, -0.01, 0.1, 0.095), k);
  d = smin(d, cap(ax, y, z, 0, 1.46, 0, 0, 1.6, 0.005, 0.125, 0.12), 0.04);
  d = smin(d, cap(ax, y, z, 0, 1.635, 0, 0, 1.705, -0.005, 0.138, 0.14), 0.035);
  d += folds(x, y, z, "body");
  if (z > 0 && y > 0.86 && y < 1.5) d -= 0.006 * ss(0.014, 0.004, Math.abs(x - 0.018) - 0.024) * ss(0.86, 0.9, y) * ss(1.5, 1.46, y);
  return d;
}
const bodyCol = (x, y, z) => (z > 0 && y > 0.88 && y < 1.48 && Math.abs(x - 0.018) < 0.03 ? YEL2 : YEL);
// Tam yüz gaz maskesi: yüzlük, cam, ağızlık, ön valf, iki filtre, başlık contası
const FA = [[0.6, -0.25, 0.76], [-0.6, -0.25, 0.76]].map((a) => { const l = Math.hypot(...a); return a.map((v) => v / l); });
const FC = FA.map((a, i) => [(i ? -1 : 1) * 0.078 + a[0] * 0.04, 1.568 + a[1] * 0.04, 0.15 + a[2] * 0.04]);
const maskParts = (x, y, z) => {
  const face = ell(x, y, z, 0, 1.65, 0.082, 0.108, 0.132, 0.088);
  const cup = ell(x, y, z, 0, 1.582, 0.148, 0.056, 0.05, 0.055);
  const valve = cyl(x, y, z, [0, 1.575, 0.2], [0, 0, 1], 0.026, 0.018);
  const fil = Math.min(cyl(x, y, z, FC[0], FA[0], 0.044, 0.02), cyl(x, y, z, FC[1], FA[1], 0.044, 0.02));
  const q = Math.hypot(x, (y - 1.652) / 1.18) - 0.113, seal = Math.hypot(q, (z - 0.092) / 1.2) - 0.015;
  return [face, cup, valve, fil, seal];
};
const mask = (x, y, z) => { const m = maskParts(x, y, z); return Math.min(smin(m[0], m[1], 0.015), m[2], m[3], m[4]); };
function maskCol(x, y, z) {
  const m = maskParts(x, y, z); let i = 0; for (let k = 1; k < 5; k++) if (m[k] < m[i]) i = k;
  if (i === 4) return YEL2;
  if (i === 3) { const a = x > 0 ? 0 : 1, h = (x - FC[a][0]) * FA[a][0] + (y - FC[a][1]) * FA[a][1] + (z - FC[a][2]) * FA[a][2]; return h > 0.016 ? FIL2 : FIL; }
  if (i === 2) return FIL;
  if (i === 0 && y > 1.628 && y < 1.74 && z > 0.118 && Math.abs(x) < 0.09) return LENS;
  return MASK;
}
// Sol kol (+x): aşağı sarkar; eldiven yumruk gibi kapalıdır (silah/fener tutar)
function arm(x, y, z) {
  let d = cap(x, y, z, 0.235, 1.455, -0.01, 0.265, 1.17, -0.02, 0.082, 0.072);
  d = smin(d, cap(x, y, z, 0.265, 1.17, -0.02, 0.275, 0.94, 0.02, 0.07, 0.06), 0.035) + folds(x, y, z, "arm");
  let g = cap(x, y, z, 0.275, 0.985, 0.012, 0.278, 0.875, 0.03, 0.078, 0.066);
  g = smin(g, cap(x, y, z, 0.278, 0.865, 0.034, 0.275, 0.805, 0.05, 0.046, 0.044), 0.03);
  g = smin(g, cap(x, y, z, 0.258, 0.845, 0.068, 0.258, 0.8, 0.086, 0.018, 0.016), 0.018);
  return Math.min(d, g);
}
const armCol = (x, y, z) => (y > 0.99 ? YEL : y > 0.945 ? TAPE : BLK);
// Sol bacak (+x) + lastik çizme
function boot(x, y, z) {
  let d = cap(x, y, z, 0.14, 0.27, -0.012, 0.14, 0.07, -0.012, 0.093, 0.082);
  d = smin(d, cap(x, y, z, 0.14, 0.05, -0.03, 0.148, 0.042, 0.15, 0.058, 0.05), 0.04);
  d = smin(d, cap(x, y, z, 0.14, 0.02, -0.05, 0.15, 0.02, 0.16, 0.05, 0.05), 0.02);
  if (y < 0.03) d -= 0.008;
  return Math.max(d, -y + 0.001, y - 0.285);
}
function leg(x, y, z) {
  let d = cap(x, y, z, 0.1, 0.93, 0, 0.125, 0.53, 0.015, 0.115, 0.095);
  d = smin(d, cap(x, y, z, 0.125, 0.53, 0.015, 0.14, 0.2, -0.01, 0.09, 0.072), 0.04) + folds(x, y, z, "leg");
  return Math.min(d, boot(x, y, z));
}
const legCol = (x, y, z) => (y > 0.29 ? YEL : y > 0.235 ? TAPE : BLK);

// ---- yüzey ağı (surface nets): mesafe alanından dörtgen ağ ----
function nets(f, [x0, y0, z0], [x1, y1, z1], h) {
  const nx = Math.ceil((x1 - x0) / h) + 1, ny = Math.ceil((y1 - y0) / h) + 1, nz = Math.ceil((z1 - z0) / h) + 1, sy = nx, sz = nx * ny;
  const v = new Float32Array(nx * ny * nz);
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) v[k * sz + j * sy + i] = f(x0 + i * h, y0 + j * h, z0 + k * h);
  const id = new Int32Array(nx * ny * nz), pos = [], idx = [];
  const cx = [0, 1, 0, 1, 0, 1, 0, 1], cy = [0, 0, 1, 1, 0, 0, 1, 1], cz = [0, 0, 0, 0, 1, 1, 1, 1];
  const E = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]], cv = new Float32Array(8);
  for (let k = 0; k < nz - 1; k++) for (let j = 0; j < ny - 1; j++) for (let i = 0; i < nx - 1; i++) {
    const o = k * sz + j * sy + i; let m = 0;
    for (let q = 0; q < 8; q++) { cv[q] = v[o + cx[q] + cy[q] * sy + cz[q] * sz]; if (cv[q] < 0) m |= 1 << q; }
    if (m === 0 || m === 255) continue;
    let px = 0, py = 0, pz = 0, n = 0;
    for (const [a, b] of E) if (cv[a] < 0 !== cv[b] < 0) { const t = cv[a] / (cv[a] - cv[b]); px += cx[a] + (cx[b] - cx[a]) * t; py += cy[a] + (cy[b] - cy[a]) * t; pz += cz[a] + (cz[b] - cz[a]) * t; n++; }
    id[o] = pos.length / 3; pos.push(x0 + (i + px / n) * h, y0 + (j + py / n) * h, z0 + (k + pz / n) * h);
  }
  const quad = (a, b, c, d, fl) => (fl ? idx.push(a, b, c, a, c, d) : idx.push(a, c, b, a, d, c));
  for (let k = 1; k < nz - 1; k++) for (let j = 1; j < ny - 1; j++) for (let i = 1; i < nx - 1; i++) {
    const o = k * sz + j * sy + i, s = v[o] < 0;
    if (s !== v[o + 1] < 0) quad(id[o], id[o - sy], id[o - sy - sz], id[o - sz], s);
    if (s !== v[o + sy] < 0) quad(id[o], id[o - sz], id[o - sz - 1], id[o - 1], s);
    if (s !== v[o + sz] < 0) quad(id[o], id[o - 1], id[o - 1 - sy], id[o - sy], s);
  }
  return { pos, idx };
}
// Ağları birleştir, üçgen renklerini ağırlık merkezinden bul, ölçekle (ve istenirse x'te aynala)
function build(meshes, K, mirror) {
  const pos = [], idx = [], col = [];
  for (const { m, colFn } of meshes) {
    const base = pos.length / 3;
    for (let i = 0; i < m.pos.length; i += 3) pos.push(r4(m.pos[i] * K * (mirror ? -1 : 1)), r4(m.pos[i + 1] * K), r4(m.pos[i + 2] * K));
    for (let t = 0; t < m.idx.length; t += 3) {
      const [a, b, c] = [m.idx[t], m.idx[t + 1], m.idx[t + 2]];
      const g = [0, 1, 2].map((q) => (m.pos[a * 3 + q] + m.pos[b * 3 + q] + m.pos[c * 3 + q]) / 3);
      idx.push(base + a, base + b, base + c); col.push(...colFn(g[0], g[1], g[2]));
    }
  }
  return { pos, idx, col };
}

const mBody = nets(body, [-0.4, 0.7, -0.26], [0.4, 1.9, 0.28], 0.037);
const mMask = nets(mask, [-0.2, 1.48, -0.06], [0.2, 1.82, 0.26], 0.02);
const mArm = nets(arm, [0.1, 0.72, -0.14], [0.4, 1.58, 0.14], 0.031);
const mLeg = nets(leg, [-0.05, -0.03, -0.14], [0.28, 1.09, 0.24], 0.034);
let top = 0; for (let i = 1; i < mBody.pos.length; i += 3) top = Math.max(top, mBody.pos[i]);
const K = HEIGHT / top;
const EYE_Y = 1.656;                          // maske camının ortası (metre)
const parts = [
  { name: "body", pivot: [0, 0, 0], swing: 0, ...build([{ m: mBody, colFn: bodyCol }, { m: mMask, colFn: maskCol }], K) },
  { name: "armL", pivot: [0.235, 1.455, -0.01], swing: 1, ...build([{ m: mArm, colFn: armCol }], K) },
  { name: "armR", pivot: [-0.235, 1.455, -0.01], swing: 1, ...build([{ m: mArm, colFn: armCol }], K, true) },
  { name: "legL", pivot: [0.1, 0.93, 0], swing: 2, ...build([{ m: mLeg, colFn: legCol }], K) },
  { name: "legR", pivot: [-0.1, 0.93, 0], swing: 2, ...build([{ m: mLeg, colFn: legCol }], K, true) },
];
const bb = { min: [1e9, 1e9, 1e9], max: [-1e9, -1e9, -1e9] };
for (const p of parts) {
  p.pivot = p.pivot.map((v) => r4(v * K)); p.mat = 0;
  for (let i = 0; i < p.pos.length; i++) { const a = i % 3; bb.min[a] = Math.min(bb.min[a], p.pos[i]); bb.max[a] = Math.max(bb.max[a], p.pos[i]); }
}
const out = { mats: [{ n: "Hazmat", c: [255, 255, 255], d: 1, e: 0 }], parts, bb, eye: r4(EYE_Y * K) };
const models = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
models.chars.hazmat = out;
fs.writeFileSync(jsonPath, JSON.stringify(models));
console.log("hazmat parçaları:", parts.map((p) => `${p.name}:${p.idx.length / 3}`).join(" "), "toplam", parts.reduce((a, p) => a + p.idx.length / 3, 0));
console.log("boy", r4(bb.max[1]), "göz yüksekliği (model)", out.eye, "-> scale 0.27 ile", r4(out.eye * 0.27));
console.log("models.json", (fs.statSync(jsonPath).size / 1024).toFixed(0), "KB");
