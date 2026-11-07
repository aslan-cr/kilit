// Hazmat FBX karakterini oyunun models.json dosyasına ekler (chars.hazmat) ve dokusunu kopyalar.
//   node tools/bake-hazmat.mjs <Hazmat klasörü>
// Gövde, iki kol ve iki bacak ayrı parçalara bölünür (kemik ağırlıklarına göre); kollar aşağı indirilir,
// çizici kolları/bacakları pivot etrafında sallayarak yürüme animasyonu verir. Boyut metreye çevrilir.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseFbx, child, childs } from "./fbx.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "../src/main/assets/models");
const dir = process.argv[2];
if (!dir) { console.error("kullanım: node bake-hazmat.mjs <Hazmat klasörü>"); process.exit(1); }
const r4 = (v) => Math.round(v * 10000) / 10000;

const f = parseFbx(path.join(dir, "Hazmat_Character.fbx"));
const obj = f.nodes.find((n) => n.name === "Objects");
const geo = childs(obj, "Geometry")[0];
const model = childs(obj, "Model").find((m) => m.props[2] === "Mesh");
const prop = (name) => { const p = child(child(model, "Properties70"), "Properties70") || child(model, "Properties70"); const c = p.children.find((x) => x.props[0] === name); return c ? c.props.slice(4) : null; };
const S = prop("Lcl Scaling")[0];                                  // 94.956 (cm)
const rotX = (prop("Lcl Rotation")[0] * Math.PI) / 180;            // -90°
// Mesh yerel -> dünya (cm): X ekseni etrafında dönüş + ölçek. Sonra metreye (/100).
const cs = Math.cos(rotX), sn = Math.sin(rotX);
const toWorld = (x, y, z) => [x * S, (y * cs - z * sn) * S, (y * sn + z * cs) * S];

const V = child(geo, "Vertices").props[0];
const PI = child(geo, "PolygonVertexIndex").props[0];
const uvNode = child(geo, "LayerElementUV");
const UV = child(uvNode, "UV").props[0], UVI = child(uvNode, "UVIndex").props[0];

// Köşe -> grup ağırlıkları
const nV = V.length / 3;
const GROUPS = ["body", "armL", "armR", "legL", "legR"];
const groupOf = (bone) => (/^(shoulder|upper_arm|forearm|hand)\.L/.test(bone) ? "armL" : /^(shoulder|upper_arm|forearm|hand)\.R/.test(bone) ? "armR"
  : /^(thigh|shin|foot|toe|heel)[\w.]*\.L/.test(bone) ? "legL" : /^(thigh|shin|foot|toe|heel)[\w.]*\.R/.test(bone) ? "legR" : "body");
const gw = Array.from({ length: nV }, () => ({ body: 0, armL: 0, armR: 0, legL: 0, legR: 0 }));
const pivots = {};
for (const d of childs(obj, "Deformer").filter((d) => d.props[2] === "Cluster")) {
  const bone = String(d.props[1]).split("\0")[0], idx = child(d, "Indexes"), w = child(d, "Weights");
  if (idx) for (let k = 0; k < idx.props[0].length; k++) gw[idx.props[0][k]][groupOf(bone)] += w.props[0][k];
  const tl = child(d, "TransformLink");
  if (tl) pivots[bone] = [tl.props[0][12], tl.props[0][13], tl.props[0][14]];   // bağlama pozunda kemik (cm, dünya)
}
const P = (b) => pivots[b].map((v) => v / 100);
const piv = { armL: P("upper_arm.L"), armR: P("upper_arm.R"), legL: P("thigh.L"), legR: P("thigh.R"), body: [0, 0, 0] };

// Çokgenleri üçgenle, her üçgeni ağırlığı en yüksek gruba ver
const tris = []; let poly = [];
for (let i = 0; i < PI.length; i++) {
  const end = PI[i] < 0, vi = end ? ~PI[i] : PI[i];
  poly.push({ v: vi, uv: UVI[i] });
  if (end) { for (let k = 1; k + 1 < poly.length; k++) tris.push([poly[0], poly[k], poly[k + 1]]); poly = []; }
}
const parts = Object.fromEntries(GROUPS.map((g) => [g, { map: new Map(), pos: [], uv: [], idx: [] }]));
const bb = { min: [1e9, 1e9, 1e9], max: [-1e9, -1e9, -1e9] };
for (const t of tris) {
  const sum = Object.fromEntries(GROUPS.map((g) => [g, 0]));
  for (const c of t) for (const g of GROUPS) sum[g] += gw[c.v][g];
  const grp = GROUPS.reduce((a, b) => (sum[b] > sum[a] ? b : a), "body");
  const part = parts[grp];
  const ids = t.map((c) => {
    const key = c.v + "/" + c.uv;
    if (!part.map.has(key)) {
      part.map.set(key, part.pos.length / 3);
      let w = toWorld(V[c.v * 3], V[c.v * 3 + 1], V[c.v * 3 + 2]).map((v) => v / 100);
      if (grp === "armL" || grp === "armR") {                       // T-pozundan kollar aşağı: omuz etrafında z ekseninde ±76°
        const a = ((grp === "armL" ? -76 : 76) * Math.PI) / 180, p = piv[grp], dx = w[0] - p[0], dy = w[1] - p[1];
        w = [p[0] + dx * Math.cos(a) - dy * Math.sin(a), p[1] + dx * Math.sin(a) + dy * Math.cos(a), w[2]];
      }
      for (let a = 0; a < 3; a++) { bb.min[a] = Math.min(bb.min[a], w[a]); bb.max[a] = Math.max(bb.max[a], w[a]); }
      part.pos.push(r4(w[0]), r4(w[1]), r4(w[2]));
      part.uv.push(r4(UV[c.uv * 2]), r4(UV[c.uv * 2 + 1]));
    }
    return part.map.get(key);
  });
  part.idx.push(...ids);
}
// Kol pivotu: indirilmiş kolun omuz noktası (kol etrafında x ekseninde sallanır)
const out = { mats: [{ n: "Hazmat", c: [255, 255, 255], d: 1, e: 0 }], tex: "models/tex/Hazmet_Tex.png", parts: [] };
for (const g of GROUPS) {
  const p = parts[g];
  if (!p.idx.length) continue;
  out.parts.push({ name: g, pivot: [r4(piv[g][0]), r4(piv[g][1]), r4(piv[g][2])], mat: 0, pos: p.pos, uv: p.uv, idx: p.idx, swing: g === "body" ? 0 : g.startsWith("arm") ? 1 : 2 });
}
out.bb = { min: bb.min.map(r4), max: bb.max.map(r4) };

const jsonPath = path.join(OUT, "models.json");
const models = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
models.chars.hazmat = out;
fs.mkdirSync(path.join(OUT, "tex"), { recursive: true });
fs.copyFileSync(path.join(dir, "Hazmet_Tex.png"), path.join(OUT, "tex/Hazmet_Tex.png"));
fs.writeFileSync(jsonPath, JSON.stringify(models));
console.log("hazmat parçaları:", out.parts.map((p) => `${p.name}:${p.idx.length / 3}üçgen`).join(" "));
console.log("boyut (m):", out.bb.max.map((v, i) => r4(v - out.bb.min[i])).join(" x "), "min", out.bb.min.join());
console.log("pivotlar:", JSON.stringify(piv));
console.log("models.json", (fs.statSync(jsonPath).size / 1024).toFixed(0), "KB");
