// Göz Kırpma Kurbağası: Karanlık Bataklık
// Birinci şahıs korku oyunu. Kamera + MediaPipe Face Landmarker ile göz kapanmasını algılar.
// Kural: gözlerin AÇIKKEN gölgeler donar, gözünü KAPATTIĞIN an yalnızca onlar hareket eder.
// Dil algılama kaldırıldı. Göz hassasiyeti düşürüldü (CLOSE_AT / OPEN_AT).

const WASM_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm";
const MODULE_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm";
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task";

// ---------- Ayarlar ----------
const CLOSE_AT = 0.5;  // göz kapanma değeri bunun üstüne çıkınca göz kapalı sayılır (eskiden 0.32; yüksek = daha az hassas)
const OPEN_AT = 0.3;   // bunun altına inince göz açık sayılır (eskiden 0.18)
const FLIES_NEEDED = 5;
const ENEMY_COUNT = 3;
const MAZE_CELLS = 10;           // 10x10 hücre -> 21x21 karo
const PLAYER_SPEED = 2.4;        // karo/sn
const PLAYER_RADIUS = 0.2;
const ENEMY_BASE_SPEED = 1.5;    // karo/sn (göz kapalıyken)
const ENEMY_SPEED_PER_FLY = 0.25;
const CATCH_DIST = 0.5;
const LOOK_SENS = 0.0055;        // rad/piksel
const JOY_DEAD = 10;             // piksel
const JOY_FULL = 60;             // bu kadar uzaklıkta tam hız; daha uzağı sınırsız, hız aynı kalır
const FOV_K = 0.66;
const CAM_H = 0.42;              // kurbağa göz hizası (duvar yüksekliği = 1)

// ---------- Sayfa öğeleri ----------
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const video = document.getElementById("cam");
const touchLayer = document.getElementById("touch");
const joyEl = document.getElementById("joy");
const knobEl = document.getElementById("knob");
const hudEl = document.getElementById("hud");
const fliesEl = document.getElementById("flies");
const needEl = document.getElementById("need");
const timeEl = document.getElementById("time");
const eyesEl = document.getElementById("eyes");
const msgEl = document.getElementById("msg");
const eyeBtn = document.getElementById("eyeBtn");
const menuEl = document.getElementById("menu");
const resultEl = document.getElementById("result");
const startBtn = document.getElementById("start");
const keyBtn = document.getElementById("keyboard");
const statusEl = document.getElementById("status");
needEl.textContent = FLIES_NEEDED;

function safeGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function safeSet(k, v) { try { localStorage.setItem(k, v); } catch { /* yoksay */ } }
function setStatus(t) { statusEl.textContent = t; }

let msgTimer = 0;
function showMsg(t, ms = 2600) {
  msgEl.textContent = t;
  msgEl.classList.add("on");
  clearTimeout(msgTimer);
  msgTimer = setTimeout(() => msgEl.classList.remove("on"), ms);
}

// ---------- Durum ----------
const state = {
  mode: "idle",        // idle | camera | keyboard
  phase: "menu",       // menu | play | scare
  target: { left: 0, right: 0 },   // kameradan gelen göz kapanma değerleri (0 açık, 1 kapalı)
  closedL: false,
  closedR: false,
  eyesClosed: false,
  lid: 0,              // göz kapağı (0 açık, 1 tam kapalı), yumuşatılmış
  keys: { w: false, a: false, s: false, d: false, left: false, right: false, eye: false },
  btnEye: false,
  collected: 0,
  elapsed: 0,
  scareT: 0,
  danger: 0,
  flick: 1,
  dip: 0,
  bob: 0,
  bestTime: Number(safeGet("gk_best_time") || 0),
};

let world = null;
window.__gk = { state, get world() { return world; } }; // hata ayıklama için

// ---------- Kamera + yüz izleme (yalnızca göz) ----------
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
  initAudio();
  setStatus("Yüz modeli yükleniyor…");
  try {
    if (!landmarker) landmarker = await loadLandmarker();
    setStatus("Kamera izni bekleniyor…");
    if (!video.srcObject) {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, frameRate: { ideal: 60, min: 30 }, facingMode: "user" },
        audio: false,
      });
      video.srcObject = stream;
      await video.play();
    }
    video.style.display = "block";
    state.mode = "camera";
    eyeBtn.classList.add("hidden");
    startGame();
  } catch (err) {
    console.error(err);
    startBtn.disabled = false;
    setStatus("Kamera açılamadı: " + (err && err.message ? err.message : err) + " — kamerasız modu deneyebilirsin.");
  }
}

let lastVideoTime = -1;
let noFaceMsgAt = 0;
function readCamera() {
  if (!landmarker || video.readyState < 2) return;
  if (video.currentTime === lastVideoTime) return;
  lastVideoTime = video.currentTime;
  const res = landmarker.detectForVideo(video, performance.now());
  const shapes = res.faceBlendshapes && res.faceBlendshapes[0];
  if (!shapes) {
    // Yüz yoksa gözler açık sayılır (takılı kalmasın)
    state.target.left = 0;
    state.target.right = 0;
    if (performance.now() - noFaceMsgAt > 4000) { noFaceMsgAt = performance.now(); showMsg("Yüzün görünmüyor, kameraya dön…"); }
    return;
  }
  let l = 0, r = 0;
  for (const c of shapes.categories) {
    if (c.categoryName === "eyeBlinkLeft") l = c.score;
    else if (c.categoryName === "eyeBlinkRight") r = c.score;
  }
  state.target.left = l;
  state.target.right = r;
}

function readManualEyes() {
  const closed = state.keys.eye || state.btnEye;
  state.target.left = closed ? 1 : 0;
  state.target.right = closed ? 1 : 0;
}

