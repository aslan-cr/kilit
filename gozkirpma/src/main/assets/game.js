// Göz Kırpma Kurbağası
// Kamera + MediaPipe Face Landmarker ile göz kırpmayı algılar, kurbağa aynı anda kırpar.

const WASM_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm";
const MODULE_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm";
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task";

const GAME_SECONDS = 60;
const CLOSE_AT = 0.32; // bu değerin üstü: göz kapalı (düşük = daha hassas)
const OPEN_AT = 0.18;  // bu değerin altı: göz açık (histerezis)
const TONGUE_OUT_AT = 0.22; // dil çıkarma: bu değerin üstü dil dışarıda
const TONGUE_IN_AT = 0.1;  // bu değerin altı dil içeride

const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const video = document.getElementById("cam");
const startBtn = document.getElementById("start");
const keyBtn = document.getElementById("keyboard");
const statusEl = document.getElementById("status");
const scoreEl = document.getElementById("score");
const timeEl = document.getElementById("time");
const bestEl = document.getElementById("best");

const W = canvas.width;
const H = canvas.height;
const FROG = { x: W / 2, y: H - 110 };

// ---------- Durum ----------
const state = {
  running: false,
  score: 0,
  timeLeft: GAME_SECONDS,
  best: Number(safeGet("gk_best") || 0),
  // Hedef (kameradan gelen) göz kapanma değerleri: 0 açık, 1 kapalı
  target: { left: 0, right: 0, tongue: 0 },
  // Ekrandaki göz kapağı (yumuşatılmış)
  lid: { left: 0, right: 0 },
  closed: { left: false, right: false },
  wasBothClosed: false,
  tongueIsOut: false, // kullanıcı dilini çıkarmış mı
  tongue: null, // {t, tx, ty, fly}
  tongueCooldown: 0,
  flies: [],
  particles: [],
  mode: "idle", // idle | camera | keyboard
  keys: { space: false, z: false, x: false, c: false },
};
bestEl.textContent = state.best;

function safeGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function safeSet(k, v) { try { localStorage.setItem(k, v); } catch { /* yoksay */ } }
function setStatus(t) { statusEl.textContent = t; }

// ---------- Kamera + yüz izleme ----------
let landmarker = null;

async function loadLandmarker() {
  const { FaceLandmarker, FilesetResolver } = await import(MODULE_URL);
  const fileset = await FilesetResolver.forVisionTasks(WASM_URL);
  const opts = (delegate) => ({
    baseOptions: { modelAssetPath: MODEL_URL, delegate },
    runningMode: "VIDEO",
    numFaces: 1,
    outputFaceBlendshapes: true,
  });
  try {
    return await FaceLandmarker.createFromOptions(fileset, opts("GPU"));
  } catch {
    return await FaceLandmarker.createFromOptions(fileset, opts("CPU"));
  }
}

async function startCamera() {
  startBtn.disabled = true;
  setStatus("Yüz modeli yükleniyor…");
  try {
    landmarker = await loadLandmarker();
    setStatus("Kamera izni bekleniyor…");
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { width: 640, height: 480, frameRate: { ideal: 60, min: 30 }, facingMode: "user" },
      audio: false,
    });
    video.srcObject = stream;
    await video.play();
    video.style.display = "block";
    state.mode = "camera";
    setStatus("Kameraya bak ve göz kırp! 🐸");
    startGame();
  } catch (err) {
    console.error(err);
    startBtn.disabled = false;
    setStatus("Kamera açılamadı: " + (err && err.message ? err.message : err) + " — klavye modunu deneyebilirsin.");
  }
}

