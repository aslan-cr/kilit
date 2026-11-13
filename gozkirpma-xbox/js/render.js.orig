// Yazılım çizici: ışın izlemeli labirent (duvar/zemin/tavan) + KayKit/PSX 3D modelleri için üçgen rasterizer.
// Hiçbir dış kütüphane gerekmez (internetsiz WebView'da çalışır). Sim durumunu (g) okur, hiçbir şeyi değiştirmez.
import { RULES } from "./rules.js";
import { rayWall } from "./sim.js";

// Yönlü (huzme) ışık için konik çarpan: ışığın önünde 1, yan tarafta 0 (karekök yok)
function coneF(L, dx, dy, d2) {
  const dp = dx * L.dx + dy * L.dy;
  if (dp <= 0) return 0;
  const cc = (dp * dp) / (d2 + 1e-6), f = (cc - L.c0) / (1 - L.c0);
  return f <= 0 ? 0 : f >= 1 ? 1 : f * f * (3 - 2 * f);
}
const FOV_K = 0.66;
const NEAR = 0.1;
const AMB = 0.018;
const TINT = [1.0, 0.95, 0.72];

// ---------- Modeller ----------
export async function loadModels(base = "models/") {
  const json = await (await fetch(base + "models.json")).json();
  const prep = (m, name) => {
    m.name = name;
    for (const p of m.parts) {
      p.P = Float32Array.from(p.pos);
      p.I = Uint32Array.from(p.idx);
      p.arm = /Arm(Left|Right)/i.test(p.name) ? (/Left/i.test(p.name) ? 1 : -1) : 0;
      p.hat = /Hat/i.test(p.name);
      p.UV = p.uv ? Float32Array.from(p.uv) : null;       // dokulu karakter (Hazmat)
      p.side = /L$/.test(p.name) ? 1 : -1;
    }
    return m;
  };
  const M = { props: {}, chars: {}, guns: {}, flash: {} };
  for (const [k, m] of Object.entries(json.props)) M.props[k] = prep(m, k);
  for (const [k, m] of Object.entries(json.chars)) {
    M.chars[k] = prep(m, k);
    if (m.tex) M.chars[k].texData = await loadTex(base.replace(/models\/$/, "") + m.tex);
  }
  for (const [k, m] of Object.entries(json.guns)) {
    M.guns[k] = { name: k, P: Float32Array.from(m.pos), UV: Float32Array.from(m.uv), I: Uint32Array.from(m.idx), tex: await loadTex(base.replace(/models\/$/, "") + m.tex) };
  }
  for (const [k, m] of Object.entries(json.flash || {})) {
    M.flash[k] = { name: k, P: Float32Array.from(m.pos), UV: Float32Array.from(m.uv), I: Uint32Array.from(m.idx), tex: await loadTex(base.replace(/models\/$/, "") + m.tex) };
  }
  if (json.coin) M.coin = { P: Float32Array.from(json.coin.pos), UV: Float32Array.from(json.coin.uv), I: Uint32Array.from(json.coin.idx), tex: await loadTex(base.replace(/models\/$/, "") + json.coin.tex) };
  prepArms(M);
  return M;
}
// Hazmat kollarını birinci şahıs eli olarak hazırla: eldiven merkezi (bilek ucu) ve omuza giden eksen
function prepArms(M) {
  const h = M.chars.hazmat;
  if (!h) return;
  M.arms = { tex: h.texData };
  for (const part of h.parts) {
    if (part.name !== "armL" && part.name !== "armR") continue;
    const P = part.P, n = P.length / 3;
    let ymin = Infinity, ymax = -Infinity;
    for (let i = 0; i < n; i++) { ymin = Math.min(ymin, P[i * 3 + 1]); ymax = Math.max(ymax, P[i * 3 + 1]); }
    const avg = (pred) => { const c = [0, 0, 0]; let k = 0; for (let i = 0; i < n; i++) if (pred(P[i * 3 + 1])) { c[0] += P[i * 3]; c[1] += P[i * 3 + 1]; c[2] += P[i * 3 + 2]; k++; } return c.map((x) => x / (k || 1)); };
    const hand = avg((y) => y < ymin + 0.16), sh = avg((y) => y > ymax - 0.2);
    const A = [sh[0] - hand[0], sh[1] - hand[1], sh[2] - hand[2]], L = Math.hypot(...A);
    M.arms[part.name] = { part, hand, A: A.map((x) => x / L) };
  }
}
function loadTex(url) {
  return new Promise((res) => {
    const im = new Image();
    im.onload = () => {
      const c = document.createElement("canvas"); c.width = im.width; c.height = im.height;
      const x = c.getContext("2d"); x.drawImage(im, 0, 0);
      res({ w: im.width, h: im.height, d: x.getImageData(0, 0, im.width, im.height).data });
    };
    im.onerror = () => res({ w: 1, h: 1, d: new Uint8ClampedArray([120, 90, 70, 255]) });
    im.src = url;
  });
}

// Işık yayan malzemeler: 0..1 (1 = tam parlak)
function emissive(mat, modelName) {
  if (/yellow|flame/i.test(mat.n)) return 1;
  if (/jack/i.test(modelName) && /orange/i.test(mat.n)) return 0.55;
  return 0;
}

// ---------- Dokular (procedural) ----------
function hash(x, y) { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); }
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function makeTex(kind) {
  const T = new Uint8Array(64 * 64 * 3);
  for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
    const n = vnoise(x * 0.35, y * 0.35) * 0.6 + vnoise(x * 0.9, y * 0.9) * 0.4;
    const moss = vnoise(x * 0.12 + 7, y * 0.12 + 3);
    let r, g, b;
    if (kind === 0) { // taş duvar + yosun
      const row = (y / 16) | 0, bx = (x + (row % 2 ? 16 : 0)) % 32, by = y % 16;
      const mortar = by < 2 || bx < 2;
      const base = mortar ? 38 : 88 + n * 60;
      r = base * 0.88; g = base * 0.96; b = base * 0.82;
      if (moss > 0.52) { const k = Math.min(1, (moss - 0.52) * 4); r = r * (1 - k) + 40 * k * (0.6 + n * 0.6); g = g * (1 - k) + 100 * k * (0.6 + n * 0.6); b = b * (1 - k) + 36 * k * (0.6 + n * 0.6); }
    } else if (kind === 1) { // ıslak çamur
      const base = 55 + n * 55; r = base * 0.8; g = base * 0.78; b = base * 0.55;
      if (moss > 0.5) { r *= 0.6; g *= 1.1; b *= 0.6; }
    } else { const base = 35 + n * 40; r = base * 0.8; g = base * 0.9; b = base; }
    const i = (y * 64 + x) * 3; T[i] = r; T[i + 1] = g; T[i + 2] = b;
  }
  return T;
}
const TEX_WALL = makeTex(0), TEX_FLOOR = makeTex(1), TEX_CEIL = makeTex(2);
const noise = new Float32Array(4096).map(() => Math.random());

function px32(r, g, b) {
  r = r < 0 ? 0 : r > 255 ? 255 : r | 0; g = g < 0 ? 0 : g > 255 ? 255 : g | 0; b = b < 0 ? 0 : b > 255 ? 255 : b | 0;
  return (255 << 24) | (b << 16) | (g << 8) | r;
}

// ---------- Çizici ----------
export class Renderer {
  constructor(canvas, models, opts = {}) {
    this.fixed = opts.size || null;                      // [w, h]: pencereden bağımsız sabit çözünürlük
    this.canvas = canvas; this.ctx = canvas.getContext("2d");
    this.M = models; this.frameNo = 0;
    this.flick = 1; this.amb = AMB;
    this.resize();
  }

