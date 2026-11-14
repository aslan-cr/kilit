// Kadın referans modelini (HuBMAP "3D Reference Organ Set for Female v1.5", CC BY 4.0) uygulamanın parça biçimine pişirir.
//   npm i meshoptimizer        (bir kez, herhangi bir klasörde; NODE_PATH ile gösterilebilir)
//   node organlar/tools/bake-female.mjs <oran, örn. 0.22> <asıl.glb> [ek.glb ...]
// Birden çok sürüm verilirse ilki esas alınır; sonrakilerden yalnızca ilkinde ADI bulunmayan parçalar eklenir
// (v1.9'da ağız/diş/göğüs kemiği var ama bağırsaklar ve pankreas yok; v1.5'te tersi. Koordinatları aynıdır).
// Çıktı: organlar/src/main/assets/models/atlas-female.json + fbody-N.bin.gz
// Biçim (erkek modelle aynı): parça başına Float32 konum, Int16 normal, Uint32 indis; hepsi 4 bayta hizalı.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const require = createRequire(path.join(process.cwd(), "x.js"));
const { MeshoptSimplifier } = require("meshoptimizer");
await MeshoptSimplifier.ready;

const [ratioArg, ...srcs] = process.argv.slice(2);
const RATIO = Number(ratioArg || 0.22), ERR = 0.004, CHUNK = 4.2e6;
const OUT = path.join(path.dirname(fileURLToPath(import.meta.url)), "../src/main/assets/models");

// ---- GLB oku
function loadGlb(src) {
  const buf = fs.readFileSync(src);
  const jl = buf.readUInt32LE(12), g = JSON.parse(buf.toString("utf8", 20, 20 + jl));
  const bin = buf.subarray(20 + jl + 8);
  function acc(i) {
    const a = g.accessors[i], bv = g.bufferViews[a.bufferView], n = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[a.type];
    const off = bin.byteOffset + (bv.byteOffset || 0) + (a.byteOffset || 0);
    const T = { 5126: Float32Array, 5125: Uint32Array, 5123: Uint16Array, 5121: Uint8Array }[a.componentType];
    const size = T.BYTES_PER_ELEMENT * n, stride = bv.byteStride || size;
    if (stride === size && off % T.BYTES_PER_ELEMENT === 0) return new T(bin.buffer, off, a.count * n);
    const out = new T(a.count * n), dv = new DataView(bin.buffer, off);
    const rd = { 5126: "getFloat32", 5125: "getUint32", 5123: "getUint16", 5121: "getUint8" }[a.componentType];
    for (let k = 0; k < a.count; k++) for (let c = 0; c < n; c++) out[k * n + c] = dv[rd](k * stride + c * T.BYTES_PER_ELEMENT, true);
    return out;
  }
  return { g, acc };
}
// 4x4 (sütun öncelikli) yardımcıları: düğüm dönüşümleri (v1.9'da deri kabuğu ölçekli ve döndürülmüş gelir)
const IDENT = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
function mul(a, b) { const o = new Array(16); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) { let v = 0; for (let k = 0; k < 4; k++) v += a[k * 4 + r] * b[c * 4 + k]; o[c * 4 + r] = v; } return o; }
function local(n) {
  if (n.matrix) return n.matrix;
  const t = n.translation || [0, 0, 0], q = n.rotation || [0, 0, 0, 1], s = n.scale || [1, 1, 1], [x, y, z, w] = q;
  return [(1 - 2 * (y * y + z * z)) * s[0], 2 * (x * y + z * w) * s[0], 2 * (x * z - y * w) * s[0], 0,
    2 * (x * y - z * w) * s[1], (1 - 2 * (x * x + z * z)) * s[1], 2 * (y * z + x * w) * s[1], 0,
    2 * (x * z + y * w) * s[2], 2 * (y * z - x * w) * s[2], (1 - 2 * (x * x + y * y)) * s[2], 0, t[0], t[1], t[2], 1];
}
const xf = (m, x, y, z) => [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13], m[2] * x + m[6] * y + m[10] * z + m[14]];

// ---- Sistem eşlemesi (kaynak grup adı -> uygulamadaki sistem)
const SKIP = /placenta|umbilical|chorion|amnio|Yao_lymph_node|Yao_/i;       // gebelik başvuru parçaları ve ölçek dışı lenf düğümü örneği alınmaz
function systemOf(p) {
  const top = p[0], all = p.join(" ").toLowerCase(), leaf = p[p.length - 1].toLowerCase();
  if (/integumentary/.test(top)) return /mammary/.test(all) ? "reproductive" : "integumentary";
  if (/nervous/.test(top)) return /_eyes?\b|eye_[rl]|nerves_of_eye/.test(all) && !/nerve|dura/.test(leaf) ? "sensory" : "nervous";
  if (/muscular/.test(top)) return "muscular";
  if (/reproductive/.test(top)) return "reproductive";
  if (/digestive/.test(top)) return "digestive";
  if (/urinary/.test(top)) return "urinary";
  if (/respiratory/.test(top)) return "respiratory";
  if (/lymphatic/.test(top)) return /thymus/.test(all) ? "endocrine" : "lymphatic";
  if (/lower_limb/.test(top)) return /muscle|muscul/.test(all) ? "muscular" : /ligament|cartilage|menisc|enthesis|tendon/.test(all) ? "connective" : "skeletal";
  if (/skeletal/.test(top)) return /ligament|cartilage|menisc|enthesis/.test(all) ? "connective" : "skeletal";
  if (/circulatory/.test(top)) {
    if (/blood_vasculature/.test(all)) return /vein|vena|venous|sinus/.test(leaf) || (/veins?_/.test(all) && !/arter|aort/.test(leaf)) ? "venous" : "arterial";
    return "cardiac";
  }
  return "connective";
}
const clean = (s) => s.replace(/^(VH_F_|Allen_)/, "").replace(/_/g, " ").replace(/\s+/g, " ").trim()
  .replace(/ ([RL])( [a-z])?$/, (m, s, x) => (s === "R" ? " (right)" : " (left)") + (x ? x : ""));

