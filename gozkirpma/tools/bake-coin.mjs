// Para (coin) FBX'ini models.json'a ekler (models.coin) ve dokusunu (renk x AO) küçük bir PNG yapar.
//   node tools/bake-coin.mjs <coin.fbx> <coinC_2.png> <coinAO.png>
// Para dik duran bir disktir: yarıçap 1, disk düzlemi xy, kalınlık ekseni z. Çizici dikey eksende döndürür.
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { parseFbx, child, childs } from "./fbx.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, "../src/main/assets/models");
const [fbx, colorPng, aoPng] = process.argv.slice(2);
if (!fbx || !colorPng || !aoPng) { console.error("kullanım: node bake-coin.mjs <coin.fbx> <coinC_2.png> <coinAO.png>"); process.exit(1); }
const r4 = (v) => Math.round(v * 1e4) / 1e4;

const f = parseFbx(fbx);
const geo = childs(f.nodes.find((n) => n.name === "Objects"), "Geometry")[0];
const V = child(geo, "Vertices").props[0], PI = child(geo, "PolygonVertexIndex").props[0];
const uvNode = child(geo, "LayerElementUV"), UV = child(uvNode, "UV").props[0], UVI = child(uvNode, "UVIndex").props[0];

const map = new Map(), pos = [], uv = [], idx = []; let poly = [];
for (let i = 0; i < PI.length; i++) {
  const end = PI[i] < 0, vi = end ? ~PI[i] : PI[i];
  poly.push({ v: vi, uv: UVI[i] });
  if (!end) continue;
  for (let k = 1; k + 1 < poly.length; k++) for (const c of [poly[0], poly[k], poly[k + 1]]) {
    const key = c.v + "/" + c.uv;
    if (!map.has(key)) {
      map.set(key, pos.length / 3);
      const rx = V[c.v * 3], ry = V[c.v * 3 + 1], rz = V[c.v * 3 + 2];
      pos.push(r4(ry), r4(rz), r4(rx));                        // ham: eksen x, düzlem yz  ->  düzlem xy, eksen z (çift permütasyon: yön korunur)
      uv.push(r4(UV[c.uv * 2]), r4(UV[c.uv * 2 + 1]));
    }
    idx.push(map.get(key));
  }
  poly = [];
}
// Dokuyu üret: renk x AO, 128x128
fs.mkdirSync(path.join(OUT, "tex"), { recursive: true });
execFileSync("python3", ["-c", `
from PIL import Image, ImageChops
import sys
c=Image.open(sys.argv[1]).convert('RGB'); a=Image.open(sys.argv[2]).convert('RGB')
ImageChops.multiply(c,a).resize((128,128),Image.LANCZOS).save(sys.argv[3],optimize=True)
`, colorPng, aoPng, path.join(OUT, "tex/Coin_base.png")]);

const jsonPath = path.join(OUT, "models.json");
const models = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
models.coin = { pos, uv, idx, tex: "models/tex/Coin_base.png" };
fs.writeFileSync(jsonPath, JSON.stringify(models));
const ext = [0, 1, 2].map((a) => { const v = pos.filter((_, i) => i % 3 === a); return [Math.min(...v), Math.max(...v)].map(r4); });
console.log("para: köşe", pos.length / 3, "üçgen", idx.length / 3, "ext", JSON.stringify(ext));