// ---------- Girdiler: klavye ----------
addEventListener("keydown", (e) => setKey(e, true));
addEventListener("keyup", (e) => setKey(e, false));
function setKey(e, down) {
  const k = state.keys;
  switch (e.code) {
    case "KeyW": k.w = down; break;
    case "ArrowUp": k.w = down; e.preventDefault(); break;
    case "KeyS": k.s = down; break;
    case "ArrowDown": k.s = down; e.preventDefault(); break;
    case "KeyA": k.a = down; break;
    case "KeyD": k.d = down; break;
    case "ArrowLeft": k.left = down; e.preventDefault(); break;
    case "ArrowRight": k.right = down; e.preventDefault(); break;
    case "Space": k.eye = down; e.preventDefault(); break;
  }
}

// ---------- Girdiler: dokunma ----------
// Sol yarı: parmak nerede değerse joystick orada belirir, uzaklık sınırı yoktur.
// Sağ yarı: yalnızca ekranı (bakışı) döndürür, hareket ettirmez.
const joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 };
const look = { id: null, x: 0 };
const half = () => (window.innerWidth || 800) / 2;

touchLayer.addEventListener("pointerdown", (e) => {
  e.preventDefault();
  if (state.phase !== "play") return;
  try { touchLayer.setPointerCapture(e.pointerId); } catch { /* yoksay */ }
  if (e.clientX < half()) {
    if (joy.id === null) {
      joy.id = e.pointerId;
      joy.ox = joy.x = e.clientX;
      joy.oy = joy.y = e.clientY;
      joyEl.style.left = joy.ox + "px";
      joyEl.style.top = joy.oy + "px";
      knobEl.style.transform = "translate(0,0)";
      joyEl.classList.add("on");
    }
  } else if (look.id === null) {
    look.id = e.pointerId;
    look.x = e.clientX;
  }
});

touchLayer.addEventListener("pointermove", (e) => {
  if (e.pointerId === joy.id) {
    joy.x = e.clientX;
    joy.y = e.clientY;
    const dx = joy.x - joy.ox, dy = joy.y - joy.oy;
    const d = Math.hypot(dx, dy) || 1;
    const k = Math.min(d, 44) / d; // topuz görsel olarak halkada kalır, hareket mesafesi sınırsızdır
    knobEl.style.transform = `translate(${dx * k}px,${dy * k}px)`;
  } else if (e.pointerId === look.id) {
    // Sağ yarıdayken döner; parmak sol yarıya geçerse dönmez
    if (e.clientX >= half() && state.phase === "play") yaw(( e.clientX - look.x) * LOOK_SENS);
    look.x = e.clientX;
  }
});

function releasePointer(e) {
  if (e.pointerId === joy.id) { joy.id = null; joyEl.classList.remove("on"); }
  if (e.pointerId === look.id) look.id = null;
}
touchLayer.addEventListener("pointerup", releasePointer);
touchLayer.addEventListener("pointercancel", releasePointer);
touchLayer.addEventListener("contextmenu", (e) => e.preventDefault());

function resetTouch() {
  joy.id = null; look.id = null;
  joyEl.classList.remove("on");
  state.btnEye = false;
  eyeBtn.classList.remove("down");
}

// Kamerasız modda gözü kapatma düğmesi (basılı tut)
eyeBtn.addEventListener("pointerdown", (e) => {
  e.preventDefault(); e.stopPropagation();
  try { eyeBtn.setPointerCapture(e.pointerId); } catch { /* yoksay */ }
  state.btnEye = true; eyeBtn.classList.add("down");
});
const eyeUp = (e) => { e.stopPropagation(); state.btnEye = false; eyeBtn.classList.remove("down"); };
eyeBtn.addEventListener("pointerup", eyeUp);
eyeBtn.addEventListener("pointercancel", eyeUp);

// ---------- Labirent ----------
let S = 0;

function genMaze(n) {
  S = n * 2 + 1;
  const m = new Uint8Array(S * S).fill(1);
  const seen = new Uint8Array(n * n);
  const stack = [[0, 0]];
  seen[0] = 1;
  m[1 * S + 1] = 0;
  const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  while (stack.length) {
    const [cx, cy] = stack[stack.length - 1];
    const opts = [];
    for (const [dx, dy] of dirs) {
      const nx = cx + dx, ny = cy + dy;
      if (nx >= 0 && ny >= 0 && nx < n && ny < n && !seen[ny * n + nx]) opts.push([dx, dy, nx, ny]);
    }
    if (!opts.length) { stack.pop(); continue; }
    const [dx, dy, nx, ny] = opts[Math.floor(Math.random() * opts.length)];
    seen[ny * n + nx] = 1;
    m[(2 * cy + 1 + dy) * S + (2 * cx + 1 + dx)] = 0;
    m[(2 * ny + 1) * S + (2 * nx + 1)] = 0;
    stack.push([nx, ny]);
  }
  // Döngüler aç: donmuş bir gölge koridoru tıkamasın, kaçış yolu hep olsun
  let extra = Math.floor(n * n * 0.3);
  for (let tries = 0; extra > 0 && tries < 600; tries++) {
    const x = 1 + Math.floor(Math.random() * (S - 2));
    const y = 1 + Math.floor(Math.random() * (S - 2));
    if (m[y * S + x] !== 1 || (x + y) % 2 === 0) continue;
    const ok = x % 2 === 0
      ? m[y * S + x - 1] === 0 && m[y * S + x + 1] === 0
      : m[(y - 1) * S + x] === 0 && m[(y + 1) * S + x] === 0;
    if (ok) { m[y * S + x] = 0; extra--; }
  }
  return m;
}