// ---- Düğümleri gez
const leaves = [], groups = [], seen = new Set(), groupByName = new Map();
srcs.forEach((src, si) => {
  const G = loadGlb(src), g = G.g; let added = 0;
  function walk(i, pth, gids, M) {
    const n = g.nodes[i], W = n.matrix || n.translation || n.rotation || n.scale ? mul(M, local(n)) : M;
    const p = pth.concat(n.name);
    if (SKIP.test(p.join("/"))) return;
    let mine = gids;
    if (n.children && pth.length >= 1) {
      let gi = groupByName.get(n.name);
      if (gi === undefined) { gi = groups.length; groupByName.set(n.name, gi); groups.push({ id: "FG" + String(gi + 1).padStart(4, "0"), name: clean(n.name), elements: [] }); }
      mine = gids.concat(gi);
    }
    if (n.mesh != null && !seen.has(n.name)) { seen.add(n.name); added++; leaves.push({ name: n.name, path: p.slice(1), mesh: n.mesh, gids: mine, G, W }); }
    (n.children || []).forEach((c) => walk(c, p, mine, W));
  }
  g.scenes[g.scene || 0].nodes.forEach((r) => walk(r, [], [], IDENT));
  console.log(path.basename(src), "->", added, "parça alındı");
});

// ---- Sahneye oturt: ayak tabanı y=0, x/z ortada
let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
for (const l of leaves) for (const pr of l.G.g.meshes[l.mesh].primitives) {
  const a = l.G.g.accessors[pr.attributes.POSITION];
  for (let c = 0; c < 8; c++) { const v = xf(l.W, c & 1 ? a.max[0] : a.min[0], c & 2 ? a.max[1] : a.min[1], c & 4 ? a.max[2] : a.min[2]); for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], v[k]); mx[k] = Math.max(mx[k], v[k]); } }
}
const OFF = [-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2];
console.log("kaynak sınırlar", mn, mx, "boy", (mx[1] - mn[1]).toFixed(3), "m");