let lastVideoTime = -1;
function readCamera() {
  if (!landmarker || video.readyState < 2) return;
  if (video.currentTime === lastVideoTime) return;
  lastVideoTime = video.currentTime;
  const res = landmarker.detectForVideo(video, performance.now());
  const shapes = res.faceBlendshapes && res.faceBlendshapes[0];
  if (!shapes) {
    setStatus("Yüzün görünmüyor, kameraya dön 🙂");
    return;
  }
  let l = 0, r = 0, tg = 0;
  for (const c of shapes.categories) {
    if (c.categoryName === "eyeBlinkLeft") l = c.score;
    else if (c.categoryName === "eyeBlinkRight") r = c.score;
    else if (c.categoryName === "tongueOut") tg = c.score;
  }
  // Ayna görüntüsünde kişinin sol gözü ekranın solunda görünür.
  state.target.left = l;
  state.target.right = r;
  state.target.tongue = tg;
}

function readKeyboard() {
  const both = state.keys.space;
  state.target.left = both || state.keys.z ? 1 : 0;
  state.target.right = both || state.keys.x ? 1 : 0;
  state.target.tongue = state.keys.c ? 1 : 0;
}

addEventListener("keydown", (e) => setKey(e, true));
addEventListener("keyup", (e) => setKey(e, false));
function setKey(e, down) {
  if (e.code === "Space") { state.keys.space = down; e.preventDefault(); }
  else if (e.code === "KeyZ") state.keys.z = down;
  else if (e.code === "KeyX") state.keys.x = down;
  else if (e.code === "KeyC") state.keys.c = down;
}

// ---------- Oyun mantığı ----------
function startGame() {
  state.running = true;
  state.score = 0;
  state.timeLeft = GAME_SECONDS;
  state.flies = [];
  state.tongue = null;
  scoreEl.textContent = 0;
  for (let i = 0; i < 5; i++) spawnFly();
}

function endGame() {
  state.running = false;
  if (state.score > state.best) {
    state.best = state.score;
    safeSet("gk_best", String(state.best));
    bestEl.textContent = state.best;
  }
  setStatus(`Süre bitti! Skorun: ${state.score}. Tekrar oynamak için butona bas.`);
  startBtn.disabled = false;
  startBtn.textContent = "Tekrar oyna";
}

function spawnFly() {
  state.flies.push({
    x: 60 + Math.random() * (W - 120),
    y: 60 + Math.random() * (H - 280),
    ox: Math.random() * 1000,
    oy: Math.random() * 1000,
    sp: 0.6 + Math.random() * 0.9,
  });
}

function updateBlink(dt) {
  // Göz kapağını hedefe yumuşakça yaklaştır
  for (const k of ["left", "right"]) {
    const goal = Math.min(1, state.target[k] * 1.8);
    const speed = goal > state.lid[k] ? 60 : 30;
    state.lid[k] += (goal - state.lid[k]) * Math.min(1, speed * dt);
    if (!state.closed[k] && state.target[k] > CLOSE_AT) state.closed[k] = true;
    else if (state.closed[k] && state.target[k] < OPEN_AT) state.closed[k] = false;
  }
  const both = state.closed.left && state.closed.right;
  if (both && !state.wasBothClosed && state.running && state.tongueCooldown <= 0) {
    fireTongue();
  }
  state.wasBothClosed = both;

  // Dil çıkarma: dil dışarı çıktığı an kurbağa da dilini fırlatır
  if (!state.tongueIsOut && state.target.tongue > TONGUE_OUT_AT) {
    state.tongueIsOut = true;
    if (state.running && state.tongueCooldown <= 0) fireTongue();
  } else if (state.tongueIsOut && state.target.tongue < TONGUE_IN_AT) {
    state.tongueIsOut = false;
  }

  state.tongueCooldown -= dt;
}

function fireTongue() {
  const mouth = { x: FROG.x, y: FROG.y + 18 };
  let best = null, bd = Infinity;
  for (const f of state.flies) {
    const d = Math.hypot(f.x - mouth.x, f.y - mouth.y);
    if (d < bd) { bd = d; best = f; }
  }
  state.tongue = best
    ? { t: 0, tx: best.x, ty: best.y, fly: best }
    : { t: 0, tx: mouth.x, ty: mouth.y - 160, fly: null };
  state.tongueCooldown = 0.45;
}