function bfs(map, sx, sy) {
  const d = new Int16Array(S * S).fill(-1);
  const q = [sy * S + sx];
  d[q[0]] = 0;
  for (let i = 0; i < q.length; i++) {
    const c = q[i], x = c % S, y = (c / S) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy, nc = ny * S + nx;
      if (nx < 0 || ny < 0 || nx >= S || ny >= S || map[nc] || d[nc] >= 0) continue;
      d[nc] = d[c] + 1;
      q.push(nc);
    }
  }
  return d;
}

function buildWorld() {
  const map = genMaze(MAZE_CELLS);
  const distStart = bfs(map, 1, 1);
  const cells = [];
  for (let cy = 0; cy < MAZE_CELLS; cy++) for (let cx = 0; cx < MAZE_CELLS; cx++) cells.push([2 * cx + 1, 2 * cy + 1]);
  const shuffled = cells.sort(() => Math.random() - 0.5);

  const enemies = [];
  for (const [x, y] of shuffled) {
    if (enemies.length >= ENEMY_COUNT) break;
    if (distStart[y * S + x] < 14) continue;
    if (enemies.some((e) => Math.hypot(e.x - (x + 0.5), e.y - (y + 0.5)) < 5)) continue;
    enemies.push({ x: x + 0.5, y: y + 0.5, tx: 0, ty: 0, has: false, chase: false, phase: Math.random() * 6 });
  }
  // yeterince uzak yer bulunamazsa en uzak hücreleri al
  for (const [x, y] of shuffled.slice().sort((a, b) => distStart[b[1] * S + b[0]] - distStart[a[1] * S + a[0]])) {
    if (enemies.length >= ENEMY_COUNT) break;
    if (!enemies.some((e) => e.x === x + 0.5 && e.y === y + 0.5)) enemies.push({ x: x + 0.5, y: y + 0.5, tx: 0, ty: 0, has: false, chase: false, phase: 0 });
  }

  const orbs = [];
  for (const [x, y] of shuffled) {
    if (orbs.length >= FLIES_NEEDED) break;
    if (distStart[y * S + x] < 6) continue;
    if (orbs.some((o) => Math.hypot(o.x - (x + 0.5), o.y - (y + 0.5)) < 4)) continue;
    if (enemies.some((e) => Math.hypot(e.x - (x + 0.5), e.y - (y + 0.5)) < 5)) continue;
    orbs.push({ x: x + 0.5, y: y + 0.5, taken: false, ph: Math.random() * 6 });
  }
  for (const [x, y] of shuffled) {
    if (orbs.length >= FLIES_NEEDED) break;
    if (!orbs.some((o) => o.x === x + 0.5 && o.y === y + 0.5) && distStart[y * S + x] >= 4) orbs.push({ x: x + 0.5, y: y + 0.5, taken: false, ph: Math.random() * 6 });
  }

  // Açık yöne bakarak başla
  let yawStart = 0;
  if (map[1 * S + 2] === 0) yawStart = 0;
  else if (map[2 * S + 1] === 0) yawStart = Math.PI / 2;

  return { map, enemies, orbs, px: 1.5, py: 1.5, yaw: yawStart, dist: null };
}

// ---------- Oyun akışı ----------
function startGame() {
  initAudio();
  world = buildWorld();
  state.phase = "play";
  state.collected = 0;
  state.elapsed = 0;
  state.lid = 0;
  state.closedL = state.closedR = state.eyesClosed = false;
  state.danger = 0;
  state.scareT = 0;
  resetTouch();
  fliesEl.textContent = "0";
  timeEl.textContent = "0";
  eyesEl.textContent = "açık";
  hudEl.style.display = "flex";
  menuEl.classList.add("off");
  startBtn.disabled = false;
  if (state.mode === "keyboard") eyeBtn.classList.remove("hidden");
  showMsg("Gözlerin açıkken gölgeler donar. Kırptığın an gelirler.", 4200);
}

function endGame(win) {
  state.phase = "menu";
  hudEl.style.display = "none";
  eyeBtn.classList.add("hidden");
  msgEl.classList.remove("on");
  resetTouch();
  menuEl.classList.remove("off");
  startBtn.textContent = state.mode === "camera" ? "Tekrar oyna" : "Kamerayı aç ve başla";
  if (win) {
    const t = Math.round(state.elapsed);
    let line = `Kurtuldun! Süre: ${t} sn.`;
    if (!state.bestTime || t < state.bestTime) {
      state.bestTime = t;
      safeSet("gk_best_time", String(t));
      line += " Yeni rekor!";
    } else line += ` Rekor: ${state.bestTime} sn.`;
    resultEl.style.color = "#b6f0c0";
    resultEl.textContent = line;
  } else {
    resultEl.style.color = "#ffb4a8";
    resultEl.textContent = `Seni yakaladılar. ${state.collected}/${FLIES_NEEDED} ışık böceği toplamıştın.`;
  }
  setStatus(state.mode === "camera" ? "Tekrar denemek için butona bas." : "Tekrar denemek için bir mod seç.");
}

function caught() {
  state.phase = "scare";
  state.scareT = 0;
  resetTouch();
  playScream();
  if (navigator.vibrate) { try { navigator.vibrate([80, 40, 160]); } catch { /* yoksay */ } }
}

// ---------- Hareket ----------
function yaw(a) { if (world) world.yaw += a; }

function blocked(x, y, r) {
  const m = world.map;
  return m[((y - r) | 0) * S + ((x - r) | 0)] || m[((y - r) | 0) * S + ((x + r) | 0)] ||
         m[((y + r) | 0) * S + ((x - r) | 0)] || m[((y + r) | 0) * S + ((x + r) | 0)];
}

