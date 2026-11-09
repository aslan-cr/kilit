// Sıska Canavar (three.js ile yazılmış, kodla üretilen model) -> oyunun models.json'una "monster" karakteri olarak pişirir.
//   node tools/bake-monster.mjs <siska-canavar/canavar-model.js> [models.json]
// three.js yerine bu dosyadaki küçük bir "THREE" taklidi kullanılır (yalnızca modelin kullandığı kısım). Segment sayıları oyun için düşürülür.
import fs from "node:fs";
const src0 = fs.readFileSync(process.argv[2], "utf8");
const outPath = process.argv[3] || new URL("../src/main/assets/models/models.json", import.meta.url).pathname;
const Q = { tube: 0.1, rad: 0.35, sph: [12, 8], cone: 4, hair: 0.12, thick: 1.5, minR: 0.022, targetH: 2.177 };   // targetH: eski cadının boyu (oyundaki boyut aynı kalır)

// ---- minik THREE ----
class V3 { constructor(x = 0, y = 0, z = 0) { this.x = x; this.y = y; this.z = z; }
  set(x, y, z) { this.x = x; this.y = y; this.z = z; return this; } clone() { return new V3(this.x, this.y, this.z); }
  crossVectors(a, b) { this.set(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x); return this; }
  length() { return Math.hypot(this.x, this.y, this.z); } normalize() { const l = this.length() || 1; this.x /= l; this.y /= l; this.z /= l; return this; }
  dot(o) { return this.x * o.x + this.y * o.y + this.z * o.z; } }
class Curve { constructor(pts) { this.p = pts; this._len = null; }
  getPoint(t) { const p = this.p, n = p.length - 1, f = t * n, i = Math.min(n - 1, Math.floor(f)), w = f - i;
    const g = (k) => (k < 0 ? new V3(2 * p[0].x - p[1].x, 2 * p[0].y - p[1].y, 2 * p[0].z - p[1].z) : k > n ? new V3(2 * p[n].x - p[n - 1].x, 2 * p[n].y - p[n - 1].y, 2 * p[n].z - p[n - 1].z) : p[k]);
    const p0 = g(i - 1), p1 = g(i), p2 = g(i + 1), p3 = g(i + 2), w2 = w * w, w3 = w2 * w, o = new V3();
    for (const a of ["x", "y", "z"]) o[a] = 0.5 * ((2 * p1[a]) + (-p0[a] + p2[a]) * w + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * w2 + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * w3);
    return o; }
  lengths() { if (this._len) return this._len; const L = [0]; let prev = this.getPoint(0); for (let i = 1; i <= 200; i++) { const q = this.getPoint(i / 200); L.push(L[i - 1] + Math.hypot(q.x - prev.x, q.y - prev.y, q.z - prev.z)); prev = q; } return (this._len = L); }
  tOf(u) { const L = this.lengths(), tot = L[200], target = u * tot; let lo = 0, hi = 200; while (lo < hi) { const m = (lo + hi) >> 1; if (L[m] < target) lo = m + 1; else hi = m; } if (lo === 0) return 0; const a = L[lo - 1], b = L[lo]; return (lo - 1 + (b > a ? (target - a) / (b - a) : 0)) / 200; }
  getPointAt(u) { return this.getPoint(this.tOf(u)); }
  getTangentAt(u) { const t = this.tOf(u), a = this.getPoint(Math.max(0, t - 1e-3)), b = this.getPoint(Math.min(1, t + 1e-3)); return new V3(b.x - a.x, b.y - a.y, b.z - a.z).normalize(); }
  computeFrenetFrames(seg) {
    const T = [], N = [], B = [];
    for (let i = 0; i <= seg; i++) T.push(this.getTangentAt(i / seg));
    const t0 = T[0]; let min = Infinity, ax = new V3(1, 0, 0);
    const ab = [Math.abs(t0.x), Math.abs(t0.y), Math.abs(t0.z)], mi = ab.indexOf(Math.min(...ab)); ax = new V3(mi === 0 ? 1 : 0, mi === 1 ? 1 : 0, mi === 2 ? 1 : 0);
    const vec = new V3().crossVectors(t0, ax).normalize(); N[0] = new V3().crossVectors(t0, vec).normalize(); B[0] = new V3().crossVectors(t0, N[0]);
    for (let i = 1; i <= seg; i++) {
      N[i] = N[i - 1].clone(); B[i] = B[i - 1].clone();
      const v = new V3().crossVectors(T[i - 1], T[i]);
      if (v.length() > 1e-9) { v.normalize(); const th = Math.acos(Math.max(-1, Math.min(1, T[i - 1].dot(T[i])))), c = Math.cos(th), s = Math.sin(th), n = N[i];
        const d = v.dot(n), cr = new V3().crossVectors(v, n); N[i] = new V3(n.x * c + cr.x * s + v.x * d * (1 - c), n.y * c + cr.y * s + v.y * d * (1 - c), n.z * c + cr.z * s + v.z * d * (1 - c)); }
      B[i] = new V3().crossVectors(T[i], N[i]);
    }
    return { tangents: T, normals: N, binormals: B }; } }
