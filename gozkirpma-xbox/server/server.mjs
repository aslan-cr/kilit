// Karanlık Bataklık lobi sunucusu. Bağımlılık yok.   Kullanım:  node server/server.mjs [port]
// İnternetten gelen herkes AYNI lobiye girer; bir lobi en fazla rules.lobby.maxPlayers (20) kişi. 20 dolunca yeni lobi açılır;
// biri çıkıp lobi 20'nin altına inerse sonradan gelenler önce boşluğu olan en küçük numaralı lobiye yerleşir. Boş kalan lobiler (1. hariç) silinir.
// Oyuncular lobide dolaşır; 4 odadan birine (kabine) girer; oda başına en fazla 10 kişi. Odaya girilince 50 sn sayaç başlar, bitince oyun otomatik başlar. Mantık js/rooms.js'te.
import http from "node:http";
import { fileURLToPath } from "node:url";
import { attachWebSocket } from "./ws.mjs";
import { RULES } from "../src/main/assets/js/rules.js";
import { createHub, hubJoin, hubLeave, hubMove, hubTick, hubBack, hubView } from "../src/main/assets/js/rooms.js";

export function createServer({ port = 8080, rules = RULES, log = () => {}, sendHz = 10 } = {}) {   // sayaç: rules.lobby.countdown
  const lobbies = new Map([[1, createHub(rules)]]);              // lobi no -> hub (1'den başlar)
  const total = () => { let n = 0; for (const h of lobbies.values()) n += h.players.size; return n; };
  const conns = new Map();                                        // id -> { ws, no }
  const maxLobbies = rules.lobby.maxLobbies || 50;
  function place() {                                              // boşluğu olan en küçük numaralı lobi; yoksa yeni lobi
    const nos = [...lobbies.keys()].sort((a, b) => a - b);
    for (const no of nos) if (lobbies.get(no).players.size < rules.lobby.maxPlayers) return no;
    if (lobbies.size >= maxLobbies) return null;
    let no = 1; while (lobbies.has(no)) no++;
    lobbies.set(no, createHub(rules)); return no;
  }
  let nextId = 1;
  const send = (ws, o) => ws.send(JSON.stringify(o));

  const httpServer = http.createServer((req, res) => {
    if (req.url === "/health") { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ ok: true, players: total(), lobbies: [...lobbies].map(([no, h]) => ({ no, players: h.players.size })) })); return; }
    res.writeHead(426, { "Content-Type": "text/plain; charset=utf-8" }); res.end("Karanlık Bataklık lobi sunucusu: WebSocket ile bağlanın.");
  });

  attachWebSocket(httpServer, (ws) => {
    let id = null, lobbyNo = 0, lastPos = 0, msgs = 0, winStart = Date.now();
    ws.onmessage = (raw) => {
      const now = Date.now();
      if (now - winStart > 1000) { winStart = now; msgs = 0; }
      if (++msgs > 60) { ws.close(); return; }                    // saniyede 60'tan fazla mesaj = kötüye kullanım
      let m; try { m = JSON.parse(raw); } catch { return; }
      if (!m || typeof m !== "object") return;
      if (id === null) {
        if (m.t !== "hello") return;
        const no = place();
        if (no === null) { send(ws, { t: "err", msg: "Sunucu dolu." }); ws.close(); return; }
        const hub = lobbies.get(no);
        const r = hubJoin(hub, nextId, m.name);
        if (!r.ok) { send(ws, { t: "err", msg: r.error }); ws.close(); return; }
        id = nextId++; lobbyNo = no; conns.set(id, { ws, no });
        send(ws, { t: "welcome", id, name: r.name, x: r.x, y: r.y, max: rules.lobby.maxPerRoom, lobby: no, cap: rules.lobby.maxPlayers });
        log(`+ ${r.name} -> lobi ${no} (${hub.players.size}/${rules.lobby.maxPlayers})`);
        return;
      }
      if (m.t === "pos") {
        if (now - lastPos < 40) return;                           // en çok ~25 Hz
        lastPos = now;
        const r = hubMove(lobbies.get(lobbyNo), id, m);
        if (r.deny) send(ws, { t: "deny", ...r.deny });
      } else if (m.t === "back") hubBack(lobbies.get(lobbyNo), id);
    };
    ws.onclose = () => {
      if (id === null) return;
      const hub = lobbies.get(lobbyNo), p = hub.players.get(id);
      hubLeave(hub, id); conns.delete(id); log(`- ${p ? p.name : id} (lobi ${lobbyNo}: ${hub.players.size})`);
      if (!hub.players.size && lobbyNo !== 1) lobbies.delete(lobbyNo);
    };
  });

  let lastTick = Date.now();
  const timer = setInterval(() => {
    const now = Date.now(), dt = (now - lastTick) / 1000; lastTick = now;
    for (const [no, hub] of lobbies) {
      for (const st of hubTick(hub, dt)) {                     // sayacı biten odalar otomatik başlar
        for (const mid of st.members) { const c = conns.get(mid); if (c) send(c.ws, { t: "start", room: st.room, seed: st.seed }); }
        log(`lobi ${no} oda ${st.room + 1} başladı (${st.members.length} kişi)`);
      }
      if (!hub.players.size) continue;
      const view = JSON.stringify({ t: "snap", lobby: no, ...hubView(hub) });
      for (const [mid] of hub.players) { const c = conns.get(mid); if (c) c.ws.send(view); }
    }
  }, 1000 / sendHz);

  return {
    lobbies, get hub() { return lobbies.get(1); }, httpServer,
    listen: () => new Promise((res) => httpServer.listen(port, () => res(httpServer.address().port))),
    close: () => { clearInterval(timer); for (const c of conns.values()) c.ws.close(); httpServer.close(); },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const port = Number(process.argv[2] || process.env.PORT || 8080);
  createServer({ port, log: (s) => console.log(new Date().toISOString().slice(11, 19), s) }).listen().then((p) => console.log(`Lobi sunucusu hazır: ws://0.0.0.0:${p}  (sağlık: http://localhost:${p}/health)`));
}