function movePlayer(dt) {
  const k = state.keys;
  // klavye
  let fwd = (k.w ? 1 : 0) - (k.s ? 1 : 0);
  let str = (k.d ? 1 : 0) - (k.a ? 1 : 0);
  // joystick (sınırsız mesafe; hız JOY_FULL'de doyar)
  if (joy.id !== null) {
    const dx = joy.x - joy.ox, dy = joy.y - joy.oy;
    const d = Math.hypot(dx, dy);
    if (d > JOY_DEAD) {
      const mag = Math.min(1, (d - JOY_DEAD) / (JOY_FULL - JOY_DEAD));
      fwd += (-dy / d) * mag;
      str += (dx / d) * mag;
    }
  }
  if (k.left) yaw(-2.0 * dt);
  if (k.right) yaw(2.0 * dt);

  const len = Math.hypot(fwd, str);
  if (len > 1) { fwd /= len; str /= len; }
  const dirX = Math.cos(world.yaw), dirY = Math.sin(world.yaw);
  const vx = (dirX * fwd - dirY * str) * PLAYER_SPEED * dt;
  const vy = (dirY * fwd + dirX * str) * PLAYER_SPEED * dt;
  if (vx || vy) {
    if (!blocked(world.px + vx, world.py, PLAYER_RADIUS)) world.px += vx;
    if (!blocked(world.px, world.py + vy, PLAYER_RADIUS)) world.py += vy;
    state.bob += dt * 9 * Math.min(1, len);
  }
}

function updateEyes(dt) {
  for (const [key, flag] of [["left", "closedL"], ["right", "closedR"]]) {
    if (!state[flag] && state.target[key] > CLOSE_AT) state[flag] = true;
    else if (state[flag] && state.target[key] < OPEN_AT) state[flag] = false;
  }
  const was = state.eyesClosed;
  state.eyesClosed = state.closedL && state.closedR;
  if (state.eyesClosed !== was) eyesEl.textContent = state.eyesClosed ? "KAPALI" : "açık";
  const goal = state.eyesClosed ? 1 : 0;
  state.lid += (goal - state.lid) * Math.min(1, dt * 22);
}

function enemySpeed() { return ENEMY_BASE_SPEED + ENEMY_SPEED_PER_FLY * state.collected; }

function moveEnemy(e, dt, dist) {
  let step = enemySpeed() * dt;
  const pcx = world.px | 0, pcy = world.py | 0;
  for (let guard = 0; step > 1e-5 && guard < 6; guard++) {
    if (!e.has) {
      const cx = e.x | 0, cy = e.y | 0;
      if (cx === pcx && cy === pcy) { e.tx = world.px; e.ty = world.py; e.chase = true; e.has = true; }
      else {
        let best = dist[cy * S + cx], bx = cx, by = cy;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = cx + dx, ny = cy + dy, nd = dist[ny * S + nx];
          if (nd >= 0 && !world.map[ny * S + nx] && nd < best) { best = nd; bx = nx; by = ny; }
        }
        if (bx === cx && by === cy) return;
        e.tx = bx + 0.5; e.ty = by + 0.5; e.chase = false; e.has = true;
      }
    }
    if (e.chase) { e.tx = world.px; e.ty = world.py; }
    const dx = e.tx - e.x, dy = e.ty - e.y, d = Math.hypot(dx, dy);
    if (d <= step) { e.x = e.tx; e.y = e.ty; step -= d; e.has = false; if (e.chase) return; }
    else { e.x += (dx / d) * step; e.y += (dy / d) * step; step = 0; }
  }
}

let stepNext = 0;
function updateWorld(dt) {
  state.elapsed += dt;
  const sec = Math.floor(state.elapsed);
  if (timeEl.textContent !== String(sec)) timeEl.textContent = sec;

  movePlayer(dt);

  // Gölgeler: yalnızca gözler KAPALIYKEN hareket eder
  let nearest = 99;
  if (state.eyesClosed) {
    const dist = bfs(world.map, world.px | 0, world.py | 0);
    for (const e of world.enemies) moveEnemy(e, dt, dist);
    stepNext -= dt;
    if (stepNext <= 0) { stepNext = 0.32; playStep(); }
  }
  for (const e of world.enemies) nearest = Math.min(nearest, Math.hypot(e.x - world.px, e.y - world.py));
  state.danger = Math.max(0, Math.min(1, 1 - nearest / 8));

  // Işık böceği topla
  for (const o of world.orbs) {
    if (!o.taken && Math.hypot(o.x - world.px, o.y - world.py) < 0.55) {
      o.taken = true;
      state.collected++;
      fliesEl.textContent = state.collected;
      playPickup();
      if (state.collected >= FLIES_NEEDED) { endGame(true); return; }
      showMsg(`Işık böceği ${state.collected}/${FLIES_NEEDED}. Gölgeler hızlandı…`, 2400);
    }
  }
  // Yakalanma
  for (const e of world.enemies) {
    if (Math.hypot(e.x - world.px, e.y - world.py) < CATCH_DIST) { caught(); return; }
  }

  // Fener titremesi (tehlike arttıkça sıklaşır)
  if (Math.random() < 0.02 + state.danger * 0.1) state.dip = 0.35 + Math.random() * 0.4;
  state.dip *= Math.pow(0.02, dt);
  const t = performance.now() / 1000;
  state.flick = (0.9 + 0.06 * Math.sin(t * 13) + 0.04 * Math.sin(t * 31.7)) * (1 - state.dip);

  heartbeat(dt);
}

