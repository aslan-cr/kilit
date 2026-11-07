// Karanlık Bataklık lobi sunucusu. Bağımlılık yok.   Kullanım:  node server/server.mjs [port]
// Oyuncular lobide dolaşır; 4 odadan birine (kabine) girer; oda başına en fazla 10 kişi. Odaya girilince 50 sn sayaç başlar, bitince oyun otomatik başlar. Mantık js/rooms.js'te.
import http from "node:http";
import { fileURLToPath } from "node:url";
import { attachWebSocket } from "./ws.mjs";
import { RULES } from "../src/main/assets/js/rules.js";
import { createHub, hubJoin, hubLeave, hubMove, hubTick, hubBack, hubView } from "../src/main/assets/js/rooms.js";

export function createServer({ port = 8080, rules = RULES, log = () => {}, sendHz = 10 } = {}) {   // sayaç: rules.lobby.countdown
  const hub = createHub(rules);
  const conns = new Map();                                        // id -> ws
  let nextId = 1;
  const send = (ws, o) => ws.send(JSON.stringify(o));

  const httpServer = http.createServer((req, res) => {
    if (req.url === "/health") { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ ok: true, players: hub.players.size })); return; }
    res.writeHead(426, { "Content-Type": "text/plain; charset=utf-8" }); res.end("Karanlık Bataklık lobi sunucusu: WebSocket ile bağlanın.");
  });

  attachWebSocket(httpServer, (ws) => {
    let id = null, lastPos = 0, msgs = 0, winStart = Date.now();
    ws.onmessage = (raw) => {
      const now = Date.now();
      if (now - winStart > 1000) { winStart = now; msgs = 0; }
      if (++msgs > 60) { ws.close(); return; }                    // saniyede 60'tan fazla mesaj = kötüye kullanım
      let m; try { m = JSON.parse(raw); } catch { return; }
      if (!m || typeof m !== "object") return;
      if (id === null) {
        if (m.t !== "hello") return;
        const r = hubJoin(hub, nextId, m.name);
        if (!r.ok) { send(ws, { t: "err", msg: r.error }); ws.close(); return; }
        id = nextId++; conns.set(id, ws);
        send(ws, { t: "welcome", id, name: r.name, x: r.x, y: r.y, max: rules.lobby.maxPerRoom });
        log(`+ ${r.name} (${hub.players.size})`);
        return;
      }
      if (m.t === "pos") {
        if (now - lastPos < 40) return;                           // en çok ~25 Hz
        lastPos = now;
        const r = hubMove(hub, id, m);
        if (r.deny) send(ws, { t: "deny", ...r.deny });
      } else if (m.t === "back") hubBack(hub, id);
    };
    ws.onclose = () => { if (id !== null) { const p = hub.players.get(id); hubLeave(hub, id); conns.delete(id); log(`- ${p ? p.name : id} (${hub.players.size})`); } };
  });

  let lastTick = Date.now();
  const timer = setInterval(() => {
    const now = Date.now(), dt = (now - lastTick) / 1000; lastTick = now;
    for (const st of hubTick(hub, dt)) {                       // sayacı biten odalar otomatik başlar
      for (const mid of st.members) { const c = conns.get(mid); if (c) send(c, { t: "start", room: st.room, seed: st.seed }); }
      log(`oda ${st.room + 1} başladı (${st.members.length} kişi)`);
    }
    if (!conns.size) return;
    const view = JSON.stringify({ t: "snap", ...hubView(hub) });
    for (const ws of conns.values()) ws.send(view);
  }, 1000 / sendHz);

  return {
    hub, httpServer,
    listen: () => new Promise((res) => httpServer.listen(port, () => res(httpServer.address().port))),
    close: () => { clearInterval(timer); for (const ws of conns.values()) ws.close(); httpServer.close(); },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const port = Number(process.argv[2] || process.env.PORT || 8080);
  createServer({ port, log: (s) => console.log(new Date().toISOString().slice(11, 19), s) }).listen().then((p) => console.log(`Lobi sunucusu hazır: ws://0.0.0.0:${p}  (sağlık: http://localhost:${p}/health)`));
}
