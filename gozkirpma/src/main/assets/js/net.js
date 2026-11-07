// Lobi sunucusuna bağlantı (WebSocket). Sunucu: server/server.mjs. Mesajlar JSON.
// Çevrimdışıyken (sunucu yokken) oyun tek başına çalışmaya devam eder; bu dosya yalnızca lobi için kullanılır.

// "192.168.1.5:8080" -> "ws://192.168.1.5:8080"; "https://x.com" -> "wss://x.com"
export function normalizeUrl(u) {
  u = (u || "").trim();
  if (!u) return "";
  if (/^https:\/\//i.test(u)) return "wss://" + u.slice(8);
  if (/^http:\/\//i.test(u)) return "ws://" + u.slice(7);
  if (!/^wss?:\/\//i.test(u)) return "ws://" + u;
  return u;
}

// h: { onWelcome(m), onSnap(m), onDeny(m), onStart(m), onErr(text), onClose() }
// Döner: Promise<{ send(obj), close(), id, name }>; bağlanamazsa reddeder.
export function connectLobby(url, name, h, { timeout = 6000, WS = globalThis.WebSocket } = {}) {
  return new Promise((resolve, reject) => {
    let ws, done = false, welcomed = false;
    const fail = (msg) => { if (done) return; done = true; try { ws && ws.close(); } catch { /* yoksay */ } reject(new Error(msg)); };
    const timer = setTimeout(() => fail("Sunucu yanıt vermedi."), timeout);
    try { ws = new WS(url); } catch (e) { clearTimeout(timer); return reject(new Error("Geçersiz sunucu adresi.")); }
    const api = { id: null, name, send: (o) => { if (ws.readyState === 1) ws.send(JSON.stringify(o)); }, close: () => { try { ws.close(); } catch { /* yoksay */ } }, get open() { return ws.readyState === 1; } };
    ws.onopen = () => ws.send(JSON.stringify({ t: "hello", name }));
    ws.onerror = () => fail("Sunucuya bağlanılamadı.");
    ws.onclose = () => { clearTimeout(timer); if (!welcomed) fail("Sunucu bağlantıyı kapattı."); else if (h.onClose) h.onClose(); };
    ws.onmessage = (e) => {
      let m; try { m = JSON.parse(e.data); } catch { return; }
      if (m.t === "welcome") { welcomed = true; done = true; clearTimeout(timer); api.id = m.id; api.name = m.name; if (h.onWelcome) h.onWelcome(m); resolve(api); }
      else if (m.t === "err") { if (!welcomed) fail(m.msg); else if (h.onErr) h.onErr(m.msg); }
      else if (m.t === "snap") { if (h.onSnap) h.onSnap(m); }
      else if (m.t === "deny") { if (h.onDeny) h.onDeny(m); }
      else if (m.t === "start") { if (h.onStart) h.onStart(m); }
    };
  });
}