// ---------- Ses (WebAudio) ----------
let AC = null, master = null, beatT = 0;
function initAudio() {
  if (AC) { if (AC.state === "suspended") AC.resume(); return; }
  try {
    AC = new (window.AudioContext || window.webkitAudioContext)();
    master = AC.createGain();
    master.gain.value = 0.9;
    master.connect(AC.destination);
    // Alçak uğultu
    for (const [f, type, g] of [[38, "sawtooth", 0.035], [41.5, "sine", 0.06], [57, "triangle", 0.02]]) {
      const o = AC.createOscillator(); o.type = type; o.frequency.value = f;
      const lp = AC.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 160;
      const gn = AC.createGain(); gn.gain.value = g;
      o.connect(lp); lp.connect(gn); gn.connect(master); o.start();
    }
    // Rüzgâr
    const len = AC.sampleRate * 2;
    const buf = AC.createBuffer(1, len, AC.sampleRate);
    const ch = buf.getChannelData(0);
    for (let i = 0; i < len; i++) ch[i] = Math.random() * 2 - 1;
    const src = AC.createBufferSource(); src.buffer = buf; src.loop = true;
    const bp = AC.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 380; bp.Q.value = 0.7;
    const wg = AC.createGain(); wg.gain.value = 0.025;
    const lfo = AC.createOscillator(); lfo.frequency.value = 0.12;
    const lg = AC.createGain(); lg.gain.value = 0.015;
    lfo.connect(lg); lg.connect(wg.gain); lfo.start();
    src.connect(bp); bp.connect(wg); wg.connect(master); src.start();
  } catch { AC = null; }
}

function thump(vol, at = 0) {
  if (!AC) return;
  const t = AC.currentTime + at;
  const o = AC.createOscillator(); o.type = "sine";
  o.frequency.setValueAtTime(70, t); o.frequency.exponentialRampToValueAtTime(34, t + 0.14);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.015);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.22);
}

function heartbeat(dt) {
  beatT -= dt;
  if (beatT > 0) return;
  const d = state.danger;
  beatT = 1.15 - 0.7 * d;
  const v = 0.12 + 0.5 * d;
  thump(v); thump(v * 0.65, 0.2);
}

function noiseBurst(vol, dur, freq, type = "bandpass") {
  if (!AC) return;
  const len = Math.floor(AC.sampleRate * dur);
  const buf = AC.createBuffer(1, len, AC.sampleRate);
  const ch = buf.getChannelData(0);
  for (let i = 0; i < len; i++) ch[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const s = AC.createBufferSource(); s.buffer = buf;
  const f = AC.createBiquadFilter(); f.type = type; f.frequency.value = freq;
  const g = AC.createGain(); g.gain.value = vol;
  s.connect(f); f.connect(g); g.connect(master); s.start();
}

function playStep() {
  // Gözün kapalıyken gölgelerin adımlarını duyarsın: yakınsa daha yüksek
  let nearest = 99;
  for (const e of world.enemies) nearest = Math.min(nearest, Math.hypot(e.x - world.px, e.y - world.py));
  const v = Math.max(0, Math.min(0.55, 1.4 / (nearest + 0.5) - 0.1));
  if (v > 0.02) noiseBurst(v, 0.09, 140, "lowpass");
}

function playPickup() {
  if (!AC) return;
  const t = AC.currentTime;
  const o = AC.createOscillator(); o.type = "sine";
  o.frequency.setValueAtTime(520, t); o.frequency.exponentialRampToValueAtTime(1040, t + 0.18);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.12, t + 0.03);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.4);
}

function playScream() {
  if (!AC) return;
  noiseBurst(0.7, 0.9, 1800, "highpass");
  const t = AC.currentTime;
  const o = AC.createOscillator(); o.type = "sawtooth";
  o.frequency.setValueAtTime(90, t); o.frequency.exponentialRampToValueAtTime(520, t + 0.5);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.3, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 1.1);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + 1.2);
}

// ---------- Görüntü: yazılım ışın izleme ----------
let RW = 0, RH = 0, SC = 0, img = null, buf32 = null, zbuf = null, vig = null;
const noise = new Float32Array(4096).map(() => Math.random());

function resize() {
  const w = window.innerWidth || 800, h = window.innerHeight || 450;
  RW = Math.max(240, Math.min(400, Math.round(w / 2.2)));
  RH = Math.max(150, Math.min(340, Math.round((RW * h) / w)));
  SC = RW / (2 * FOV_K); // 1 birim uzaklıkta, 1 birim yüksekliğin piksel karşılığı
  canvas.width = RW;
  canvas.height = RH;
  img = ctx.createImageData(RW, RH);
  buf32 = new Uint32Array(img.data.buffer);
  zbuf = new Float32Array(RW);
  vig = new Float32Array(RW * RH);
  for (let y = 0; y < RH; y++) {
    for (let x = 0; x < RW; x++) {
      const nx = (x / RW - 0.5) * 2, ny = (y / RH - 0.5) * 2;
      const r = (nx * nx + ny * ny) / 2;
      vig[y * RW + x] = Math.max(0.1, 1 - 0.95 * Math.pow(r, 0.95));
    }
  }
}
addEventListener("resize", resize);