function updateTongue(dt) {
  const t = state.tongue;
  if (!t) return;
  const prev = t.t;
  t.t += dt / 0.4;
  if (prev < 0.5 && t.t >= 0.5 && t.fly) {
    const i = state.flies.indexOf(t.fly);
    if (i >= 0) {
      state.flies.splice(i, 1);
      state.score++;
      scoreEl.textContent = state.score;
      burst(t.tx, t.ty);
      spawnFly();
      if (Math.random() < 0.3) spawnFly();
    }
  }
  if (t.t >= 1) state.tongue = null;
}

function burst(x, y) {
  for (let i = 0; i < 14; i++) {
    const a = Math.random() * Math.PI * 2;
    const s = 60 + Math.random() * 140;
    state.particles.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.6 });
  }
}

function updateWorld(dt, time) {
  for (const f of state.flies) {
    f.x += Math.sin(time * f.sp + f.ox) * 45 * dt;
    f.y += Math.cos(time * f.sp * 1.3 + f.oy) * 35 * dt;
    f.x = Math.max(30, Math.min(W - 30, f.x));
    f.y = Math.max(40, Math.min(H - 230, f.y));
  }
  for (const p of state.particles) {
    p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
  }
  state.particles = state.particles.filter((p) => p.life > 0);
}

