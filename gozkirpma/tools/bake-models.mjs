// Varlık paketlerini oyunun okuyacağı küçük bir models.json dosyasına çevirir.
// Kullanım:
//   node tools/bake-models.mjs <KayKit_Spooktober klasörü> <PSXShotgunPack Files klasörü>
// Çıktı: src/main/assets/models/models.json ve models/tex/*.png|jpg
// Neden: Telefondaki WebView'da internet/three.js olmadan, glb/obj ayrıştırmadan modelleri çizebilmek için.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "../src/main/assets/models");
const [spook, guns] = process.argv.slice(2);
if (!spook || !guns) { console.error("kullanım: node bake-models.mjs <spooktober> <shotgun Files>"); process.exit(1); }
fs.mkdirSync(path.join(OUT, "tex"), { recursive: true });

const r4 = (v) => Math.round(v * 10000) / 10000;
const srgb = (c) => Math.round(255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055));

// ---- 4x4 matris yardımcıları (sütun öncelikli, glTF gibi) ----
const I4 = () => [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
function mul(a, b) { const o = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c*4+r] += a[k*4+r] * b[c*4+k]; return o; }
function trs(t = [0,0,0], q = [0,0,0,1], s = [1,1,1]) {
  const [x,y,z,w] = q;
  const m = [1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w), 0,  2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w), 0,  2*(x*z+y*w), 2*(y*z-x*w), 1-2*(x*x+y*y), 0,  0,0,0,1];
  for (let i = 0; i < 3; i++) { m[i] *= s[0]; m[4+i] *= s[1]; m[8+i] *= s[2]; }
  m[12] = t[0]; m[13] = t[1]; m[14] = t[2];
  return m;
}
const xf = (m, p) => [m[0]*p[0]+m[4]*p[1]+m[8]*p[2]+m[12], m[1]*p[0]+m[5]*p[1]+m[9]*p[2]+m[13], m[2]*p[0]+m[6]*p[1]+m[10]*p[2]+m[14]];

// ---- glTF / GLB okuyucu ----
function readGltf(file) {
  const buf = fs.readFileSync(file);
  let json, bin;
  if (file.endsWith(".glb")) {
    const jl = buf.readUInt32LE(12);
    json = JSON.parse(buf.slice(20, 20 + jl).toString("utf8"));
    const off = 20 + jl;
    bin = buf.slice(off + 8, off + 8 + buf.readUInt32LE(off));
  } else {
    json = JSON.parse(buf.toString("utf8"));
    bin = Buffer.from(json.buffers[0].uri.split(",")[1], "base64");
  }
  return { json, bin };
}
function accessor(g, i) {
  const a = g.json.accessors[i], bv = g.json.bufferViews[a.bufferView];
  const n = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[a.type];
  const base = (bv.byteOffset || 0) + (a.byteOffset || 0);
  const comp = a.componentType, size = { 5126: 4, 5125: 4, 5123: 2, 5121: 1 }[comp];
  const stride = bv.byteStride || n * size;
  const out = [];
  for (let k = 0; k < a.count; k++) for (let c = 0; c < n; c++) {
    const o = base + k * stride + c * size;
    out.push(comp === 5126 ? g.bin.readFloatLE(o) : comp === 5125 ? g.bin.readUInt32LE(o) : comp === 5123 ? g.bin.readUInt16LE(o) : g.bin.readUInt8(o));
  }
  return out;
}

function bakeGltf(file, opts = {}) {
  const g = readGltf(file), j = g.json;
  const mats = j.materials.map((m) => {
    const c = m.pbrMetallicRoughness.baseColorFactor;
    const emi = /yellow|flame|fire|glow|light/i.test(m.name) && !/green ?light/i.test(m.name);
    return { n: m.name, c: [srgb(c[0]), srgb(c[1]), srgb(c[2])], d: m.doubleSided ? 1 : 0, e: emi ? 1 : 0 };
  });
  const parts = [];
  const bb = { min: [1e9,1e9,1e9], max: [-1e9,-1e9,-1e9] };
  const walk = (ni, parent) => {
    const n = j.nodes[ni];
    const local = trs(n.translation, n.rotation, n.scale);
    const world = mul(parent, local);
    if (n.mesh !== undefined) {
      for (const p of j.meshes[n.mesh].primitives) {
        const raw = accessor(g, p.attributes.POSITION);
        const pos = [];
        for (let k = 0; k < raw.length; k += 3) {
          const w = xf(world, [raw[k], raw[k+1], raw[k+2]]);
          for (let a = 0; a < 3; a++) { bb.min[a] = Math.min(bb.min[a], w[a]); bb.max[a] = Math.max(bb.max[a], w[a]); }
          pos.push(r4(w[0]), r4(w[1]), r4(w[2]));
        }
        const pivot = xf(world, [0, 0, 0]);
        parts.push({ name: n.name || "", pivot: pivot.map(r4), mat: p.material || 0, pos, idx: accessor(g, p.indices) });
      }
    }
    for (const c of n.children || []) walk(c, world);
  };
  for (const ni of j.scenes[j.scene || 0].nodes) walk(ni, I4());
  return { mats, parts, bb: { min: bb.min.map(r4), max: bb.max.map(r4) } };
}