  resize() {
    const w = window.innerWidth || 800, h = window.innerHeight || 450;
    if (this.fixed) {
      const RW = (this.RW = this.fixed[0]), RH = (this.RH = this.fixed[1]);
      this.SC = RW / (2 * FOV_K); this.canvas.width = RW; this.canvas.height = RH;
      this.img = this.ctx.createImageData(RW, RH); this.buf32 = new Uint32Array(this.img.data.buffer);
      this.zbuf = new Float32Array(RW); this.dbuf = new Float32Array(RW * RH); this.vig = new Float32Array(RW * RH).fill(1);
      return;
    }
    const q = this.quality || 1;                      // yavaş cihazda ana.js kaliteyi düşürür
    const RW = (this.RW = Math.max(150, Math.min(400, Math.round((w / 2.2) * q))));
    const RH = (this.RH = Math.max(90, Math.min(340, Math.round((RW * h) / w))));
    this.SC = RW / (2 * FOV_K);
    this.canvas.width = RW; this.canvas.height = RH;
    this.img = this.ctx.createImageData(RW, RH);
    this.buf32 = new Uint32Array(this.img.data.buffer);
    this.zbuf = new Float32Array(RW);
    this.dbuf = new Float32Array(RW * RH);
    this.vig = new Float32Array(RW * RH);
    for (let y = 0; y < RH; y++) for (let x = 0; x < RW; x++) {
      const nx = (x / RW - 0.5) * 2, ny = (y / RH - 0.5) * 2, r = (nx * nx + ny * ny) / 2;
      this.vig[y * RW + x] = Math.max(0.1, 1 - 0.95 * Math.pow(r, 0.95));
    }
  }

  light(d) { const A = this.amb; return A + (1 - A) * this.flick / (1 + 0.85 * d * d); }

  // ----- Ana kare -----
  render(g, fx) {
    this.frameNo++;
    const R = g.rules, ctx = this.ctx, RW = this.RW, RH = this.RH;
    this.flick = fx.flick;
    if (fx.lid >= 0.97) { ctx.fillStyle = "#070000"; ctx.fillRect(0, 0, RW, RH); return; }
    const cam = { x: g.px, y: g.py, yaw: g.yaw, eye: R.player.eyeHeight, bob: g.bob, time: fx.time };
    this.world(g, cam, fx);
    if (g.state === "play") this.drawGun(g, fx);
    ctx.putImageData(this.img, 0, 0);
    this.post(g, fx);
  }

  // Yakalanma sahnesi (≈3 sn): 1) karanlıkta yaklaşan parlak gözler 2) göz kapakları aniden açılır, canavarın suratı
  // 3) saldırı: büyür, titrer, ekran bozulur, strobe 4) kan kırmızısı sızar, ani kararma
  noiseOverlay(alpha) {
    const ctx = this.ctx, RW = this.RW, RH = this.RH;
    if (!this._nz) { this._nz = document.createElement("canvas"); this._nz.width = 96; this._nz.height = 54; this._nzI = this._nz.getContext("2d").createImageData(96, 54); }
    const d = this._nzI.data;
    for (let i = 0; i < d.length; i += 4) { const v = (Math.random() * 255) | 0; d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = 255; }
    this._nz.getContext("2d").putImageData(this._nzI, 0, 0);
    ctx.save(); ctx.imageSmoothingEnabled = false; ctx.globalAlpha = alpha; ctx.drawImage(this._nz, 0, 0, RW, RH); ctx.restore();
  }

  eyeGlow(cx, cy, spread, r, a) {
    const ctx = this.ctx;
    for (const sx of [-1, 1]) {
      const x = cx + sx * spread, gr = ctx.createRadialGradient(x, cy, 0, x, cy, r);
      gr.addColorStop(0, `rgba(255,250,150,${Math.min(1, a).toFixed(3)})`); gr.addColorStop(0.25, `rgba(255,220,40,${(a * 0.8).toFixed(3)})`); gr.addColorStop(1, "rgba(255,120,0,0)");
      ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(x, cy, r, 0, Math.PI * 2); ctx.fill();
    }
  }