// ---------- Çizim ----------
function drawBackground() {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, "#27472f");
  g.addColorStop(1, "#16281c");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
  // Nilüfer yaprağı
  ctx.fillStyle = "#2f7a45";
  ctx.beginPath();
  ctx.ellipse(FROG.x, FROG.y + 70, 190, 46, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#256a3a";
  ctx.beginPath();
  ctx.ellipse(FROG.x, FROG.y + 76, 170, 34, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawFly(f, time) {
  ctx.save();
  ctx.translate(f.x, f.y);
  ctx.fillStyle = "rgba(220,240,255,.7)";
  const w = Math.sin(time * 60 + f.ox) * 3;
  ctx.beginPath(); ctx.ellipse(-6, -6, 7, 3 + w * .3, -.5, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(6, -6, 7, 3 + w * .3, .5, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = "#111";
  ctx.beginPath(); ctx.ellipse(0, 0, 5, 7, 0, 0, Math.PI * 2); ctx.fill();
  ctx.restore();
}

function drawEye(cx, cy, lid) {
  const R = 40;
  // Beyaz
  ctx.fillStyle = "#fff";
  ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.fill();
  // Göz bebeği
  ctx.fillStyle = "#111";
  ctx.beginPath(); ctx.arc(cx, cy + 4, 17, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.beginPath(); ctx.arc(cx - 6, cy - 3, 5, 0, Math.PI * 2); ctx.fill();
  // Göz kapağı (yukarıdan aşağı iner)
  const cover = Math.max(0, Math.min(1, lid));
  ctx.save();
  ctx.beginPath(); ctx.arc(cx, cy, R + 2, 0, Math.PI * 2); ctx.clip();
  ctx.fillStyle = "#3fae5a";
  ctx.fillRect(cx - R - 4, cy - R - 4, R * 2 + 8, (R * 2 + 8) * cover);
  if (cover > 0.05) {
    ctx.strokeStyle = "#1f6b35";
    ctx.lineWidth = 3;
    const ly = cy - R - 4 + (R * 2 + 8) * cover;
    ctx.beginPath(); ctx.moveTo(cx - R, ly); ctx.lineTo(cx + R, ly); ctx.stroke();
  }
  ctx.restore();
  // Dış çizgi
  ctx.strokeStyle = "#1f6b35";
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.stroke();
}

function drawTongue() {
  const t = state.tongue;
  if (!t) return;
  const mx = FROG.x, my = FROG.y + 20;
  const p = t.t < 0.5 ? t.t / 0.5 : (1 - t.t) / 0.5;
  const ex = mx + (t.tx - mx) * p;
  const ey = my + (t.ty - my) * p;
  ctx.strokeStyle = "#ff6f91";
  ctx.lineWidth = 12;
  ctx.lineCap = "round";
  ctx.beginPath(); ctx.moveTo(mx, my); ctx.lineTo(ex, ey); ctx.stroke();
  ctx.fillStyle = "#ff4d79";
  ctx.beginPath(); ctx.arc(ex, ey, 11, 0, Math.PI * 2); ctx.fill();
  if (t.fly && t.t >= 0.5) {
    // yakalanan sinek dilin ucunda
  }
}

function drawFrog() {
  const { x, y } = FROG;
  // Gövde
  ctx.fillStyle = "#4cc46a";
  ctx.beginPath(); ctx.ellipse(x, y + 20, 110, 80, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = "#c9f2d3";
  ctx.beginPath(); ctx.ellipse(x, y + 50, 70, 40, 0, 0, Math.PI * 2); ctx.fill();
  // Ön ayaklar
  ctx.fillStyle = "#3fae5a";
  ctx.beginPath(); ctx.ellipse(x - 80, y + 88, 38, 16, -.2, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(x + 80, y + 88, 38, 16, .2, 0, Math.PI * 2); ctx.fill();
  // Gözler (kamera: sol göz -> ekranın solu)
  drawEye(x - 55, y - 48, state.lid.left);
  drawEye(x + 55, y - 48, state.lid.right);
  // Ağız
  ctx.strokeStyle = "#1f6b35";
  ctx.lineWidth = 5;
  ctx.lineCap = "round";
  ctx.beginPath(); ctx.arc(x, y + 6, 44, 0.15 * Math.PI, 0.85 * Math.PI); ctx.stroke();
  // Yanaklar
  ctx.fillStyle = "rgba(255,120,150,.35)";
  ctx.beginPath(); ctx.arc(x - 78, y + 12, 12, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(x + 78, y + 12, 12, 0, Math.PI * 2); ctx.fill();
}

function drawOverlay() {
  if (state.running) return;
  ctx.fillStyle = "rgba(0,0,0,.45)";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "#fff";
  ctx.textAlign = "center";
  ctx.font = "700 30px system-ui, sans-serif";
  ctx.fillText(state.mode === "idle" ? "Başlamak için butona bas" : "Oyun bitti", W / 2, 110);
  ctx.font = "20px system-ui, sans-serif";
  ctx.fillText("Göz kırp veya dil çıkar → kurbağa sinek yakalar", W / 2, 150);
}

// ---------- Döngü ----------
let last = performance.now();
let acc = 0;
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  const time = now / 1000;

  if (state.mode === "camera") readCamera();
  else if (state.mode === "keyboard") readKeyboard();
  else readKeyboard(); // boştayken de klavye ile kurbağaya bakılabilir

  updateBlink(dt);
  if (state.running) {
    acc += dt;
    if (acc >= 1) {
      const whole = Math.floor(acc);
      acc -= whole;
      state.timeLeft = Math.max(0, state.timeLeft - whole);
      timeEl.textContent = state.timeLeft;
      if (state.timeLeft === 0) endGame();
    }
    updateTongue(dt);
    updateWorld(dt, time);
  }

  drawBackground();
  for (const f of state.flies) drawFly(f, time);
  drawTongue();
  drawFrog();
  for (const p of state.particles) {
    ctx.fillStyle = `rgba(255,230,120,${Math.max(0, p.life / 0.6)})`;
    ctx.beginPath(); ctx.arc(p.x, p.y, 3, 0, Math.PI * 2); ctx.fill();
  }
  drawOverlay();
  requestAnimationFrame(frame);
}

// ---------- Butonlar ----------
startBtn.addEventListener("click", () => {
  if (state.mode === "camera") { acc = 0; startGame(); startBtn.disabled = true; setStatus("Göz kırp! 🐸"); }
  else startCamera();
});
keyBtn.addEventListener("click", () => {
  state.mode = "keyboard";
  acc = 0;
  startGame();
  setStatus("Klavye modu: Boşluk = göz kırp, Z = sol göz, X = sağ göz.");
});

requestAnimationFrame(frame);
