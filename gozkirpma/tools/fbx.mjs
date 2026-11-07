// Minimal ikili FBX okuyucu (yalnızca statik mesh: köşeler, çokgenler, UV, model dönüşümleri). Bağımlılıksız.
import fs from "node:fs";
import zlib from "node:zlib";

export function parseFbx(file) {
  const b = fs.readFileSync(file);
  if (b.slice(0, 20).toString() !== "Kaydara FBX Binary  ") throw new Error("ikili FBX değil");
  const ver = b.readUInt32LE(23);
  const big = ver >= 7500;
  let o = 27;
  const u32 = () => { const v = b.readUInt32LE(o); o += 4; return v; };
  const u64 = () => { const v = Number(b.readBigUInt64LE(o)); o += 8; return v; };
  const readProp = () => {
    const t = String.fromCharCode(b[o++]);
    switch (t) {
      case "Y": { const v = b.readInt16LE(o); o += 2; return v; }
      case "C": return b[o++] !== 0;
      case "I": { const v = b.readInt32LE(o); o += 4; return v; }
      case "F": { const v = b.readFloatLE(o); o += 4; return v; }
      case "D": { const v = b.readDoubleLE(o); o += 8; return v; }
      case "L": { const v = Number(b.readBigInt64LE(o)); o += 8; return v; }
      case "S": { const n = u32(); const s = b.slice(o, o + n).toString("latin1"); o += n; return s; }
      case "R": { const n = u32(); const r = b.slice(o, o + n); o += n; return r; }
      case "f": case "d": case "l": case "i": case "b": {
        const len = u32(), enc = u32(), clen = u32();
        let raw = b.slice(o, o + clen); o += clen;
        if (enc === 1) raw = zlib.inflateSync(raw);
        const sz = { f: 4, d: 8, l: 8, i: 4, b: 1 }[t];
        const out = new (t === "f" ? Float32Array : t === "d" ? Float64Array : t === "i" ? Int32Array : t === "l" ? Float64Array : Uint8Array)(len);
        for (let k = 0; k < len; k++) {
          out[k] = t === "f" ? raw.readFloatLE(k * 4) : t === "d" ? raw.readDoubleLE(k * 8) : t === "i" ? raw.readInt32LE(k * 4) : t === "l" ? Number(raw.readBigInt64LE(k * 8)) : raw[k];
        }
        return out;
      }
      default: throw new Error("bilinmeyen özellik türü " + t);
    }
  };
  const readNode = () => {
    const end = big ? u64() : u32(), np = big ? u64() : u32(); big ? u64() : u32();
    const nl = b[o++];
    if (end === 0) return null;
    const name = b.slice(o, o + nl).toString("latin1"); o += nl;
    const props = []; for (let i = 0; i < np; i++) props.push(readProp());
    const children = [];
    while (o < end) { const c = readNode(); if (c) children.push(c); else break; }
    o = end;
    return { name, props, children };
  };
  const nodes = [];
  while (o < b.length - 40) { const n = readNode(); if (!n) break; nodes.push(n); }
  return { version: ver, nodes };
}
export const child = (n, name) => n.children.find((c) => c.name === name);
export const childs = (n, name) => n.children.filter((c) => c.name === name);