// Dokular (64x64, procedural): taş duvar + yosun, çamur zemin, mağara tavanı
function hash(x, y) { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); }
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function makeTex(kind) {
  const T = new Uint8Array(64 * 64 * 3);
  for (let y = 0; y < 64; y++) {
    for (let x = 0; x < 64; x++) {
      const n = vnoise(x * 0.35, y * 0.35) * 0.6 + vnoise(x * 0.9, y * 0.9) * 0.4;
      const moss = vnoise(x * 0.12 + 7, y * 0.12 + 3);
      let r, g, b;
      if (kind === 0) { // duvar
        const row = (y / 16) | 0, bx = (x + (row % 2 ? 16 : 0)) % 32, by = y % 16;
        const mortar = by < 2 || bx < 2;
        const base = mortar ? 38 : 88 + n * 60;
        r = base * 0.88; g = base * 0.96; b = base * 0.82;
        if (moss > 0.52) { const k = Math.min(1, (moss - 0.52) * 4); r = r * (1 - k) + 40 * k * (0.6 + n * 0.6); g = g * (1 - k) + 100 * k * (0.6 + n * 0.6); b = b * (1 - k) + 36 * k * (0.6 + n * 0.6); }
      } else if (kind === 1) { // zemin: ıslak çamur
        const base = 55 + n * 55;
        r = base * 0.8; g = base * 0.78; b = base * 0.55;
        if (moss > 0.5) { r *= 0.6; g *= 1.1; b *= 0.6; }
      } else { // tavan
        const base = 35 + n * 40;
        r = base * 0.8; g = base * 0.9; b = base;
      }
      const i = (y * 64 + x) * 3;
      T[i] = r; T[i + 1] = g; T[i + 2] = b;
    }
  }
  return T;
}
const TEX_WALL = makeTex(0), TEX_FLOOR = makeTex(1), TEX_CEIL = makeTex(2);

const AMB = 0.018;
function light(d) { return AMB + (1 - AMB) * state.flick / (1 + 0.85 * d * d); }

function px32(r, g, b) {
  r = r < 0 ? 0 : r > 255 ? 255 : r | 0;
  g = g < 0 ? 0 : g > 255 ? 255 : g | 0;
  b = b < 0 ? 0 : b > 255 ? 255 : b | 0;
  return (255 << 24) | (b << 16) | (g << 8) | r;
}

// Fener rengi (soluk, yeşilimsi sarı)
const TINT = [1.0, 0.95, 0.72];
let frameNo = 0;

function renderWorld(time) {
  const { map, px, py } = world;
  const dirX = Math.cos(world.yaw), dirY = Math.sin(world.yaw);
  const plX = -dirY * FOV_K, plY = dirX * FOV_K;
  const horizon = RH / 2 + Math.sin(state.bob) * 1.6 * (RH / 220);
  const noiseOff = (frameNo * 977) & 4095;

  // Zemin ve tavan
  const ambFill = px32(AMB * 150, AMB * 190, AMB * 170);
  for (let y = 0; y < RH; y++) {
    const isFloor = y > horizon;
    const dy = isFloor ? y - horizon : horizon - y;
    if (dy < 0.5) { for (let x = 0; x < RW; x++) buf32[y * RW + x] = 0xff000000; continue; }
    const rowDist = ((isFloor ? CAM_H : 1 - CAM_H) * SC) / dy;
    const sh = light(rowDist);
    if (sh < AMB * 1.25) {
      const base = y * RW;
      for (let x = 0; x < RW; x++) buf32[base + x] = ambFill;
      continue;
    }
    const tex = isFloor ? TEX_FLOOR : TEX_CEIL;
    const mul = sh * (isFloor ? 1.0 : 0.7);
    let fx = px + rowDist * (dirX - plX);
    let fy = py + rowDist * (dirY - plY);
    const sx = (rowDist * 2 * plX) / RW, sy = (rowDist * 2 * plY) / RW;
    const base = y * RW;
    for (let x = 0; x < RW; x++) {
      const tx = ((fx - Math.floor(fx)) * 64) | 0, ty = ((fy - Math.floor(fy)) * 64) | 0;
      const ti = (ty * 64 + tx) * 3;
      const m = mul * vig[base + x] * (0.92 + noise[(base + x + noiseOff) & 4095] * 0.16);
      buf32[base + x] = px32(tex[ti] * m * TINT[0], tex[ti + 1] * m * TINT[1], tex[ti + 2] * m * TINT[2]);
      fx += sx; fy += sy;
    }
  }

  // Duvarlar
  for (let x = 0; x < RW; x++) {
    const camX = (2 * x) / RW - 1;
    const rdx = dirX + plX * camX, rdy = dirY + plY * camX;
    let mx = px | 0, my = py | 0;
    const ddx = rdx === 0 ? 1e30 : Math.abs(1 / rdx), ddy = rdy === 0 ? 1e30 : Math.abs(1 / rdy);
    let stepX, stepY, sdx, sdy;
    if (rdx < 0) { stepX = -1; sdx = (px - mx) * ddx; } else { stepX = 1; sdx = (mx + 1 - px) * ddx; }
    if (rdy < 0) { stepY = -1; sdy = (py - my) * ddy; } else { stepY = 1; sdy = (my + 1 - py) * ddy; }
    let side = 0;
    for (let i = 0; i < 64; i++) {
      if (sdx < sdy) { sdx += ddx; mx += stepX; side = 0; } else { sdy += ddy; my += stepY; side = 1; }
      if (map[my * S + mx]) break;
    }
    let perp = side === 0 ? sdx - ddx : sdy - ddy;
    if (perp < 0.05) perp = 0.05;
    zbuf[x] = perp;
    let wallX = side === 0 ? py + perp * rdy : px + perp * rdx;
    wallX -= Math.floor(wallX);
    let texX = (wallX * 64) | 0;
    if ((side === 0 && rdx > 0) || (side === 1 && rdy < 0)) texX = 63 - texX;

    const lineH = SC / perp;
    const topF = horizon - (1 - CAM_H) * lineH;
    let y0 = Math.max(0, topF | 0), y1 = Math.min(RH - 1, (horizon + CAM_H * lineH) | 0);
    const sh = light(perp) * (side ? 0.78 : 1);
    const stepT = 64 / lineH;
    let tyF = (y0 - topF) * stepT;
    for (let y = y0; y <= y1; y++) {
      const ti = ((tyF & 63) * 64 + texX) * 3;
      tyF += stepT;
      const idx = y * RW + x;
      const m = sh * vig[idx] * (0.92 + noise[(idx + noiseOff) & 4095] * 0.16);
      buf32[idx] = px32(TEX_WALL[ti] * m * TINT[0], TEX_WALL[ti + 1] * m * TINT[1], TEX_WALL[ti + 2] * m * TINT[2]);
    }
  }

  // Cisimler (gölgeler ve ışık böcekleri), uzaktan yakına doğru çizilir
  const list = [];
  for (const o of world.orbs) if (!o.taken) list.push({ k: 1, o, d: (o.x - px) ** 2 + (o.y - py) ** 2 });
  for (const e of world.enemies) list.push({ k: 0, o: e, d: (e.x - px) ** 2 + (e.y - py) ** 2 });
  list.sort((a, b) => b.d - a.d);
  const inv = 1 / (plX * dirY - dirX * plY);
  for (const s of list) {
    const rx = s.o.x - px, ry = s.o.y - py;
    const tx = inv * (dirY * rx - dirX * ry);
    const ty = inv * (-plY * rx + plX * ry);
    if (ty < 0.15) continue;
    drawSprite(s.k, s.o, tx, ty, horizon, time);
  }
}

