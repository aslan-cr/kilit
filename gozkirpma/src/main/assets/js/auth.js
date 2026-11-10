// Hesap sistemi: kullanıcı adı + şifre, misafir girişi, hesap başına rekor/istatistik.
//
// ÖNEMLİ SINIR: Hesaplar yalnızca bu cihazda (localStorage) tutulur. Şifre düz metin saklanmaz
// (PBKDF2-SHA256, rastgele tuz, 120 bin tur) ama sunucu olmadığı için hesap başka cihaza taşınmaz ve
// unutulan şifre sıfırlanamaz. Çok oyunculu için gerçek bir sunucu gerekir: `store` arayüzünü
// (get/set) bir sunucu adaptörüyle değiştirmek ve register/login'i oraya yönlendirmek yeterli olacak şekilde yazıldı.

const ITER = 120000;
const LOCK_AFTER = 5, LOCK_SEC = 30;
const NAME_RE = /^[A-Za-z0-9_ğüşıöçĞÜŞİÖÇ]{3,16}$/;

const b64 = (buf) => { let s = ""; for (const b of new Uint8Array(buf)) s += String.fromCharCode(b); return btoa(s); };
const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const keyOf = (name) => name.toLocaleLowerCase("tr");

export function validateUsername(u) {
  if (!NAME_RE.test(u || "")) return "Kullanıcı adı 3-16 karakter olmalı (harf, rakam, _).";
  return "";
}
export function validatePassword(p) {
  if (!p || p.length < 6) return "Şifre en az 6 karakter olmalı.";
  if (p.length > 64) return "Şifre en fazla 64 karakter olabilir.";
  return "";
}

export function memoryStore() {
  const m = new Map();
  return { get: (k) => (m.has(k) ? m.get(k) : null), set: (k, v) => { if (v === null) m.delete(k); else m.set(k, v); } };
}
export function browserStore() {
  try {
    localStorage.setItem("gk_t", "1"); localStorage.removeItem("gk_t");
    return { get: (k) => localStorage.getItem(k), set: (k, v) => (v === null ? localStorage.removeItem(k) : localStorage.setItem(k, v)) };
  } catch { return memoryStore(); }           // özel mod vb.: oturum kapanınca hesaplar kaybolur
}

export function createAuth({ store = browserStore(), crypto = globalThis.crypto, now = () => Date.now(), iter = ITER } = {}) {
  const load = (k, d) => { try { return JSON.parse(store.get(k)) ?? d; } catch { return d; } };
  const save = (k, v) => store.set(k, JSON.stringify(v));

  async function derive(password, salt, iterations) {
    const subtle = crypto && crypto.subtle;
    if (!subtle) throw new Error("Bu tarayıcıda güvenli şifreleme yok (https gerekir).");
    const key = await subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
    return new Uint8Array(await subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256));
  }
  const same = (a, b) => { if (a.length !== b.length) return false; let d = 0; for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i]; return d === 0; };
  const emptyStats = () => ({ games: 0, wins: 0, deaths: 0, kills: 0, best: 0, coins: 0 });

  const api = {
    // { ok, error }
    async register(name, password, password2) {
      name = (name || "").trim();
      let e = validateUsername(name) || validatePassword(password);
      if (!e && password2 !== undefined && password !== password2) e = "Şifreler aynı değil.";
      if (e) return { ok: false, error: e };
      const users = load("gk_users", {}), k = keyOf(name);
      if (users[k]) return { ok: false, error: "Bu kullanıcı adı alınmış." };
      const salt = crypto.getRandomValues(new Uint8Array(16));
      const hash = await derive(password, salt, iter);
      users[k] = { name, salt: b64(salt), hash: b64(hash), iter, created: now(), stats: emptyStats() };
      save("gk_users", users);
      store.set("gk_session", k); store.set("gk_guest", null);
      return { ok: true, user: api.current() };
    },

    async login(name, password) {
      name = (name || "").trim();
      const k = keyOf(name), locks = load("gk_lock", {}), L = locks[k];
      if (L && L.until > now()) return { ok: false, error: `Çok fazla yanlış deneme. ${Math.ceil((L.until - now()) / 1000)} sn bekle.` };
      const users = load("gk_users", {}), u = users[k];
      let ok = false;
      if (u) ok = same(await derive(password || "", unb64(u.salt), u.iter || ITER), unb64(u.hash));
      else await derive(password || "", new Uint8Array(16), iter);     // kullanıcı var mı yok mu zamanlamadan anlaşılmasın
      if (!ok) {
        const n = ((L && L.n) || 0) + 1;
        locks[k] = n >= LOCK_AFTER ? { n: 0, until: now() + LOCK_SEC * 1000 } : { n, until: 0 };
        save("gk_lock", locks);
        return { ok: false, error: "Kullanıcı adı veya şifre yanlış." };
      }
      delete locks[k]; save("gk_lock", locks);
      store.set("gk_session", k); store.set("gk_guest", null);
      return { ok: true, user: api.current() };
    },

    guest() { store.set("gk_session", null); store.set("gk_guest", "1"); return api.current(); },
    logout() { store.set("gk_session", null); store.set("gk_guest", null); },

    // { name, guest } ya da null
    current() {
      const k = store.get("gk_session");
      if (k) { const u = load("gk_users", {})[k]; if (u) return { name: u.name, guest: false }; }
      if (store.get("gk_guest")) return { name: "Misafir", guest: true };
      return null;
    },

    stats() {
      const k = store.get("gk_session");
      if (k) { const u = load("gk_users", {})[k]; if (u) return { ...emptyStats(), ...u.stats }; }
      return { ...emptyStats(), ...load("gk_guest_stats", {}) };
    },

    // Cüzdan: hesapta kalıcı para ve satın alınanlar (silah/fener). Oyun kazanılsa da kaybedilse de toplanan para buraya eklenir.
    wallet() {
      const k = store.get("gk_session"), users = load("gk_users", {});
      const w = k && users[k] ? users[k].wallet : load("gk_guest_wallet", null);
      return { money: 0, guns: [], lights: [], ...(w || {}) };
    },
    saveWallet(w) {
      const k = store.get("gk_session"), users = load("gk_users", {});
      const clean = { money: Math.max(0, Math.floor(w.money || 0)), guns: [...new Set(w.guns || [])], lights: [...new Set(w.lights || [])] };
      if (k && users[k]) { users[k].wallet = clean; save("gk_users", users); } else save("gk_guest_wallet", clean);
      return { ...clean };
    },
    addMoney(n) { const w = api.wallet(); w.money += Math.max(0, Math.floor(n || 0)); return api.saveWallet(w); },

    // Oyun bitince: { win, time (sn), kills, coins (toplanan para) }
    recordGame({ win, time, kills, coins }) {
      const k = store.get("gk_session"), users = load("gk_users", {});
      const target = k && users[k] ? users[k].stats : load("gk_guest_stats", emptyStats());
      Object.assign(target, { ...emptyStats(), ...target });
      target.games++; target.kills += kills || 0; target.coins += coins || 0;
      if (win) { target.wins++; if (!target.best || time < target.best) target.best = Math.round(time); } else target.deaths++;
      if (k && users[k]) { users[k].stats = target; save("gk_users", users); } else save("gk_guest_stats", target);
      return { ...target };
    },
  };
  return api;
}