  renderScare(g, fx) {
    const ctx = this.ctx, RW = this.RW, RH = this.RH, t = fx.scareT, total = g.rules.scare.seconds;
    const killer = g.enemies[g.killer], T_OPEN = 0.55;
    // 1) Göz kapalı karanlık: iki parlak göz yaklaşır
    if (!killer || t < T_OPEN) {
      ctx.fillStyle = "#030000"; ctx.fillRect(0, 0, RW, RH);
      const k = t / T_OPEN, flick = Math.random() < 0.15 ? 0.3 : 1;
      this.eyeGlow(RW / 2, RH * 0.46, RW * (0.03 + 0.08 * k * k), RW * (0.012 + 0.05 * k * k), (0.2 + 0.8 * k) * flick);
      this.noiseOverlay(0.06 + 0.1 * k);
      return;
    }
    const u = t - T_OPEN;
    // 2) Beyaz parlama: göz kapakları açılır
    if (u < 0.07) { ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, RW, RH); return; }
    // 3) Saldırı
    const k = Math.min(1, u / 0.8), ease = k * k;
    const ang = Math.atan2(killer.y - g.py, killer.x - g.px);
    const room = Math.max(0.45, rayWall(g, g.px, g.py, Math.cos(ang), Math.sin(ang), 3) - 0.2);   // duvarın içine girmesin
    const dist = Math.min(room, 1.0 - 0.32 * ease);
    const twitch = u > 0.8 ? (Math.random() - 0.5) : 0;
    const T = g.rules.enemies.types[killer.type];
    const rules2 = { ...g.rules, enemies: { ...g.rules.enemies, types: { ...g.rules.enemies.types, [killer.type]: { ...T, scale: T.scale * (1 + 0.35 * ease) } } } };
    const e2 = { ...killer, alive: true, x: g.px + Math.cos(ang) * dist, y: g.py + Math.sin(ang) * dist, yaw: ang + Math.PI + twitch * 0.5, hit: 0.35 + 0.35 * Math.sin(u * 50), walk: u * 14 };
    const g2 = { ...g, rules: rules2, enemies: [e2], bob: 0, danger: 0, dry: 0 };
    const shake = (0.02 + 0.07 * ease) * (u < 1.5 ? 1 : Math.max(0.2, 1 - (u - 1.5)));
    const cam = { x: g.px + (Math.random() - 0.5) * shake, y: g.py + (Math.random() - 0.5) * shake, yaw: ang + (Math.random() - 0.5) * shake * 2.2, eye: g.rules.player.eyeHeight + (Math.random() - 0.5) * shake * 0.6, bob: 0, time: fx.time };
    this.flick = 0.8 + Math.random() * 0.6;
    this.world(g2, cam, { ...fx, flick: this.flick });
    ctx.putImageData(this.img, 0, 0);
    // Parlayan gözler
    const unit = this.SC / dist;
    this.eyeGlow(RW / 2, RH / 2 - unit * 0.05, unit * 0.07, unit * (0.05 + 0.04 * ease), 0.55 + 0.35 * Math.random());
    // Görüntü bozulması: kayan şeritler
    const slices = 2 + Math.floor(6 * ease);
    for (let i = 0; i < slices; i++) {
      const sy = Math.random() * RH, h = 3 + Math.random() * RH * 0.1, off = (Math.random() - 0.5) * RW * 0.2 * (0.3 + ease);
      ctx.drawImage(this.canvas, 0, sy, RW, h, off, sy, RW, h);
    }
    // Strobe: negatif kareler
    if (u < 1.5 && Math.floor(u * 16) % 3 === 0) { ctx.save(); ctx.globalCompositeOperation = "difference"; ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, RW, RH); ctx.restore(); }
    // Kan kırmızısı kenar (zamanla içeri sızar) + çatlak damarlar
    const bl = Math.min(1, 0.45 + u * 0.35);
    const gr = ctx.createRadialGradient(RW / 2, RH / 2, RH * (0.5 - 0.3 * Math.min(1, u / 1.6)), RW / 2, RH / 2, RH * 0.95);
    gr.addColorStop(0, "rgba(140,0,0,0)"); gr.addColorStop(1, `rgba(110,0,0,${bl.toFixed(3)})`);
    ctx.fillStyle = gr; ctx.fillRect(0, 0, RW, RH);
    if (u > 0.5) {
      ctx.strokeStyle = "rgba(150,0,0,.8)"; ctx.lineWidth = Math.max(1, RW / 260);
      for (let i = 0; i < 7; i++) {
        let x = Math.random() < 0.5 ? 0 : RW, y = Math.random() * RH;
        ctx.beginPath(); ctx.moveTo(x, y);
        const dir = x === 0 ? 1 : -1, len = 3 + Math.floor(Math.min(6, (u - 0.5) * 6));
        for (let j = 0; j < len; j++) { x += dir * (RW * 0.04 + Math.random() * RW * 0.05); y += (Math.random() - 0.5) * RH * 0.18; ctx.lineTo(x, y); }
        ctx.stroke();
      }
    }
    this.noiseOverlay(0.08 + 0.08 * ease);
    // 4) Son: ani kararma (son 0.6 sn), sonra tam siyah
    const left = total - t;
    if (left < 0.6) { ctx.fillStyle = `rgba(0,0,0,${Math.min(1, 1 - left / 0.6).toFixed(3)})`; ctx.fillRect(0, 0, RW, RH); }
  }

  setCam(cam) {
    this.cam = cam;
    cam.dirX = Math.cos(cam.yaw); cam.dirY = Math.sin(cam.yaw);
    cam.plX = -cam.dirY * FOV_K; cam.plY = cam.dirX * FOV_K;
    cam.horizon = this.RH / 2 + Math.sin(cam.bob || 0) * 1.6 * (this.RH / 220);
  }

  // En yakın birkaç ışık kaynağı (jack-o'-lantern, mum, lamba)
  nearLights(g, cam) {
    const arr = [];
    const F = g.rules.flashlight, fl = [];
    if (g.lightOn) {                                          // el feneri: yönlü huzme + yumuşak hale
      const dng = g.danger || 0, jitter = dng > 0.3 && Math.random() < dng * 0.25 ? 0.25 : 1;   // tehlikede titrer
      fl.push({ x: cam.x, y: cam.y, r: F.range, k: F.k * jitter, c: F.color, cone: true, dx: cam.dirX, dy: cam.dirY, c0: F.coneCos * F.coneCos });
      fl.push({ x: cam.x, y: cam.y, r: F.haloR, k: F.haloK * jitter, c: F.color });
    }
    for (const l of g.lights) {
      const d2 = (l.x - cam.x) ** 2 + (l.y - cam.y) ** 2;
      if (d2 < (l.r + 7) ** 2) arr.push({ l, d2 });
    }
    arr.sort((a, b) => a.d2 - b.d2);
    return fl.concat(arr.slice(0, 4 - (fl.length ? 2 : 0)).map((a) => a.l));
  }

  world(g, cam, fx, noEnv = false) {
    this.setCam(cam);
    const RW = this.RW, RH = this.RH, buf32 = this.buf32, vig = this.vig, SC = this.SC;
    const { dirX, dirY, plX, plY, horizon } = cam;
    const S = g.S, map = g.map;
    const noiseOff = (this.frameNo * 977) & 4095;
    this.dbuf.fill(Infinity);
    const lights = noEnv ? [] : this.nearLights(g, cam);
    const NL = lights.length;
    this.lightsNow = lights;

    if (noEnv) {
      buf32.fill(0xff000000);
      this.zbuf.fill(Infinity);
    } else {
      // Zemin ve tavan
      const ambFill = px32(AMB * 150, AMB * 190, AMB * 170);
      for (let y = 0; y < RH; y++) {
        const isFloor = y > horizon;
        const dy = isFloor ? y - horizon : horizon - y;
        if (dy < 0.5) { for (let x = 0; x < RW; x++) buf32[y * RW + x] = 0xff000000; continue; }
        const rowDist = ((isFloor ? cam.eye : 1 - cam.eye) * SC) / dy;
        const sh = this.light(rowDist);
        if (sh < AMB * 1.25 && !NL) { const base = y * RW; for (let x = 0; x < RW; x++) buf32[base + x] = ambFill; continue; }
        const tex = isFloor ? TEX_FLOOR : TEX_CEIL;
        const mul = isFloor ? 1.0 : 0.7;
        let fx2 = cam.x + rowDist * (dirX - plX), fy2 = cam.y + rowDist * (dirY - plY);
        const sx = (rowDist * 2 * plX) / RW, sy = (rowDist * 2 * plY) / RW;
        const base = y * RW;
        for (let x = 0; x < RW; x++) {
          const tx = ((fx2 - Math.floor(fx2)) * 64) | 0, ty = ((fy2 - Math.floor(fy2)) * 64) | 0;
          const ti = (ty * 64 + tx) * 3;
          let lr = sh * TINT[0], lg = sh * TINT[1], lb = sh * TINT[2];
          for (let k = 0; k < NL; k++) {
            const L = lights[k], ddx = fx2 - L.x, ddy = fy2 - L.y, d2 = ddx * ddx + ddy * ddy, q = 1 - d2 / (L.r * L.r);
            if (q > 0) { let a = q * q * L.k * this.flick; if (L.cone) a *= coneF(L, ddx, ddy, d2); lr += a * L.c[0]; lg += a * L.c[1]; lb += a * L.c[2]; }
          }
          const m = mul * vig[base + x] * (0.92 + noise[(base + x + noiseOff) & 4095] * 0.16);
          buf32[base + x] = px32(tex[ti] * lr * m, tex[ti + 1] * lg * m, tex[ti + 2] * lb * m);
          fx2 += sx; fy2 += sy;
        }
      }

      // Duvarlar
      for (let x = 0; x < RW; x++) {
        const camX = (2 * x) / RW - 1;
        const rdx = dirX + plX * camX, rdy = dirY + plY * camX;
        let mx = cam.x | 0, my = cam.y | 0;
        const ddx = rdx === 0 ? 1e30 : Math.abs(1 / rdx), ddy = rdy === 0 ? 1e30 : Math.abs(1 / rdy);
        let stepX, stepY, sdx, sdy;
        if (rdx < 0) { stepX = -1; sdx = (cam.x - mx) * ddx; } else { stepX = 1; sdx = (mx + 1 - cam.x) * ddx; }
        if (rdy < 0) { stepY = -1; sdy = (cam.y - my) * ddy; } else { stepY = 1; sdy = (my + 1 - cam.y) * ddy; }
        let side = 0;
        for (let i = 0; i < 64; i++) {
          if (sdx < sdy) { sdx += ddx; mx += stepX; side = 0; } else { sdy += ddy; my += stepY; side = 1; }
          if (mx < 0 || my < 0 || mx >= S || my >= S || map[my * S + mx]) break;
        }
        let perp = side === 0 ? sdx - ddx : sdy - ddy;
        if (perp < 0.05) perp = 0.05;
        this.zbuf[x] = perp;
        let wallX = side === 0 ? cam.y + perp * rdy : cam.x + perp * rdx;
        wallX -= Math.floor(wallX);
        let texX = (wallX * 64) | 0;
        if ((side === 0 && rdx > 0) || (side === 1 && rdy < 0)) texX = 63 - texX;
        const lineH = SC / perp;
        const topF = horizon - (1 - cam.eye) * lineH;
        const y0 = Math.max(0, topF | 0), y1 = Math.min(RH - 1, (horizon + cam.eye * lineH) | 0);
        const sh = this.light(perp) * (side ? 0.78 : 1);
        let lr = sh * TINT[0], lg = sh * TINT[1], lb = sh * TINT[2];
        if (NL) {
          const hx = cam.x + perp * rdx, hy = cam.y + perp * rdy;
          for (let k = 0; k < NL; k++) {
            const L = lights[k], ddx2 = hx - L.x, ddy2 = hy - L.y, d22 = ddx2 * ddx2 + ddy2 * ddy2, q = 1 - d22 / (L.r * L.r);
            if (q > 0) { let a = q * q * L.k * this.flick; if (L.cone) a *= coneF(L, ddx2, ddy2, d22); lr += a * L.c[0]; lg += a * L.c[1]; lb += a * L.c[2]; }
          }
        }
        const stepT = 64 / lineH;
        let tyF = (y0 - topF) * stepT;
        for (let y = y0; y <= y1; y++) {
          const ti = ((tyF & 63) * 64 + texX) * 3;
          tyF += stepT;
          const idx = y * RW + x;
          const m = vig[idx] * (0.92 + noise[(idx + noiseOff) & 4095] * 0.16);
          buf32[idx] = px32(TEX_WALL[ti] * lr * m, TEX_WALL[ti + 1] * lg * m, TEX_WALL[ti + 2] * lb * m);
        }
      }
    }

    // Modeller
    if (!noEnv) this.drawProps(g);
    this.drawItems(g, cam, fx);
    this.labels = [];
    this.drawEnemies(g, cam, fx);
    this.drawPlayers(g, cam);
    this.drawSigns(g, cam);
    if (!noEnv) this.drawGlows(g, cam, fx);
  }

  // ----- Dönüşüm + çizim yardımcıları -----
  // Parça köşelerini sahneye yerleştirir: ölçek s, yaw, konum, (kol için pivot etrafında dönüş)
  placePart(p, s, yaw, ox, oy, oh, rot, out) {
    const P = p.P, n = P.length;
    const cy = Math.cos(yaw), sy = Math.sin(yaw);
    let c = 1, sn = 0, pvy = 0, pvz = 0;
    if (rot) { c = Math.cos(rot); sn = Math.sin(rot); pvy = p.pivot[1]; pvz = p.pivot[2]; }
    for (let k = 0; k < n; k += 3) {
      const mx = P[k]; let my = P[k + 1], mz = P[k + 2];
      if (rot) { const y = my - pvy, z = mz - pvz; my = pvy + y * c - z * sn; mz = pvz + y * sn + z * c; }
      out[k] = ox + (mz * cy - mx * sy) * s;
      out[k + 1] = oy + (mz * sy + mx * cy) * s;
      out[k + 2] = oh + my * s;
    }
  }

  // Dünya koordinatlı (x,y,h) köşeleri görüntü uzayına çevirip çizer.
  drawWorldMesh(W, I, colorFn, cam, opts = {}) {
    const n = W.length / 3;
    this.ensure(n);
    const V = this._V, SX = this._SX, SY = this._SY, RW = this.RW, SC = this.SC, hor = cam.horizon;
    const { x: cx0, y: cy0, dirX, dirY } = cam;
    for (let k = 0, j = 0; k < W.length; k += 3, j++) {
      const rx = W[k] - cx0, ry = W[k + 1] - cy0, h = W[k + 2] - cam.eye;
      const d = rx * dirX + ry * dirY, l = -rx * dirY + ry * dirX;
      V[k] = l; V[k + 1] = h; V[k + 2] = d;
      if (d > NEAR) { const id = SC / d; SX[j] = RW / 2 + l * id; SY[j] = hor - h * id; }
    }
    this.rasterize(V, SX, SY, I, colorFn, opts);
  }

  // Kamera uzayında hazır köşeler (l,v,d): ele tutulan silah ve ölüm sahnesi için
  drawViewMesh(V, I, colorFn, opts = {}) {
    const n = V.length / 3;
    this.ensure(n);
    const SX = this._SX, SY = this._SY, RW = this.RW, SC = this.SC, hor = this.RH / 2;
    for (let k = 0, j = 0; k < V.length; k += 3, j++) {
      const d = V[k + 2];
      if (d > NEAR) { const id = SC / d; SX[j] = RW / 2 + V[k] * id; SY[j] = hor - V[k + 1] * id; }
    }
    this.rasterize(V, SX, SY, I, colorFn, opts);
  }

  ensure(n) {
    if (!this._V || this._V.length < n * 3) { this._V = new Float32Array(n * 3 + 3000); this._SX = new Float32Array(n + 1000); this._SY = new Float32Array(n + 1000); }
  }

  rasterize(V, SX, SY, I, colorFn, opts) {
    const RH = this.RH, RW = this.RW, uv = opts.uv;
    const rec = (i) => [V[i*3], V[i*3+1], V[i*3+2], SX[i], SY[i], uv ? uv[i*2] : 0, uv ? uv[i*2+1] : 0];
    for (let t = 0, ti = 0; t < I.length; t += 3, ti++) {
      const a = I[t], b = I[t + 1], c = I[t + 2];
      const da = V[a*3+2], db = V[b*3+2], dc = V[c*3+2];
      if (da <= NEAR && db <= NEAR && dc <= NEAR) continue;
      if (da > NEAR && db > NEAR && dc > NEAR) {
        const xa = SX[a], xb = SX[b], xc = SX[c];
        if ((xa < 0 && xb < 0 && xc < 0) || (xa >= RW && xb >= RW && xc >= RW)) continue;
        const ya = SY[a], yb = SY[b], yc = SY[c];
        if ((ya < 0 && yb < 0 && yc < 0) || (ya >= RH && yb >= RH && yc >= RH)) continue;
        const area = (xb - xa) * (yc - ya) - (xc - xa) * (yb - ya);
        if (area * area < 0.25) continue;
        this.fillTri(rec(a), rec(b), rec(c), ti, colorFn, opts);
      } else {
        const poly = [rec(a), rec(b), rec(c)], out = [];
        for (let i = 0; i < 3; i++) {
          const p = poly[i], q = poly[(i + 1) % 3], pin = p[2] > NEAR, qin = q[2] > NEAR;
          if (pin) out.push(p);
          if (pin !== qin) {
            const k = (NEAR - p[2]) / (q[2] - p[2]);
            const l = p[0] + (q[0] - p[0]) * k, v = p[1] + (q[1] - p[1]) * k, id = this.SC / NEAR;
            out.push([l, v, NEAR, RW / 2 + l * id, (opts.gun || opts.view ? RH / 2 : this.cam.horizon) - v * id, p[5] + (q[5] - p[5]) * k, p[6] + (q[6] - p[6]) * k]);
          }
        }
        for (let i = 1; i + 1 < out.length; i++) this.fillTri(out[0], out[i], out[i + 1], ti, colorFn, opts);
      }
    }
  }

  fillTri(A, B, C, ti, colorFn, opts) {
    const RW = this.RW, RH = this.RH;
    const xa = A[3], ya = A[4], xb = B[3], yb = B[4], xc = C[3], yc = C[4];
    const area = (xb - xa) * (yc - ya) - (xc - xa) * (yb - ya);
    if (area === 0) return;
    const da = A[2], db = B[2], dc = C[2];
    const e1l = B[0] - A[0], e1v = B[1] - A[1], e1d = db - da;
    const e2l = C[0] - A[0], e2v = C[1] - A[1], e2d = dc - da;
    const nl = e1v * e2d - e1d * e2v, nv = e1d * e2l - e1l * e2d, nd = e1l * e2v - e1v * e2l;
    const nlen = Math.hypot(nl, nv, nd) || 1;
    const ml = (A[0] + B[0] + C[0]) / 3, mv = (A[1] + B[1] + C[1]) / 3, md = (da + db + dc) / 3;
    const mlen = Math.hypot(ml, mv, md) || 1;
    const facing = Math.abs(nl * ml + nv * mv + nd * md) / (nlen * mlen);
    const col = colorFn(ti, md, facing);
    const minX = Math.max(0, Math.floor(Math.min(xa, xb, xc))), maxX = Math.min(RW - 1, Math.ceil(Math.max(xa, xb, xc)));
    const minY = Math.max(0, Math.floor(Math.min(ya, yb, yc))), maxY = Math.min(RH - 1, Math.ceil(Math.max(ya, yb, yc)));
    const ia = 1 / da, ib = 1 / db, ic = 1 / dc, inv = 1 / area;
    const buf32 = this.buf32, dbuf = this.dbuf, zbuf = this.zbuf, vig = this.vig;
    const noiseOff = (this.frameNo * 977) & 4095;
    const ignoreWall = !!(opts.gun || opts.view);
    const tex = opts.tex;
    const r0 = col[0], g0 = col[1], b0 = col[2];
    for (let y = minY; y <= maxY; y++) {
      const py = y + 0.5;
      for (let x = minX; x <= maxX; x++) {
        const px = x + 0.5;
        const w0 = ((xb - px) * (yc - py) - (xc - px) * (yb - py)) * inv;
        const w1 = ((xc - px) * (ya - py) - (xa - px) * (yc - py)) * inv;
        const w2 = 1 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        const iz = w0 * ia + w1 * ib + w2 * ic;
        const d = 1 / iz;
        const idx = y * RW + x;
        if (d >= dbuf[idx]) continue;
        if (!ignoreWall && d >= zbuf[x]) continue;
        let r = r0, g = g0, b = b0;
        if (tex) {
          const u = (w0 * A[5] * ia + w1 * B[5] * ia * 0 + w2 * C[5] * ic) * 0; // (aşağıda doğru hesap)
          const uu = (w0 * A[5] * ia + w1 * B[5] * ib + w2 * C[5] * ic) * d, vv = (w0 * A[6] * ia + w1 * B[6] * ib + w2 * C[6] * ic) * d;
          const fu = uu - Math.floor(uu), fv = 1 - vv - Math.floor(1 - vv);
          const tx = (fu * tex.w) | 0, ty = (fv * tex.h) | 0;
          const k = (Math.min(ty, tex.h - 1) * tex.w + Math.min(tx, tex.w - 1)) * 4;
          r = tex.d[k] * r0; g = tex.d[k + 1] * g0; b = tex.d[k + 2] * b0;
        }
        const m = vig[idx] * (0.92 + noise[(idx + noiseOff) & 4095] * 0.16);
        dbuf[idx] = d;
        buf32[idx] = px32(r * m, g * m, b * m);
      }
    }
  }

  // ----- Renk fonksiyonları -----
  // Malzeme renkleri (0-255), ışık: yüz dönüklüğü + el feneri + yakın ışıklar
  matColor(model, mats, objL, tintRed = 0, dimK = 1) {
    const { amb } = this;
    return (matIdx) => {
      const m = mats[matIdx], e = emissive(m, model);
      return (ti, d, facing) => {
        const lit = (this.light(d) - amb) * (0.3 + 0.7 * facing) * dimK + amb;
        let r = m.c[0] * (lit * TINT[0] + objL[0]), g = m.c[1] * (lit * TINT[1] + objL[1]), b = m.c[2] * (lit * TINT[2] + objL[2]);
        if (e) { const k = 0.55 + 0.45 * this.flick; r = r * (1 - e) + m.c[0] * k * e * 1.15; g = g * (1 - e) + m.c[1] * k * e * 1.15; b = b * (1 - e) + m.c[2] * k * e * 1.15; }
        if (tintRed) { r = r * (1 - tintRed) + 255 * tintRed; g *= 1 - tintRed; b *= 1 - tintRed; }
        return [r, g, b];
      };
    };
  }

  objLight(x, y, exceptSelf) {
    let r = 0, g = 0, b = 0;
    for (const L of this.lightsNow) {
      const dx = x - L.x, dy = y - L.y, q = 1 - (dx * dx + dy * dy) / (L.r * L.r);
      if (q > 0 && (dx * dx + dy * dy) > exceptSelf) { let a = q * q * L.k * this.flick; if (L.cone) a *= coneF(L, dx, dy, dx * dx + dy * dy); r += a * L.c[0]; g += a * L.c[1]; b += a * L.c[2]; }
    }
    return [r, g, b];
  }

  // Bir modeli (parçalarıyla) çiz. anim: parça başına dönüş fonksiyonu
  drawModel(model, s, yaw, ox, oy, oh, g, anim, tintRed) {
    const cam = this.cam;
    const rx = ox - cam.x, ry = oy - cam.y, dd = rx * cam.dirX + ry * cam.dirY;
    if (dd < -1.2 || dd > 9.5) return;
    const objL = this.objLight(ox, oy, 0.12);
    const colorOf = this.matColor(model.name, model.mats, objL, tintRed || 0);
    for (const p of model.parts) {
      if (!p._W || p._W.length < p.P.length) p._W = new Float32Array(p.P.length);
      this.placePart(p, s, yaw, ox, oy, oh, anim ? anim(p) : 0, p._W);
      if (model.texData && p.UV) {
        const amb = this.amb, k = this.flick;
        this.drawWorldMesh(p._W, p.I, (ti, d, facing) => {
          const lit = (this.light(d) - amb) * (0.35 + 0.65 * facing) + amb;
          return [lit * TINT[0] + objL[0], lit * TINT[1] + objL[1], lit * TINT[2] + objL[2]];
        }, cam, { tex: model.texData, uv: p.UV });
      } else this.drawWorldMesh(p._W, p.I, colorOf(p.mat), cam);
    }
  }

  drawProps(g) {
    const sc = g.rules.props.scale, cam = this.cam;
    for (const p of g.props) {
      const model = this.M.props[p.kind];
      if (!model) continue;
      const rx = p.x - cam.x, ry = p.y - cam.y, dd = rx * cam.dirX + ry * cam.dirY;
      if (dd < -1.2 || dd > 9.5) continue;
      this.drawModel(model, sc[p.kind] || 0.25, p.yaw, p.x, p.y, 0, g, null, 0);
    }
  }

  // Diğer oyuncular (çok oyunculu için): Hazmat karakteri, yürürken kol ve bacak sallar, üstünde isim etiketi
  // Sabit yazılar (lobi odalarının tabelaları): g.signs = [{x,y,z,text,c}]
  drawSigns(g, cam) {
    if (!g.signs) return;
    for (const sg of g.signs) {
      if (!sg.text) continue;
      const rx = sg.x - cam.x, ry = sg.y - cam.y, d = rx * cam.dirX + ry * cam.dirY, l = -rx * cam.dirY + ry * cam.dirX;
      if (d < 0.3 || d > 14) continue;
      const col = Math.max(0, Math.min(this.RW - 1, Math.round(this.RW / 2 + (l / d) * this.SC)));
      if (d > this.zbuf[col] + 0.25) continue;
      this.labels.push({ t: sg.text, c: sg.c, big: 1, x: this.RW / 2 + (l / d) * this.SC, y: cam.horizon - ((sg.z - cam.eye) / d) * this.SC, d });
    }
  }

  drawPlayers(g, cam) {
    const P = g.players;
    if (!P || !P.length) return;
    const model = this.M.chars[g.rules.player.model], sc = g.rules.player.scale;
    if (!model) return;
    for (const pl of P) {
      const sw = Math.sin((pl.walk || 0) * 1.2) * 0.6 * Math.min(1, pl.moving ?? 1);
      this.drawModel(model, sc, pl.yaw || 0, pl.x, pl.y, Math.abs(sw) * 0.02, g,
        (p) => (p.swing === 1 ? -sw * p.side * 0.9 : p.swing === 2 ? sw * p.side : 0), 0);
      if (pl.name) {
        const rx = pl.x - cam.x, ry = pl.y - cam.y, d = rx * cam.dirX + ry * cam.dirY, l = -rx * cam.dirY + ry * cam.dirX;
        if (d > 0.3 && d < 9 && d < (this.zbuf[Math.max(0, Math.min(this.RW - 1, Math.round(this.RW / 2 + (l / d) * this.SC)))] + 0.2)) (this.labels = this.labels || []).push({ t: pl.name, x: this.RW / 2 + (l / d) * this.SC, y: cam.horizon - ((model.bb.max[1] * sc + 0.06 - cam.eye) / d) * this.SC, d });
      }
    }
  }

  // Menü/giriş ekranındaki dönen avatar önizlemesi (ayrı küçük canvas, sabit çözünürlük)
  renderAvatar(time) {
    const R = this.rulesRef || RULES, RW = this.RW, RH = this.RH;
    const g = { rules: R, map: new Uint8Array(100), S: 10, props: [], enemies: [], flies: [], boxes: [], gunItems: [], lights: [], players: [{ x: 0.5, y: 0, yaw: time * 0.9 + 2.4, walk: time * 5, moving: 0.0 }], px: 0, py: 0, yaw: 0, bob: 0, moving: 0 };
    this.flick = 2.2;
    this.world(g, { x: 0, y: 0, yaw: 0, eye: 0.34, bob: 0, time }, { time, flick: 2.2, puffs: [] }, true);
    this.ctx.putImageData(this.img, 0, 0);
  }

  drawEnemies(g, cam, fx) {
    const types = g.rules.enemies.types;
    for (const e of g.enemies) {
      if (!e.alive) continue;
      const model = this.M.chars[e.type];
      if (!model) continue;
      const d = Math.hypot(e.x - g.px, e.y - g.py);
      const reach = 1.15 + 0.35 * Math.max(0, 1 - d / 3);
      const sway = Math.sin(e.walk * 1.4) * 0.5;
      const bob = Math.abs(Math.sin(e.walk * 1.4)) * 0.025;
      this.drawModel(model, types[e.type].scale, e.yaw, e.x, e.y, bob, g,
        (p) => (p.arm ? -(reach + sway * p.arm) : 0), e.hit * 0.6);
    }
  }

  // ----- Parlayan sprite'lar (ışık böceği, mermi, gözler, vuruş patlamaları) -----
  glow(x, y, h, size, rgb, alpha) {
    const cam = this.cam, RW = this.RW, RH = this.RH, SC = this.SC;
    const rx = x - cam.x, ry = y - cam.y;
    const d = rx * cam.dirX + ry * cam.dirY, l = -rx * cam.dirY + ry * cam.dirX;
    if (d < 0.15 || d > 12) return;
    const sx = RW / 2 + (l / d) * SC, sy = cam.horizon - ((h - cam.eye) / d) * SC;
    const half = Math.max(1, (size * SC) / d / 2) | 0;
    const x0 = Math.max(0, (sx - half) | 0), x1 = Math.min(RW - 1, (sx + half) | 0);
    const y0 = Math.max(0, (sy - half) | 0), y1 = Math.min(RH - 1, (sy + half) | 0);
    const buf32 = this.buf32, dbuf = this.dbuf, zbuf = this.zbuf;
    for (let x2 = x0; x2 <= x1; x2++) {
      if (d >= zbuf[x2]) continue;
      for (let y2 = y0; y2 <= y1; y2++) {
        const idx = y2 * RW + x2;
        if (d >= dbuf[idx]) continue;
        const u = (x2 - sx) / half, v = (y2 - sy) / half, r2 = u * u + v * v;
        if (r2 > 1) continue;
        const a = Math.exp(-r2 * 5) * alpha;
        const c = buf32[idx];
        buf32[idx] = px32((c & 255) + rgb[0] * a, ((c >> 8) & 255) + rgb[1] * a, ((c >> 16) & 255) + rgb[2] * a);
      }
    }
  }

  drawGlows(g, cam, fx) {
    const t = fx.time;
    for (const o of g.flies) if (!o.taken) this.glow(o.x, o.y, 0.42 - 0.32 + Math.sin(t * 2 + o.ph) * 0.05 + 0.16, 0.2, [190, 255, 110], 1.0);
    for (const o of g.boxes) if (!o.taken) this.glow(o.x, o.y, 0.14, 0.22, [255, 70, 50], 0.55 + 0.2 * Math.sin(t * 3 + o.ph));
    for (const o of g.gunItems) if (!o.taken) this.glow(o.x, o.y, 0.14, 0.34, [255, 230, 170], 0.5 + 0.2 * Math.sin(t * 3 + o.ph));
    for (const L of g.lights) {
      const d2 = (L.x - cam.x) ** 2 + (L.y - cam.y) ** 2;
      if (d2 < 100) this.glow(L.x, L.y, 0.3, 0.25, [L.c[0] * 255, L.c[1] * 255, L.c[2] * 255], 0.35 * this.flick);
    }
    for (const e of g.enemies) {
      if (!e.alive) continue;
      const rx = e.x - cam.x, ry = e.y - cam.y, d = Math.hypot(rx, ry);
      // gözler karanlıkta parlar: oyuncuya doğru bakan iki sarı nokta
      const ex = -ry / (d || 1), ey = rx / (d || 1);
      const a = Math.max(0.15, Math.min(1, 1.5 - d / 10)) * (e.stun > 0 ? 0.5 : 1);
      this.glow(e.x - rx / (d || 1) * 0.1 + ex * 0.045, e.y - ry / (d || 1) * 0.1 + ey * 0.045, 0.40, 0.045, [255, 240, 80], a);
      this.glow(e.x - rx / (d || 1) * 0.1 - ex * 0.045, e.y - ry / (d || 1) * 0.1 - ey * 0.045, 0.40, 0.045, [255, 240, 80], a);
    }
    for (const p of fx.puffs || []) {
      const k = p.t / 0.7;
      for (let i = 0; i < 6; i++) { const a = i * 1.05 + p.seed; this.glow(p.x + Math.cos(a) * k * 0.4, p.y + Math.sin(a) * k * 0.4, 0.3 + k * 0.3, 0.1, [120, 255, 120], 1 - k); }
    }
  }

  // ----- Yerdeki eşyalar: mermi kutusu ve silahlar (3B) -----
  drawItems(g, cam, fx) {
    const t = fx.time;
    for (const o of g.boxes) {
      if (o.taken) continue;
      const rx = o.x - cam.x, ry = o.y - cam.y, dd = rx * cam.dirX + ry * cam.dirY;
      if (dd < -1 || dd > 9) continue;
      const m = this.shellModel();
      this.drawModel(m, 0.30, t * 1.2 + o.ph, o.x, o.y, 0.03 + Math.sin(t * 2 + o.ph) * 0.02, g, null, 0);
    }
    const coin = this.M.coin;
    if (coin && g.coins) for (const o of g.coins) {                    // para: dikey duran disk, kendi ekseninde döner ve hafifçe süzülür
      const rx = o.x - cam.x, ry = o.y - cam.y, dd = rx * cam.dirX + ry * cam.dirY;
      if (dd < -1 || dd > 10) continue;
      if (!coin._W) coin._W = new Float32Array(coin.P.length);
      const yaw = t * 2.6 + o.ph, cy = Math.cos(yaw), sy = Math.sin(yaw), s = g.rules.coins.scale, h0 = 0.3 + Math.sin(t * 2.2 + o.ph) * 0.03;
      for (let k = 0; k < coin.P.length; k += 3) { const mx = coin.P[k], my = coin.P[k+1], mz = coin.P[k+2]; coin._W[k] = o.x + (mx * cy - mz * sy) * s; coin._W[k+1] = o.y + (mx * sy + mz * cy) * s; coin._W[k+2] = h0 + my * s; }
      const objL = this.objLight(o.x, o.y, 0.1);
      const col = (ti, d, facing) => { const l = Math.max(0.75, (this.light(d) - this.amb) * 0.5 + this.amb + objL[0]) * (0.8 + 0.4 * facing); return [l * 1.6, l * 1.5, l * 1.0]; };
      this.drawWorldMesh(coin._W, coin.I, col, cam, { tex: coin.tex, uv: coin.UV });
    }
    for (const o of g.gunItems) {
      if (o.taken) continue;
      const rx = o.x - cam.x, ry = o.y - cam.y, dd = rx * cam.dirX + ry * cam.dirY;
      if (dd < -1 || dd > 9) continue;
      const gun = this.M.guns[g.rules.weapons[o.weapon].model];
      if (!gun) continue;
      if (!gun._W) gun._W = new Float32Array(gun.P.length);
      const yaw = t * 1.1 + o.ph, cy = Math.cos(yaw), sy = Math.sin(yaw), s = 0.85, h0 = 0.22 + Math.sin(t * 2 + o.ph) * 0.03;
      for (let k = 0; k < gun.P.length; k += 3) { const mx = gun.P[k], my = gun.P[k+1] - 0.08, mz = gun.P[k+2]; gun._W[k] = o.x + (mx * cy - mz * sy) * s; gun._W[k+1] = o.y + (mx * sy + mz * cy) * s; gun._W[k+2] = h0 + my * s; }
      const objL = this.objLight(o.x, o.y, 0.1);
      const col = (ti, d, facing) => { const l = Math.max(0.5, ((this.light(d) - this.amb) * (0.4 + 0.6 * facing) + this.amb) + objL[0]) * (0.75 + 0.25 * facing); return [l * 1.5, l * 1.5, l * 1.4]; };
      this.drawWorldMesh(gun._W, gun.I, col, cam, { tex: gun.tex, uv: gun.UV });
    }
  }

  shellModel() {
    if (this._shell) return this._shell;
    // 3 mermi (silindir): kırmızı gövde + pirinç taban
    const P = [], I = [], parts = [];
    const cyl = (cx, cz, r, h0, h1, mat) => {
      const N = 8, base = P.length / 3;
      for (let i = 0; i < N; i++) { const a = (i / N) * Math.PI * 2; P.push(cx + Math.cos(a) * r, h0, cz + Math.sin(a) * r, cx + Math.cos(a) * r, h1, cz + Math.sin(a) * r); }
      const idx = [];
      for (let i = 0; i < N; i++) { const a = base + i * 2, b = base + ((i + 1) % N) * 2; idx.push(a, b, a + 1, b, b + 1, a + 1); }
      const c = P.length / 3; P.push(cx, h1, cz); for (let i = 0; i < N; i++) idx.push(c, base + i * 2 + 1, base + ((i + 1) % N) * 2 + 1);
      return idx;
    };
    const offs = [[-0.22, 0], [0.22, 0], [0, 0.2]];
    const red = [], brass = [];
    for (const [cx, cz] of offs) { red.push(...cyl(cx, cz, 0.13, 0.28, 1.1, 0)); brass.push(...cyl(cx, cz, 0.135, 0, 0.28, 1)); }
    const mk = (idx, mat) => ({ name: "shell", pivot: [0, 0, 0], arm: 0, mat, P: Float32Array.from(P), I: Uint32Array.from(idx) });
    this._shell = { name: "shell", mats: [{ n: "Red", c: [200, 40, 35], d: 1, e: 0 }, { n: "Brass", c: [210, 170, 60], d: 1, e: 0 }], parts: [mk(red, 0), mk(brass, 1)] };
    return this._shell;
  }

  // ----- Elde tutulan silah -----
  // Elde tutulan eşya (silah ya da fener) + onu tutan eller. Geçişte eşya aşağı iner / yukarı kalkar (g.raise 1 -> 0 -> 1).
  drawGun(g, fx) {
    const R = g.rules, light = g.slot === "light";
    const W = R.weapons[g.cur];
    const item = light ? this.M.flash[g.flashModel] : this.M.guns[W.model];
    if (!item) return;
    this.dbuf.fill(Infinity);
    const low = 1 - g.raise;                                   // 0 = elde, 1 = tamamen aşağıda
    const gs = light ? 1 : 0.66, kick = light ? 0 : g.recoil * (0.12 + 0.05 * W.kick);
    const rack = !light && g.cooldown > 0 ? Math.sin(Math.min(1, g.cooldown / W.cooldown) * Math.PI) * 0.05 : 0;
    const walk = g.moving, bobx = Math.sin(g.bob * 0.5) * (light ? 0.016 : 0.012) * walk, boby = Math.abs(Math.sin(g.bob * 0.5)) * (light ? 0.016 : 0.012) * walk;
    const pitch = (light ? 0 : g.recoil * (0.28 + 0.1 * W.kick) + rack * 1.2) - low * 0.55;
    const cp = Math.cos(pitch), sp = Math.sin(pitch);
    const F0 = (light ? 0.72 : 0.74) - kick - low * 0.05, L0 = (light ? 0.2 : 0.15) + bobx + low * 0.1, V0 = (light ? -0.14 : -0.205) + boby - low * 0.62;
    // (f,u,s) takım koordinatı -> görüş uzayı [x, y, derinlik]
    const place = (f, u, s, out, o) => { const fr = f * cp - u * sp, ur = f * sp + u * cp; out[o] = L0 + s - fr * 0.13; out[o + 1] = V0 + ur; out[o + 2] = F0 + fr; };
    const V = new Float32Array(item.P.length);
    let spec;
    if (light) {
      spec = R.flashlight.hold[g.flashModel];
      const sc = spec.scale;
      for (let k = 0; k < item.P.length; k += 3) {            // fener: lens +y -> ileri, sap +z -> YUKARI (sap üstte)
        const x = item.P[k] - spec.grip[0], y = item.P[k + 1] - spec.grip[1], z = item.P[k + 2] - spec.grip[2];
        place((y + spec.at[0]) * sc, (z + spec.at[1]) * sc, x * sc, V, k);
      }
    } else {
      spec = W.hold;
      for (let k = 0; k < item.P.length; k += 3) place(item.P[k] * gs, item.P[k + 1] * gs, item.P[k + 2] * gs, V, k);
    }
    const bright = (light ? 0.9 : 0.72) + (light ? 0 : g.flash * 1.2) + 0.15 * this.flick;
    const col = (ti, d, facing) => { const l = bright * (0.55 + 0.45 * facing); return [l, l, l * 0.95]; };
    this.drawViewMesh(V, item.I, col, { tex: item.tex, uv: item.UV, gun: true });

    // Eller: sağ el kabzayı/feneri sapından tutar, sol el silahın ön tutamağında
    const arms = this.M.arms;
    if (arms) {
      const hands = light ? [["armR", spec.hand, 1]] : [["armR", spec.r, 1], ["armL", spec.l, -1]];
      for (const [name, pt, side] of hands) {
        const arm = arms[name];
        if (!arm || !pt) continue;
        const sa = (light ? spec.handScale : spec.handScale) * (light ? 1 : gs);
        const G = [0, 0, 0], D = [0, 0, 0];
        if (light) place((spec.at[0] + pt[0]) * spec.scale, (spec.at[1] + pt[1]) * spec.scale, pt[2] * spec.scale, G, 0);
        else place(pt[0] * gs, pt[1] * gs, pt[2] * gs, G, 0);
        const back = light ? [-0.35, -0.42, 1.0] : [-1.0, -0.62, 0.34 * side];                // bilekten omuza: geriye, aşağıya, dışa
        const fr = back[0] * cp - back[1] * sp, ur = back[0] * sp + back[1] * cp;
        D[0] = back[2] - fr * 0.13; D[1] = ur; D[2] = fr;
        this.drawArm(arm, arms.tex, G, D, sa, spec.roll || 0, (ti, d, f) => { const c = col(ti, d, f); return [c[0] * 1.45, c[1] * 1.45, c[2] * 1.4]; });
      }
    }
    // Fener merceğinin ekran konumu: 2B parlama için
    this._lens = null;
    if (light && g.lightOn) {
      const t = [0, 0, 0]; place((spec.lensY - spec.grip[1] + spec.at[0]) * spec.scale, (spec.at[1] - spec.grip[2]) * spec.scale, 0, t, 0);
      if (t[2] > NEAR) this._lens = { x: this.RW / 2 + (t[0] * this.SC) / t[2], y: this.RH / 2 - (t[1] * this.SC) / t[2], d: t[2] };
    }
  }

  // Kolu eldiven ucu G'de olacak, omuz yönü D'ye bakacak şekilde görüş uzayına yerleştirip çiz
  drawArm(arm, tex, G, D, scale, roll, col) {
    const part = arm.part, P = part.P, A = arm.A, hand = arm.hand;
    const dl = Math.hypot(D[0], D[1], D[2]) || 1, a = [D[0] / dl, D[1] / dl, D[2] / dl];
    // A -> a döndürme (en kısa yay), sonra a etrafında roll
    let ax = [A[1] * a[2] - A[2] * a[1], A[2] * a[0] - A[0] * a[2], A[0] * a[1] - A[1] * a[0]];
    const sin = Math.hypot(...ax), cos = A[0] * a[0] + A[1] * a[1] + A[2] * a[2];
    if (sin > 1e-6) ax = ax.map((x) => x / sin); else ax = [1, 0, 0];
    const rot = (v) => {                                       // Rodrigues
      const d = ax[0] * v[0] + ax[1] * v[1] + ax[2] * v[2];
      const cr = [ax[1] * v[2] - ax[2] * v[1], ax[2] * v[0] - ax[0] * v[2], ax[0] * v[1] - ax[1] * v[0]];
      return [v[0] * cos + cr[0] * sin + ax[0] * d * (1 - cos), v[1] * cos + cr[1] * sin + ax[1] * d * (1 - cos), v[2] * cos + cr[2] * sin + ax[2] * d * (1 - cos)];
    };
    const cr2 = Math.cos(roll), sr2 = Math.sin(roll);
    const roll2 = (v) => { const d = a[0] * v[0] + a[1] * v[1] + a[2] * v[2], c = [a[1] * v[2] - a[2] * v[1], a[2] * v[0] - a[0] * v[2], a[0] * v[1] - a[1] * v[0]];
      return [v[0] * cr2 + c[0] * sr2 + a[0] * d * (1 - cr2), v[1] * cr2 + c[1] * sr2 + a[1] * d * (1 - cr2), v[2] * cr2 + c[2] * sr2 + a[2] * d * (1 - cr2)]; };
    const V = new Float32Array(P.length);
    for (let k = 0; k < P.length; k += 3) {
      const r = roll2(rot([P[k] - hand[0], P[k + 1] - hand[1], P[k + 2] - hand[2]]));
      V[k] = G[0] + r[0] * scale; V[k + 1] = G[1] + r[1] * scale; V[k + 2] = G[2] + r[2] * scale;
    }
    this.drawViewMesh(V, part.I, col, { tex, uv: part.UV, gun: true });
  }

  // ----- Son işlemler (2B katman) -----
  post(g, fx) {
    const ctx = this.ctx, RW = this.RW, RH = this.RH, R = g.rules;
    if (this.labels && this.labels.length) {            // diğer oyuncuların isimleri
      ctx.save(); ctx.textAlign = "center"; ctx.font = `bold ${Math.max(9, Math.round(RW / 34))}px system-ui, sans-serif`;
      for (const L of this.labels) {
        const a = L.big ? Math.max(0.5, Math.min(1, 1.6 - L.d / 14)) : Math.max(0.25, Math.min(1, 1.4 - L.d / 8));
        if (L.big) ctx.font = `bold ${Math.max(10, Math.round(RW / 26))}px system-ui, sans-serif`;
        ctx.fillStyle = `rgba(0,0,0,${(a * 0.7).toFixed(2)})`; ctx.fillText(L.t, L.x + 1, L.y + 1);
        ctx.fillStyle = `rgba(${L.c || "210,255,220"},${a.toFixed(2)})`; ctx.fillText(L.t, L.x, L.y);
      }
      ctx.restore();
    }
    if (g.state === "play") this.drawGunPost(g, fx);
    if (g.state === "play" && g.slot === "light") this.drawLensGlow(g);
    if (g.danger > 0.05) {
      const gr = ctx.createRadialGradient(RW / 2, RH / 2, RH * 0.25, RW / 2, RH / 2, RH * 0.95);
      gr.addColorStop(0, "rgba(90,0,0,0)"); gr.addColorStop(1, `rgba(90,0,0,${(g.danger * 0.55).toFixed(3)})`);
      ctx.fillStyle = gr; ctx.fillRect(0, 0, RW, RH);
    }
    // Göz kuruluğu: kenarlar kararır, titrer
    const dk = (g.dry - R.eyes.dryWarn) / (R.eyes.dryMax - R.eyes.dryWarn);
    if (dk > 0 && !g.eyesClosed) {
      const a = Math.min(0.92, dk * 0.8 + (Math.random() < 0.08 ? 0.15 : 0));
      const gr = ctx.createRadialGradient(RW / 2, RH / 2, RH * (0.55 - 0.3 * dk), RW / 2, RH / 2, RH * 0.95);
      gr.addColorStop(0, "rgba(10,0,0,0)"); gr.addColorStop(1, `rgba(10,0,0,${a.toFixed(3)})`);
      ctx.fillStyle = gr; ctx.fillRect(0, 0, RW, RH);
    }
    // Göz kapakları
    if (fx.lid > 0.01) {
      const hh = (fx.lid * RH) / 2 + 1;
      ctx.fillStyle = "#050000"; ctx.fillRect(0, 0, RW, hh); ctx.fillRect(0, RH - hh, RW, hh);
      const soft = ctx.createLinearGradient(0, hh, 0, hh + 14); soft.addColorStop(0, "rgba(5,0,0,.9)"); soft.addColorStop(1, "rgba(5,0,0,0)");
      ctx.fillStyle = soft; ctx.fillRect(0, hh, RW, 14);
      const soft2 = ctx.createLinearGradient(0, RH - hh, 0, RH - hh - 14); soft2.addColorStop(0, "rgba(5,0,0,.9)"); soft2.addColorStop(1, "rgba(5,0,0,0)");
      ctx.fillStyle = soft2; ctx.fillRect(0, RH - hh - 14, RW, 14);
    }
    if (fx.hurt > 0) { ctx.fillStyle = `rgba(160,0,0,${(fx.hurt * 0.4).toFixed(3)})`; ctx.fillRect(0, 0, RW, RH); }
  }

  // Silah: 3B çizimden sonra, namlu ateşi parlaması için 2B katman
  // Fener merceği: ışık yanıkken parlama + hafif ışık sütunu (2B, toplamalı)
  drawLensGlow(g) {
    const L = this._lens;
    if (!L) return;
    const ctx = this.ctx, RW = this.RW, RH = this.RH, r = RH * 0.34;
    ctx.save(); ctx.globalCompositeOperation = "lighter";
    const gr = ctx.createRadialGradient(L.x, L.y, 1, L.x, L.y, r);
    gr.addColorStop(0, "rgba(255,244,210,.75)"); gr.addColorStop(0.25, "rgba(255,225,160,.3)"); gr.addColorStop(1, "rgba(255,200,120,0)");
    ctx.fillStyle = gr; ctx.fillRect(L.x - r, L.y - r, r * 2, r * 2);
    ctx.restore();
  }

  drawGunPost(g, fx) {
    if (g.flash > 0.02) {
      const ctx = this.ctx, RW = this.RW, RH = this.RH;
      const gr = ctx.createRadialGradient(RW * 0.56, RH * 0.62, 2, RW * 0.56, RH * 0.62, RH * 0.7);
      gr.addColorStop(0, `rgba(255,220,140,${(g.flash * 0.85).toFixed(3)})`); gr.addColorStop(0.35, `rgba(255,140,40,${(g.flash * 0.4).toFixed(3)})`); gr.addColorStop(1, "rgba(255,100,0,0)");
      ctx.fillStyle = gr; ctx.fillRect(0, 0, RW, RH);
    }
  }
}