const models = { props: {}, chars: {}, guns: {} };

// Dekorlar (glb)
const PROPS = ["gravestone","treeA_graveyard","treeB_graveyard","treeC_graveyard","treeD_graveyard","pumpkinLarge","pumpkinSmall",
  "jackolantern_big","jackolantern_small","candleBundle","candleLarge","candleSmall","lampPost","coffinA_bottom","coffinB_bottom",
  "cauldron","shrine","detail_graveyard","fenceSingle","candyBucket"];
for (const n of PROPS) models.props[n] = bakeGltf(path.join(spook, "Models/gltf", n + ".gltf.glb"));

// Karakterler (gltf, iskeletsiz parçalar: kollar ayrı)
models.chars.jack = bakeGltf(path.join(spook, "Models/Characters/Jack/gltf/character_jack.gltf"));
models.chars.witch = bakeGltf(path.join(spook, "Models/Characters/Witch/gltf/character_witch.gltf"));

// ---- Tüfekler (obj + doku) ----
function parseObj(file, texFile) {
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
  const v = [], vt = [];
  let skip = false;
  const pos = [], uv = [], idx = [];
  const map = new Map();
  for (const ln of lines) {
    const t = ln.trim().split(/\s+/);
    if (t[0] === "v") v.push([+t[1], +t[2], +t[3]]);
    else if (t[0] === "vt") vt.push([+t[1], +t[2]]);
    else if (t[0] === "o" || t[0] === "g") skip = /shell/i.test(t[1] || ""); // mermi modelleri dahil değil
    else if (t[0] === "f" && !skip) {
      const face = t.slice(1).map((s) => {
        const [a, b] = s.split("/");
        const key = a + "/" + b;
        if (!map.has(key)) { map.set(key, pos.length / 3); const p = v[+a - 1], u = b ? vt[+b - 1] : [0, 0]; pos.push(...p); uv.push(u[0], u[1]); }
        return map.get(key);
      });
      for (let k = 1; k + 1 < face.length; k++) idx.push(face[0], face[k], face[k + 1]);
    }
  }
  // eksenler: en uzun eksen = namlu. Uzunluk 1'e ölçeklenir, merkez namlunun ortasına alınır.
  const mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9];
  for (let k = 0; k < pos.length; k += 3) for (let a = 0; a < 3; a++) { mn[a] = Math.min(mn[a], pos[k+a]); mx[a] = Math.max(mx[a], pos[k+a]); }
  const ext = mx.map((m, a) => m - mn[a]);
  const L = Math.max(...ext), la = ext.indexOf(L);
  // Basit kural: x = namlu (obj'lerde böyle), y = yukarı, z = yan.
  const out = [];
  for (let k = 0; k < pos.length; k += 3) {
    const x = (pos[k] - (mn[0] + mx[0]) / 2) / L, y = (pos[k+1] - mn[1]) / L, z = (pos[k+2] - (mn[2] + mx[2]) / 2) / L;
    out.push(r4(x), r4(y), r4(z));
  }
  return { pos: out, uv: uv.map(r4), idx, tex: texFile, length: r4(L), axes: { la, ext: ext.map(r4) } };
}
const GUN_FILES = {
  pump:      ["pumpActionShotgun/PumpActionShotgun.obj", "pumpActionShotgun/Textures/PAShotgunText.png"],
  double:    ["DoubleBarrelShotgun/DoubleBarrelShotgun.obj", "DoubleBarrelShotgun/Textures/DBShotgunText.png"],
  sawed:     ["DoubleBarrelShotgun/DBSawedOffShotgun.obj", "DoubleBarrelShotgun/Textures/DBShotgunText.png"],
  overUnder: ["overUnderShotGun/OverUnderShotgun.obj", "overUnderShotGun/Textures/overUnderRef.png"],
};
for (const [k, [obj, tex]] of Object.entries(GUN_FILES)) {
  const name = path.basename(tex);
  fs.copyFileSync(path.join(guns, tex), path.join(OUT, "tex", name));
  models.guns[k] = parseObj(path.join(guns, obj), "models/tex/" + name);
}

fs.writeFileSync(path.join(OUT, "models.json"), JSON.stringify(models));
const kb = (fs.statSync(path.join(OUT, "models.json")).size / 1024).toFixed(0);
console.log("models.json", kb, "KB");
for (const [k, m] of Object.entries(models.props)) console.log("prop", k, m.bb.max.map((v, i) => r4(v - m.bb.min[i])).join(" x "));
for (const [k, m] of Object.entries(models.chars)) console.log("char", k, m.bb.max.map((v, i) => r4(v - m.bb.min[i])).join(" x "), "min", m.bb.min.join());
for (const [k, m] of Object.entries(models.guns)) console.log("gun", k, JSON.stringify(m.axes), "tris", m.idx.length / 3);