class Geo { constructor() { this.a = {}; this.index = null; } setAttribute(n, at) { this.a[n] = at; } setIndex(i) { this.index = i; }
  translate(x, y, z) { const p = this.a.position.array; for (let i = 0; i < p.length; i += 3) { p[i] += x; p[i + 1] += y; p[i + 2] += z; } } }
const F32 = class { constructor(arr, n) { this.array = arr; this.n = n; } };
class Obj { constructor() { this.position = new V3(); this.rotation = { x: 0, y: 0, z: 0, set(a, b, c) { this.x = a; this.y = b; this.z = c; } }; this.scale = new V3(1, 1, 1); this.scale.setScalar = (s) => this.scale.set(s, s, s); this.children = []; this.parent = null; this.visible = true; }
  add(o) { o.parent = this; this.children.push(o); } }
const mkMat = (o) => ({ color: { hex: o && o.color, set() {} } });
function sphereGeo(W, H) { const g = new Geo(), pos = [], idx = []; for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) { const u = x / W, v = y / H; pos.push(-Math.cos(u * 2 * Math.PI) * Math.sin(v * Math.PI), Math.cos(v * Math.PI), Math.sin(u * 2 * Math.PI) * Math.sin(v * Math.PI)); }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const a = y * (W + 1) + x, b = a + W + 1; if (y !== 0) idx.push(a, b, a + 1); if (y !== H - 1) idx.push(b, b + 1, a + 1); }
  g.setAttribute("position", new F32(pos, 3)); g.setIndex(idx); return g; }
const THREE = {
  Vector3: V3, CatmullRomCurve3: Curve, BufferGeometry: Geo, Float32BufferAttribute: F32, AdditiveBlending: 2,
  Group: class extends Obj {}, Sprite: class extends Obj { constructor() { super(); } }, PointLight: class extends Obj {},
  Mesh: class extends Obj { constructor(g, m) { super(); this.geometry = g; this.material = m; } },
  MeshStandardMaterial: function (o) { return mkMat(o); }, MeshPhysicalMaterial: function (o) { return mkMat(o); }, MeshBasicMaterial: function (o) { return mkMat(o); }, SpriteMaterial: function (o) { return mkMat(o); },
  CanvasTexture: function () { return {}; },
  SphereGeometry: function () { const g = sphereGeo(14, 10); g.isSphere = true; return g; },
  ConeGeometry: function (r, h, n) { const g = new Geo(), N = Q.cone, pos = [0, h / 2, 0], idx = []; for (let i = 0; i < N; i++) pos.push(r * Math.sin(i / N * 2 * Math.PI), -h / 2, r * Math.cos(i / N * 2 * Math.PI));
    for (let i = 0; i < N; i++) { const a = 1 + i, b = 1 + (i + 1) % N; idx.push(0, b, a); } g.setAttribute("position", new F32(pos, 3)); g.setIndex(idx); return g; },
};
globalThis.document = { createElement: () => ({ getContext: () => ({ createRadialGradient: () => ({ addColorStop() {} }), fillRect() {} }) }) };

// kaynağı oyun için seyrelt: tüp çözünürlüğü, ince tüpleri kalınlaştır
let src = src0
  .replace("var tub = o.tub || 64, rad = o.rad || 14,", `var tub = Math.max(o.hair ? 4 : 5, Math.round((o.tub || 64) * (o.hair ? ${Q.hair} : ${Q.tube}))), rad = Math.max(o.hair ? 3 : 4, Math.round((o.rad || 14) * ${Q.rad})),`)
  .replace("var r = rfn(t) * (e > 0 ? cap(t, e) : 1);", `var r = Math.max(${Q.minR}, rfn(t) * ${Q.thick}) * (e > 0 ? cap(t, e) : 1);`)
  .replace("{ tub: 50, rad: 5, cap: 0 }", "{ tub: 50, rad: 5, cap: 0, hair: 1 }");
const createMonster = new Function(src + "\nreturn createMonster;")();
const mon = createMonster(THREE, { scale: 1 });
mon.update(0, { jaw: 0.62, breathe: false });