// Sprite renk çıktısı (r,g,b,a)
let sr = 0, sg = 0, sb = 0, sa = 0;

function enemyPixel(u, v, lit, ef) {
  sa = 0;
  const dx = u - 0.5;
  let inside = false;
  const hx = dx / 0.21, hy = (v - 0.17) / 0.14;
  if (hx * hx + hy * hy < 1) inside = true;
  else if (v > 0.28 && v < 0.76) {
    const k = (v - 0.28) / 0.48;
    const hw = 0.06 + 0.16 * Math.sin(Math.min(1, k * 1.3) * Math.PI * 0.5) * (1 - 0.35 * k);
    if (Math.abs(dx) < hw) inside = true;
  } else if (v >= 0.76) {
    if (Math.abs(Math.abs(dx) - 0.1) < 0.045) inside = true;
  }
  if (!inside && v > 0.3 && v < 0.98) {
    const ax = 0.23 + 0.06 * (v - 0.3);
    if (Math.abs(Math.abs(dx) - ax) < 0.022) inside = true;
  }
  if (!inside) return;
  // ten: solgun, yeşilimsi; sadece fener ışığı kadar görünür
  const skin = 0.06 + lit;
  sr = 105 * skin; sg = 128 * skin; sb = 108 * skin; sa = 1;
  // ağız
  const mdx = dx / 0.13;
  if (Math.abs(mdx) < 1) {
    const my = 0.235 + 0.035 * (1 - mdx * mdx);
    if (Math.abs(v - my) < 0.013) { sr = 12; sg = 0; sb = 0; }
    else if (v < my - 0.013 && v > my - 0.03 && Math.floor((dx + 0.13) / 0.022) % 2 === 0) { sr = 200 * (0.2 + lit); sg = 200 * (0.2 + lit); sb = 180 * (0.2 + lit); }
  }
  // gözler: karanlıkta parlar
  for (const cx of [0.39, 0.61]) {
    const ex = (u - cx) / 0.055, ey = (v - 0.15) / 0.05;
    if (ex * ex + ey * ey < 1) {
      if (Math.abs(u - cx) < 0.007) { sr = 5; sg = 5; sb = 0; }
      else { sr = 235 * (0.3 + 0.7 * ef); sg = 255 * (0.3 + 0.7 * ef); sb = 90 * (0.3 + 0.7 * ef); }
    }
  }
}

function drawSprite(kind, o, tx, ty, horizon, time) {
  const scr = (RW / 2) * (1 + tx / ty);
  const unit = SC / ty;
  let h, w, bottom;
  if (kind === 0) { h = unit * 1.1; w = h * 0.55; bottom = horizon + CAM_H * unit; }
  else { h = unit * 0.16; w = h; bottom = horizon + (CAM_H - 0.32 - Math.sin(time * 2 + o.ph) * 0.05) * unit + h / 2; }
  const top = bottom - h;
  const x0 = Math.max(0, (scr - w / 2) | 0), x1 = Math.min(RW - 1, (scr + w / 2) | 0);
  const y0 = Math.max(0, top | 0), y1 = Math.min(RH - 1, bottom | 0);
  if (x1 < x0 || y1 < y0) return;
  const dist = Math.hypot(o.x - world.px, o.y - world.py);
  const lit = light(dist) - AMB;
  const ef = Math.max(0, Math.min(1, 1.5 - dist / 12)); // gözler uzakta sönükleşir
  const noiseOff = (frameNo * 977) & 4095;
  for (let x = x0; x <= x1; x++) {
    if (ty >= zbuf[x]) continue;
    const u = (x - (scr - w / 2)) / w;
    for (let y = y0; y <= y1; y++) {
      const v = (y - top) / h;
      const idx = y * RW + x;
      if (kind === 0) {
        enemyPixel(u, v, lit, ef);
        if (sa === 0) continue;
        const m = vig[idx] * (0.9 + noise[(idx + noiseOff) & 4095] * 0.2);
        buf32[idx] = px32(sr * m, sg * m, sb * m);
      } else {
        const r2 = (u - 0.5) ** 2 + (v - 0.5) ** 2;
        const a = Math.exp(-r2 * 26);
        if (a < 0.03) continue;
        const c = buf32[idx];
        const dr = c & 255, dg = (c >> 8) & 255, db = (c >> 16) & 255;
        buf32[idx] = px32(dr + 190 * a, dg + 255 * a, db + 110 * a * 0.8);
      }
    }
  }
}

