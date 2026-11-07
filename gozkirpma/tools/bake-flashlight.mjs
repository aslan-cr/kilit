// El feneri paketini (GLB) models.json'a ekler: models.flash.<ad> = { pos, uv, idx, tex, ext }.
// Kullanım: node tools/bake-flashlight.mjs <FLAHLIGHT_PACK klasörü>   (ardından doku için tools/shrink-tex.py gerekebilir)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "../src/main/assets/models");
const src = process.argv[2];
if (!src) { console.error("kullanım: node bake-flashlight.mjs <paket klasörü>"); process.exit(1); }
const r4 = (x) => Math.round(x * 1e4) / 1e4;

function readGlb(file) {
  const b = fs.readFileSync(file), jl = b.readUInt32LE(12), j = JSON.parse(b.subarray(20, 20 + jl).toString());
  const bin = b.subarray(20 + jl + 8);
  const acc = (i) => {
    const a = j.accessors[i], v = j.bufferViews[a.bufferView], n = { SCALAR: 1, VEC2: 2, VEC3: 3 }[a.type];
    const ct = { 5126: Float32Array, 5123: Uint16Array, 5125: Uint32Array }[a.componentType];
    const off = (v.byteOffset || 0) + (a.byteOffset || 0), stride = v.byteStride || n * ct.BYTES_PER_ELEMENT;
    const out = [];
    for (let k = 0; k < a.count; k++) { const dv = new ct(bin.buffer.slice(bin.byteOffset + off + k * stride, bin.byteOffset + off + k * stride + n * ct.BYTES_PER_ELEMENT)); for (let c = 0; c < n; c++) out.push(dv[c]); }
    return out;
  };
  const p = j.meshes[0].primitives[0];
  return { pos: acc(p.attributes.POSITION), uv: acc(p.attributes.TEXCOORD_0), idx: acc(p.indices) };
}

const json = JSON.parse(fs.readFileSync(path.join(OUT, "models.json"), "utf8"));
json.flash = {};
fs.mkdirSync(path.join(OUT, "tex"), { recursive: true });
for (const n of [1, 2, 3]) {
  const m = readGlb(path.join(src, "GLB", `FlashLight_Set_5_${n}.glb`));
  const ext = [0, 1, 2].map((a) => { const v = m.pos.filter((_, i) => i % 3 === a); return [r4(Math.min(...v)), r4(Math.max(...v))]; });
  json.flash["fl" + n] = { pos: m.pos.map(r4), uv: m.uv.map(r4), idx: m.idx, tex: "models/tex/FlashLight_base.png", ext };
  console.log("fl" + n, "köşe", m.pos.length / 3, "üçgen", m.idx.length / 3, "ext", JSON.stringify(ext));
}
fs.writeFileSync(path.join(OUT, "models.json"), JSON.stringify(json));
