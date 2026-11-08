// Bağımlılıksız minimal WebSocket sunucusu (RFC 6455): yalnızca metin çerçeveleri, ping/pong, kapanış.
import crypto from "node:crypto";

const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const MAX_FRAME = 4096;                       // lobi mesajları küçüktür; büyük çerçeve = saldırı

export function attachWebSocket(httpServer, onConnection) {
  httpServer.on("upgrade", (req, socket) => {
    const key = req.headers["sec-websocket-key"];
    if (!key || (req.headers.upgrade || "").toLowerCase() !== "websocket") { socket.destroy(); return; }
    const accept = crypto.createHash("sha1").update(key + GUID).digest("base64");
    socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
    socket.setNoDelay(true);
    const ws = makeSocket(socket, req);
    onConnection(ws, req);
  });
}

function frame(op, payload) {
  const len = payload.length;
  const head = len < 126 ? Buffer.from([0x80 | op, len]) : Buffer.from([0x80 | op, 126, len >> 8, len & 255]);
  return Buffer.concat([head, payload]);
}

function makeSocket(socket, req) {
  const ws = { onmessage: null, onclose: null, closed: false, ip: req.socket.remoteAddress };
  let buf = Buffer.alloc(0), text = null;
  const close = () => { if (ws.closed) return; ws.closed = true; try { socket.destroy(); } catch { /* yoksay */ } if (ws.onclose) ws.onclose(); };
  ws.send = (s) => { if (!ws.closed && socket.writable) socket.write(frame(1, Buffer.from(s))); };
  ws.close = () => { if (!ws.closed) { try { socket.write(frame(8, Buffer.alloc(0))); } catch { /* yoksay */ } close(); } };
  socket.on("data", (d) => {
    buf = Buffer.concat([buf, d]);
    for (;;) {
      if (buf.length < 2) return;
      const fin = !!(buf[0] & 0x80), op = buf[0] & 15, masked = !!(buf[1] & 0x80);
      let len = buf[1] & 127, off = 2;
      if (!masked) return close();                                     // istemci çerçeveleri maskeli olmak zorunda
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) return close();                            // 64 bit uzunluk: reddet
      if (len > MAX_FRAME) return close();
      if (buf.length < off + 4 + len) return;
      const mask = buf.subarray(off, off + 4), data = Buffer.from(buf.subarray(off + 4, off + 4 + len));
      for (let i = 0; i < len; i++) data[i] ^= mask[i & 3];
      buf = buf.subarray(off + 4 + len);
      if (op === 8) { ws.close(); return; }
      if (op === 9) { socket.write(frame(10, data)); continue; }
      if (op === 10) continue;
      if (op === 1 || op === 0) {
        text = op === 1 ? data : Buffer.concat([text || Buffer.alloc(0), data]);
        if (text.length > MAX_FRAME) return close();
        if (fin) { const s = text.toString("utf8"); text = null; if (ws.onmessage) ws.onmessage(s); }
      }
    }
  });
  socket.on("close", close); socket.on("error", close);
  socket.setTimeout(60000, close);                                     // 60 sn sessizlik = bağlantı kopuk
  return ws;
}