function renderFrame(time) {
  frameNo++;
  if (state.lid >= 0.97) {
    // Gözler tamamen kapalı: kızılımsı karanlık
    ctx.fillStyle = "#070000";
    ctx.fillRect(0, 0, RW, RH);
  } else {
    renderWorld(time);
    ctx.putImageData(img, 0, 0);
    // tehlike: kenarlarda kırmızı
    if (state.danger > 0.05) {
      const g = ctx.createRadialGradient(RW / 2, RH / 2, RH * 0.25, RW / 2, RH / 2, RH * 0.95);
      g.addColorStop(0, "rgba(90,0,0,0)");
      g.addColorStop(1, `rgba(90,0,0,${(state.danger * 0.55).toFixed(3)})`);
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, RW, RH);
    }
    // göz kapakları
    if (state.lid > 0.01) {
      const hh = (state.lid * RH) / 2 + 1;
      ctx.fillStyle = "#050000";
      ctx.fillRect(0, 0, RW, hh);
      ctx.fillRect(0, RH - hh, RW, hh);
      const soft = ctx.createLinearGradient(0, hh, 0, hh + 14);
      soft.addColorStop(0, "rgba(5,0,0,.9)"); soft.addColorStop(1, "rgba(5,0,0,0)");
      ctx.fillStyle = soft; ctx.fillRect(0, hh, RW, 14);
      const soft2 = ctx.createLinearGradient(0, RH - hh, 0, RH - hh - 14);
      soft2.addColorStop(0, "rgba(5,0,0,.9)"); soft2.addColorStop(1, "rgba(5,0,0,0)");
      ctx.fillStyle = soft2; ctx.fillRect(0, RH - hh - 14, RW, 14);
    }
  }
}

// Yakalanma sahnesi: ekrana fırlayan yüz
function renderScare(time) {
  const t = state.scareT;
  const shake = (1 - Math.min(1, t / 1.3)) * 10;
  ctx.fillStyle = t < 0.08 ? "#fff" : "#050000";
  ctx.fillRect(0, 0, RW, RH);
  if (t < 0.08) return;
  ctx.save();
  ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);
  const cx = RW / 2, cy = RH * 0.46, s = Math.min(RW, RH * 1.4) * (0.55 + Math.min(0.3, t * 0.4));
  // yüz
  ctx.fillStyle = "#26302a";
  ctx.beginPath(); ctx.ellipse(cx, cy, s * 0.42, s * 0.5, 0, 0, Math.PI * 2); ctx.fill();
  // gözler
  for (const sx of [-1, 1]) {
    const ex = cx + sx * s * 0.2, ey = cy - s * 0.1;
    const g = ctx.createRadialGradient(ex, ey, 2, ex, ey, s * 0.16);
    g.addColorStop(0, "#faffb0"); g.addColorStop(0.6, "#c8ff3a"); g.addColorStop(1, "rgba(200,255,60,0)");
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(ex, ey, s * 0.16, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#000"; ctx.fillRect(ex - 1.5, ey - s * 0.1, 3, s * 0.2);
  }
  // ağız
  ctx.fillStyle = "#120000";
  ctx.beginPath();
  ctx.moveTo(cx - s * 0.3, cy + s * 0.12);
  ctx.quadraticCurveTo(cx, cy + s * 0.5, cx + s * 0.3, cy + s * 0.12);
  ctx.quadraticCurveTo(cx, cy + s * 0.2, cx - s * 0.3, cy + s * 0.12);
  ctx.fill();
  ctx.fillStyle = "#dcd8c0";
  for (let i = 0; i < 9; i++) {
    const tx = cx - s * 0.26 + (i * s * 0.52) / 8;
    ctx.beginPath(); ctx.moveTo(tx - 3, cy + s * 0.14); ctx.lineTo(tx + 3, cy + s * 0.14); ctx.lineTo(tx, cy + s * 0.14 + s * 0.07); ctx.fill();
  }
  ctx.restore();
  // kızıl kenar
  const g = ctx.createRadialGradient(RW / 2, RH / 2, RH * 0.2, RW / 2, RH / 2, RH);
  g.addColorStop(0, "rgba(120,0,0,0)"); g.addColorStop(1, "rgba(120,0,0,.8)");
  ctx.fillStyle = g; ctx.fillRect(0, 0, RW, RH);
}

// ---------- Ana döngü ----------
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  const time = now / 1000;

  if (state.phase === "play") {
    if (state.mode === "camera") readCamera();
    else readManualEyes();
    updateEyes(dt);
    updateWorld(dt);
    if (state.phase === "play") renderFrame(time);
    else if (state.phase === "scare") renderScare(time);
  } else if (state.phase === "scare") {
    state.scareT += dt;
    renderScare(time);
    if (state.scareT > 1.5) endGame(false);
  } else if (world) {
    // menüde arka planda karanlık sahne
    state.lid = 0;
    state.flick = 0.85 + 0.1 * Math.sin(time * 9);
    world.yaw += dt * 0.15;
    renderFrame(time);
  } else {
    ctx.fillStyle = "#000"; ctx.fillRect(0, 0, RW, RH);
  }
  frameNo++;
  requestAnimationFrame(frame);
}

// ---------- Butonlar ----------
startBtn.addEventListener("click", () => {
  if (state.mode === "camera") startGame();
  else startCamera();
});
keyBtn.addEventListener("click", () => {
  state.mode = "keyboard";
  video.style.display = "none";
  startGame();
});

resize();
requestAnimationFrame(frame);