// ---- Parçaları işle
const parts = [], chunks = [[]]; let chunkBytes = 0, srcTri = 0, outTri = 0;
const pad4 = (n) => (n + 3) & ~3;
leaves.forEach((l, li) => {
  // ilkel(ler)i birleştir + çakışan köşeleri kaynakla
  const map = new Map(), P = [], I = [];
  for (const pr of l.G.g.meshes[l.mesh].primitives) {
    const pos = l.G.acc(pr.attributes.POSITION), idx = pr.indices != null ? l.G.acc(pr.indices) : null, n = idx ? idx.length : pos.length / 3;
    for (let k = 0; k < n; k++) {
      const v = idx ? idx[k] : k, w = l.W === IDENT ? [pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]] : xf(l.W, pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]);
      const x = w[0] + OFF[0], y = w[1] + OFF[1], z = w[2] + OFF[2];
      const key = Math.round(x * 2e5) + "," + Math.round(y * 2e5) + "," + Math.round(z * 2e5);
      let id = map.get(key); if (id === undefined) { id = P.length / 3; map.set(key, id); P.push(x, y, z); }
      I.push(id);
    }
  }
  let pos = new Float32Array(P), ind = new Uint32Array(I);
  srcTri += ind.length / 3;
  // dejenere üçgenleri at
  { let w = 0; for (let k = 0; k < ind.length; k += 3) { const a = ind[k], b = ind[k + 1], c = ind[k + 2]; if (a !== b && b !== c && a !== c) { ind[w++] = a; ind[w++] = b; ind[w++] = c; } } ind = ind.subarray(0, w); }
  if (ind.length < 3) return;
  const tri = ind.length / 3;
  if (tri > 600) {
    const target = Math.max(600, Math.floor(tri * RATIO)) * 3;
    const [res] = MeshoptSimplifier.simplify(ind, pos, 3, target, ERR, ["LockBorder"].slice(0, 0));
    if (res.length >= 3) ind = res;
  }
  // kullanılmayan köşeleri at
  const remap = new Int32Array(pos.length / 3).fill(-1); let nv = 0;
  for (let k = 0; k < ind.length; k++) { if (remap[ind[k]] < 0) remap[ind[k]] = nv++; }
  const p2 = new Float32Array(nv * 3), i2 = new Uint32Array(ind.length);
  for (let v = 0; v < remap.length; v++) if (remap[v] >= 0) { p2[remap[v] * 3] = pos[v * 3]; p2[remap[v] * 3 + 1] = pos[v * 3 + 1]; p2[remap[v] * 3 + 2] = pos[v * 3 + 2]; }
  for (let k = 0; k < ind.length; k++) i2[k] = remap[ind[k]];
  // yumuşak normaller (alan ağırlıklı)
  const N = new Float32Array(nv * 3);
  for (let k = 0; k < i2.length; k += 3) {
    const a = i2[k] * 3, b = i2[k + 1] * 3, c = i2[k + 2] * 3;
    const ux = p2[b] - p2[a], uy = p2[b + 1] - p2[a + 1], uz = p2[b + 2] - p2[a + 2], vx = p2[c] - p2[a], vy = p2[c + 1] - p2[a + 1], vz = p2[c + 2] - p2[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    for (const q of [a, b, c]) { N[q] += nx; N[q + 1] += ny; N[q + 2] += nz; }
  }
  const n16 = new Int16Array(nv * 3), bmin = [1e9, 1e9, 1e9], bmax = [-1e9, -1e9, -1e9];
  for (let v = 0; v < nv; v++) {
    const l2 = Math.hypot(N[v * 3], N[v * 3 + 1], N[v * 3 + 2]) || 1;
    for (let c = 0; c < 3; c++) { n16[v * 3 + c] = Math.round((N[v * 3 + c] / l2) * 32767); bmin[c] = Math.min(bmin[c], p2[v * 3 + c]); bmax[c] = Math.max(bmax[c], p2[v * 3 + c]); }
  }
  const bytes = nv * 12 + pad4(nv * 6) + i2.length * 4;
  if (chunkBytes + bytes > CHUNK && chunkBytes > 0) { chunks.push([]); chunkBytes = 0; }
  const id = "FF" + String(parts.length + 1).padStart(4, "0"), gid = l.gids.length ? groups[l.gids[l.gids.length - 1]].id : id;
  const part = { id, name: clean(l.name), conceptId: gid, system: systemOf(l.path), chunk: chunks.length - 1, positions: chunkBytes, normals: chunkBytes + nv * 12, indices: chunkBytes + nv * 12 + pad4(nv * 6), vertexCount: nv, indexCount: i2.length, bounds: [bmin, bmax] };
  chunks[chunks.length - 1].push({ p2, n16, i2, nv });
  chunkBytes += bytes; parts.push(part); outTri += i2.length / 3;
  for (const gi of l.gids) groups[gi].elements.push(id);
  if (li % 100 === 0) console.log(li + "/" + leaves.length, part.name, tri, "->", i2.length / 3);
});

// ---- Yaz
for (const f of fs.readdirSync(OUT)) if (/^fbody-\d+\.bin(\.gz)?$/.test(f)) fs.unlinkSync(path.join(OUT, f));
const chunkMeta = chunks.map((c, ci) => {
  const total = c.reduce((s, m) => s + m.nv * 12 + pad4(m.nv * 6) + m.i2.length * 4, 0), b = Buffer.alloc(total); let o = 0;
  for (const m of c) {
    Buffer.from(m.p2.buffer, m.p2.byteOffset, m.p2.byteLength).copy(b, o); o += m.nv * 12;
    Buffer.from(m.n16.buffer, m.n16.byteOffset, m.n16.byteLength).copy(b, o); o += pad4(m.nv * 6);
    Buffer.from(m.i2.buffer, m.i2.byteOffset, m.i2.byteLength).copy(b, o); o += m.i2.length * 4;
  }
  const gz = zlib.gzipSync(b, { level: 9 });
  fs.writeFileSync(path.join(OUT, `fbody-${ci}.bin.gz`), gz);
  return { url: `/models/fbody-${ci}.bin`, bytes: total, gzip: `/models/fbody-${ci}.bin.gz`, gzipBytes: gz.length };
});
const concepts = groups.filter((x) => x.elements.length > 1);
const atlas = { version: "HRA 3D Reference Organ Set for Female v1.9 + v1.5", parts, chunks: chunkMeta, triangles: outTri, concepts, sourceTriangles: srcTri,
  optimized: { method: "meshoptimizer quadric simplification", maximumRelativeError: ERR, preservedMeshes: parts.length }, sex: "female", source: "Human Reference Atlas (HuBMAP)",
  scope: `Adult female reference organ set · ${parts.length} source meshes` };
fs.writeFileSync(path.join(OUT, "atlas-female.json"), JSON.stringify(atlas));
const bySys = {}; parts.forEach((p) => (bySys[p.system] = (bySys[p.system] || 0) + 1));
console.log("parça", parts.length, "kavram", concepts.length, "üçgen", srcTri, "->", outTri, "gzip MB", (chunkMeta.reduce((s, c) => s + c.gzipBytes, 0) / 1e6).toFixed(1), bySys);