// ---- dünya matrisleri (T*Rx*Ry*Rz*S) ----
const mul = (a, b) => { const o = new Array(16).fill(0); for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) for (let k = 0; k < 4; k++) o[r * 4 + c] += a[r * 4 + k] * b[k * 4 + c]; return o; };
function local(o) { const { x: a, y: b, z: c } = o.rotation, ca = Math.cos(a), sa = Math.sin(a), cb = Math.cos(b), sb = Math.sin(b), cc = Math.cos(c), sc = Math.sin(c);
  const Rx = [1, 0, 0, 0, 0, ca, -sa, 0, 0, sa, ca, 0, 0, 0, 0, 1], Ry = [cb, 0, sb, 0, 0, 1, 0, 0, -sb, 0, cb, 0, 0, 0, 0, 1], Rz = [cc, -sc, 0, 0, sc, cc, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  const S = [o.scale.x, 0, 0, 0, 0, o.scale.y, 0, 0, 0, 0, o.scale.z, 0, 0, 0, 0, 1], T = [1, 0, 0, o.position.x, 0, 1, 0, o.position.y, 0, 0, 1, o.position.z, 0, 0, 0, 1];
  return mul(T, mul(Rx, mul(Ry, mul(Rz, S)))); }
const world = (o) => (o.parent ? mul(world(o.parent), local(o)) : local(o));
const W0 = (o) => { let k = 1; for (let p = o.parent; p; p = p.parent) k *= p.scale.x; return k; };
const armOf = (o) => { for (let p = o; p; p = p.parent) { const a = mon.parts.arms.find((x) => x.g === p); if (a) return a; } return null; };
const MATS = { [0x858a80]: ["Skin", [150, 156, 142]], [0xd7cdb2]: ["Bone", [226, 216, 188]], [0xb5aa8f]: ["Horn", [190, 180, 150]], [0xece3c9]: ["Tooth", [240, 232, 205]], [0x040405]: ["Dark", [10, 10, 12]], [0x7a2f3a]: ["Tongue", [150, 52, 66]], [0x0b0b0d]: ["Hair", [14, 14, 18]], [0xffb040]: ["Eye", [255, 176, 64]] };
const matKeys = Object.keys(MATS).map(Number);
const buckets = new Map();   // "mat|arm" -> {pos, idx}
(function walk(o) {
  if (o.geometry && o.visible !== false) {
    const hex = o.material.color.hex; if (!MATS[hex]) throw new Error("bilinmeyen malzeme " + hex.toString(16));
    if (process.env.DBG && o.geometry.isSphere) console.log("sph", o.scale.x, W0(o), hex.toString(16));
    if (o.geometry.isSphere) { const sc = Math.max(o.scale.x, o.scale.y, o.scale.z) * (W0(o)); o.geometry = sc > 0.25 ? sphereGeo(12, 8) : sc > 0.09 ? sphereGeo(8, 6) : sphereGeo(6, 4); }
    const arm = armOf(o), key = matKeys.indexOf(hex) + "|" + (arm ? arm.s : 0), W = world(o);
    let b = buckets.get(key); if (!b) buckets.set(key, (b = { pos: [], idx: [], mat: matKeys.indexOf(hex), arm: arm ? arm.s : 0 }));
    const p = o.geometry.a.position.array, base = b.pos.length / 3;
    for (let i = 0; i < p.length; i += 3) b.pos.push(W[0] * p[i] + W[1] * p[i + 1] + W[2] * p[i + 2] + W[3], W[4] * p[i] + W[5] * p[i + 1] + W[6] * p[i + 2] + W[7], W[8] * p[i] + W[9] * p[i + 1] + W[10] * p[i + 2] + W[11]);
    if (process.env.DBG) console.log("mesh", hex.toString(16), o.geometry.index.length / 3);
    for (const i of o.geometry.index) b.idx.push(base + i);
  }
  for (const c of o.children) walk(c);
})(mon.group);

let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
for (const b of buckets.values()) for (let i = 0; i < b.pos.length; i += 3) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], b.pos[i + a]); mx[a] = Math.max(mx[a], b.pos[i + a]); }
const k = Q.targetH / (mx[1] - mn[1]), zc = 0.1;       // k: boyu eski cadıyla aynı olacak şekilde ölçek; zc: gövde merkezi orijine
const tf = (x, y, z) => [(x) * k, (y - mn[1]) * k, (z - zc) * k];
const parts = []; let tris = 0;
for (const b of [...buckets.values()].sort((a, c) => a.mat - c.mat || a.arm - c.arm)) {
  const pos = []; for (let i = 0; i < b.pos.length; i += 3) pos.push(...tf(b.pos[i], b.pos[i + 1], b.pos[i + 2]).map((v) => +v.toFixed(4)));
  const name = "monster_" + MATS[matKeys[b.mat]][0] + (b.arm === 1 ? "ArmLeft" : b.arm === -1 ? "ArmRight" : "");
  const pivot = b.arm ? tf(0.38 * b.arm, 3.68, 0.55).map((v) => +v.toFixed(4)) : [0, 0, 0];
  parts.push({ name, pivot, mat: b.mat, pos, idx: b.idx }); tris += b.idx.length / 3;
}
const bb = { min: [mn[0] * k, 0, (mn[2] - zc) * k].map((v) => +v.toFixed(4)), max: [mx[0] * k, (mx[1] - mn[1]) * k, (mx[2] - zc) * k].map((v) => +v.toFixed(4)) };
const mats = matKeys.map((h) => ({ n: MATS[h][0], c: MATS[h][1], d: MATS[h][0] === "Dark" ? 0 : 1, e: MATS[h][0] === "Eye" ? 1 : 0 }));
const json = JSON.parse(fs.readFileSync(outPath, "utf8"));
json.chars.monster = { mats, parts, bb };
fs.writeFileSync(outPath, JSON.stringify(json));
console.log(`canavar pişirildi: ${parts.length} parça, ${tris} üçgen, boy ${bb.max[1]}, bb`, JSON.stringify(bb), "ölçek", k.toFixed(4));
