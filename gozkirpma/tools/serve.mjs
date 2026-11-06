// Bağımlılıksız yerel sunucu: assets/ klasörünü sunar. Kullanım: node tools/serve.mjs [port]
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), "../src/main/assets");
const PORT = Number(process.argv[2] || 5151);
const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg" };

export function serve(port = PORT) {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p;
      try { p = decodeURIComponent(new URL(req.url, "http://x").pathname); } catch { res.writeHead(400); return res.end(); }
      const abs = path.join(ROOT, p === "/" ? "index.html" : p);
      if (!abs.startsWith(ROOT)) { res.writeHead(403); return res.end(); }
      fs.readFile(abs, (err, buf) => {
        if (err) { res.writeHead(404); return res.end("yok"); }
        res.writeHead(200, { "Content-Type": MIME[path.extname(abs)] || "application/octet-stream", "Cache-Control": "no-cache" });
        res.end(buf);
      });
    }).listen(port, () => resolve(srv));
  });
}
if (process.argv[1].endsWith("serve.mjs")) serve().then(() => console.log(`http://localhost:${PORT}`));
