// Karanlık Bataklık: giriş noktası. Sim (sim.js) + çizici (render.js) + girdiler + ses + göz algılama.
// Hata ayıklama kancaları: ?seed=N  ?play  ?sim=N (bot N sn oynar, son kare çizilir)  ?autoplay&speed=4
//                          ?scare  ?gallery=0..3  ?r.enemies.count=3 (rules.js'teki sayıyı değiştir)
import { RULES, applyOverrides } from "./rules.js";
import { createGame, step, rng, setPlayer } from "./sim.js";
import { makeBot } from "./bot.js";
import { Renderer, loadModels } from "./render.js";
import * as A from "./audio.js";
import { makeEyeTracker, loadLandmarker, openCamera } from "./eyes.js";
import { ruleLines, HINT_FIRST } from "./texts.js";
import { createAuth } from "./auth.js";

const Q = new URLSearchParams(location.search);
const R = applyOverrides(RULES, location.search);
const STEP = 1 / 60;

const $ = (id) => document.getElementById(id);
const canvas = $("game"), video = $("cam"), touchLayer = $("touch"), joyEl = $("joy"), knobEl = $("knob");
const hudEl = $("hud"), msgEl = $("msg"), eyeBtn = $("eyeBtn"), fireBtn = $("fireBtn"), swapBtn = $("swapBtn");
const menuEl = $("menu"), resultEl = $("result"), startBtn = $("start"), keyBtn = $("keyboard"), statusEl = $("status");
const el = { flies: $("flies"), need: $("need"), time: $("time"), shells: $("shells"), gun: $("gun"), eyes: $("eyes"), dry: $("dryFill"), dryBox: $("dry") };
el.need.textContent = R.goal.flies;
$("rules").innerHTML = ruleLines(R).map((t) => `<li>${t}</li>`).join("");

const auth = createAuth();
const loginView = $("loginView"), mainView = $("mainView"), authForm = $("authForm"), authMsg = $("authMsg"), authBtn = $("authBtn");
const tabLogin = $("tabLogin"), tabReg = $("tabReg"), userIn = $("user"), passIn = $("pass"), pass2In = $("pass2");
let regMode = false, avatarR = null;
const safeGet = (k) => { try { return localStorage.getItem(k); } catch { return null; } };
const safeSet = (k, v) => { try { localStorage.setItem(k, v); } catch { /* yoksay */ } };
const setStatus = (t) => { statusEl.textContent = t; };

let msgTimer = 0;
function showMsg(t, ms = 2600) {
  msgEl.textContent = t; msgEl.classList.add("on");
  clearTimeout(msgTimer); msgTimer = setTimeout(() => msgEl.classList.remove("on"), ms);
}

// ---------- Durum ----------
const ui = {
  mode: "idle",            // idle | camera | keyboard
  phase: "menu",           // menu | play | scare
  scareT: 0, lid: 0, flick: 1, dip: 0, hurt: 0, puffs: [], time: 0,
  keys: { w: false, a: false, s: false, d: false, left: false, right: false, eye: false, fire: false },
  btnEye: false, btnFire: false, tapFire: false, swap: false, lookAcc: 0,
  best: 0,
  speed: Math.max(1, Number(Q.get("speed") || 1)),
};
let g = null, renderer = null, bot = null, acc = 0, last = performance.now();
const eyesT = makeEyeTracker(R);
window.GAME = { get g() { return g; }, get renderer() { return renderer; }, R, ui, fx: () => fx() };

// ---------- Girdiler: klavye ----------
addEventListener("keydown", (e) => setKey(e, true));
addEventListener("keyup", (e) => setKey(e, false));
function setKey(e, down) {
  if (e.target && /^(INPUT|TEXTAREA)$/.test(e.target.tagName)) return;   // giriş formunda yazarken oyun tuşları çalışmasın
  const k = ui.keys;
  switch (e.code) {
    case "KeyW": case "ArrowUp": k.w = down; e.preventDefault(); break;
    case "KeyS": case "ArrowDown": k.s = down; e.preventDefault(); break;
    case "KeyA": k.a = down; break;
    case "KeyD": k.d = down; break;
    case "KeyQ": k.left = down; break;
    case "KeyE": k.right = down; break;
    case "ArrowLeft": k.left = down; e.preventDefault(); break;
    case "ArrowRight": k.right = down; e.preventDefault(); break;
    case "Space": k.eye = down; e.preventDefault(); break;
    case "KeyF": case "Enter": k.fire = down; e.preventDefault(); break;
    case "Tab": case "KeyR": if (down) ui.swap = true; e.preventDefault(); break;
  }
}

// ---------- Girdiler: dokunma ----------
// Sol yarı: parmak nerede değerse joystick orada belirir, uzaklık sınırı yoktur.
// Sağ yarı: yalnızca ekranı (bakışı) döndürür, hareket ettirmez. Kısa dokunuş = ateş.
const joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 };
const look = { id: null, x: 0, y: 0, x0: 0, y0: 0, t0: 0, moved: 0 };
const half = () => (window.innerWidth || 800) / 2;

touchLayer.addEventListener("pointerdown", (e) => {
  e.preventDefault();
  if (ui.phase !== "play") return;
  try { touchLayer.setPointerCapture(e.pointerId); } catch { /* yoksay */ }
  if (e.clientX < half()) {
    if (joy.id === null) {
      joy.id = e.pointerId; joy.ox = joy.x = e.clientX; joy.oy = joy.y = e.clientY;
      joyEl.style.left = joy.ox + "px"; joyEl.style.top = joy.oy + "px";
      knobEl.style.transform = "translate(0,0)";
      joyEl.classList.add("on");
    }
  } else if (look.id === null) {
    Object.assign(look, { id: e.pointerId, x: e.clientX, y: e.clientY, x0: e.clientX, y0: e.clientY, t0: performance.now(), moved: 0 });
  }
});
touchLayer.addEventListener("pointermove", (e) => {
  if (e.pointerId === joy.id) {
    joy.x = e.clientX; joy.y = e.clientY;
    const dx = joy.x - joy.ox, dy = joy.y - joy.oy, d = Math.hypot(dx, dy) || 1, k = Math.min(d, 44) / d;
    knobEl.style.transform = `translate(${dx * k}px,${dy * k}px)`;   // topuz halkada kalır, hareket mesafesi sınırsızdır
  } else if (e.pointerId === look.id) {
    // yalnızca sağ yarıdayken döner; parmak sol yarıya geçerse dönmez
    if (e.clientX >= half() && ui.phase === "play") ui.lookAcc += (e.clientX - look.x) * R.player.lookSens;
    look.moved = Math.max(look.moved, Math.hypot(e.clientX - look.x0, e.clientY - look.y0));
    look.x = e.clientX; look.y = e.clientY;
  }
});
function releasePointer(e) {
  if (e.pointerId === joy.id) { joy.id = null; joyEl.classList.remove("on"); }
  if (e.pointerId === look.id) {
    if (e.type === "pointerup" && look.moved < 12 && performance.now() - look.t0 < 230 && ui.phase === "play") ui.tapFire = true;
    look.id = null;
  }
}
touchLayer.addEventListener("pointerup", releasePointer);
touchLayer.addEventListener("pointercancel", releasePointer);
touchLayer.addEventListener("contextmenu", (e) => e.preventDefault());

function holdButton(btn, on, off) {
  btn.addEventListener("pointerdown", (e) => { e.preventDefault(); e.stopPropagation(); try { btn.setPointerCapture(e.pointerId); } catch { /* yoksay */ } on(); btn.classList.add("down"); });
  const up = (e) => { e.stopPropagation(); off(); btn.classList.remove("down"); };
  btn.addEventListener("pointerup", up); btn.addEventListener("pointercancel", up);
}
holdButton(eyeBtn, () => { ui.btnEye = true; }, () => { ui.btnEye = false; });
holdButton(fireBtn, () => { ui.btnFire = true; }, () => { ui.btnFire = false; });
holdButton(swapBtn, () => { ui.swap = true; }, () => {});

function resetTouch() {
  joy.id = null; look.id = null; joyEl.classList.remove("on");
  ui.btnEye = ui.btnFire = ui.tapFire = ui.swap = false; ui.lookAcc = 0;
  for (const b of [eyeBtn, fireBtn, swapBtn]) b.classList.remove("down");
}

// ---------- Girdi -> sim ----------
let joyMag = 0;
function humanInput(first) {
  const k = ui.keys;
  let fwd = (k.w ? 1 : 0) - (k.s ? 1 : 0), str = (k.d ? 1 : 0) - (k.a ? 1 : 0);
  if (joy.id !== null) {
    const dx = joy.x - joy.ox, dy = joy.y - joy.oy, d = Math.hypot(dx, dy), DEAD = 10, FULL = 60;
    if (d > DEAD) { const mag = Math.min(1, (d - DEAD) / (FULL - DEAD)); fwd += (-dy / d) * mag; str += (dx / d) * mag; }
  }
  const input = {
    fwd, str,
    turn: ((k.right ? 1 : 0) - (k.left ? 1 : 0)) * R.player.turnKeys,
    yaw: first ? ui.lookAcc : 0,
    eyes: eyesT.closed(),
    fire: k.fire || ui.btnFire || ui.tapFire,
    switchWeapon: ui.swap,
  };
  if (first) { ui.lookAcc = 0; ui.tapFire = false; ui.swap = false; }
  return input;
}

// ---------- Oyun akışı ----------
function newSeed() { return Q.has("seed") ? Number(Q.get("seed")) : 1 + Math.floor(Math.random() * 1e6); }

function startGame(seed = newSeed()) {
  A.initAudio();
  g = createGame(seed, R);
  bot = Q.has("autoplay") ? makeBot(g, { rand: rng(seed * 7919 + 1) }) : null;
  ui.phase = "play"; ui.scareT = 0; ui.lid = 0; ui.hurt = 0; ui.puffs = []; acc = 0;
  eyesT.closedL = eyesT.closedR = false;
  resetTouch();
  menuEl.classList.add("off");
  startBtn.disabled = false;
  hudEl.style.display = "flex";
  const manual = ui.mode === "keyboard";
  eyeBtn.classList.toggle("hidden", !manual);
  fireBtn.classList.remove("hidden"); swapBtn.classList.remove("hidden");
  el.dryBox.classList.remove("hidden");
  showMsg(HINT_FIRST, 4200);
  updateHud(true);
}

function endGame(win) {
  ui.phase = "menu";
  hudEl.style.display = "none";
  for (const b of [eyeBtn, fireBtn, swapBtn]) b.classList.add("hidden");
  msgEl.classList.remove("on");
  resetTouch();
  menuEl.classList.remove("off");
  startBtn.textContent = ui.mode === "camera" ? "Tekrar oyna" : "Kamerayı aç ve başla";
  if (win) {
    const t = Math.round(g.time), before = auth.stats().best;
    const st = auth.recordGame({ win: true, time: g.time, kills: g.kills });
    let line = `Kurtuldun! Süre: ${t} sn, ${g.kills} gölge vurdun.`;
    line += !before || t < before ? " Yeni rekor!" : ` Rekor: ${before} sn.`;
    ui.best = st.best;
    resultEl.style.color = "#b6f0c0"; resultEl.textContent = line;
  } else {
    auth.recordGame({ win: false, time: g.time, kills: g.kills });
    resultEl.style.color = "#ffb4a8";
    resultEl.textContent = `Seni yakaladılar. ${g.collected}/${R.goal.flies} ışık böceği toplamıştın.`;
  }
  showView();
  setStatus(ui.mode === "camera" ? "Tekrar denemek için butona bas." : "Tekrar denemek için bir mod seç.");
}

function enterScare() {
  ui.phase = "scare"; ui.scareT = 0; ui.scareHit = false; resetTouch();
  hudEl.style.display = "none"; msgEl.classList.remove("on");
  for (const b of [eyeBtn, fireBtn, swapBtn]) b.classList.add("hidden");
}

function onEvents() {
  for (const ev of g.events) {
    switch (ev.t) {
      case "fire": A.playShot(ev.weapon); safeVibrate(25); break;
      case "empty": A.playEmpty(); showMsg("Mermin yok! Kırmızı mermi kutularını ara.", 1800); break;
      case "hit": A.playHit(); ui.puffs.push({ x: ev.x, y: ev.y, t: 0, seed: Math.random() * 6 }); break;
      case "kill": A.playKill(); ui.puffs.push({ x: ev.x, y: ev.y, t: 0, seed: Math.random() * 6 }); showMsg(`Gölge dağıldı. ${R.enemies.respawnSec} sn sonra geri döner…`, 2200); break;
      case "step": A.playStep(ev.near); break;
      case "fly": A.playPickup(); showMsg(`Işık böceği ${ev.n}/${R.goal.flies}. Gölgeler hızlandı…`, 2400); break;
      case "ammo": A.playPickup(); showMsg(`Mermi kutusu: ${ev.n} mermi.`, 1600); break;
      case "gun": A.playGunPick(); showMsg(`Yeni silah: ${R.weapons[ev.weapon].name}`, 2400); break;
      case "switch": A.playGunPick(); showMsg(R.weapons[ev.weapon].name, 1200); break;
      case "forcedBlink": A.playForcedBlink(); showMsg("Gözlerin yandı! Kırpmak zorundasın, gölgeler geliyor.", 2600); break;
      case "caught": enterScare(); A.playScareStart(); break;
      case "win": endGame(true); break;
    }
  }
  g.events.length = 0;
}
function safeVibrate(p) { if (navigator.vibrate) { try { navigator.vibrate(p); } catch { /* yoksay */ } } }

// ---------- HUD ----------
const hudCache = {};
function setText(key, node, v) { if (hudCache[key] !== v) { hudCache[key] = v; node.textContent = v; } }
function updateHud() {
  if (ui.phase === "scare") return;
  setText("f", el.flies, String(g.collected));
  setText("t", el.time, String(Math.floor(g.time)));
  setText("s", el.shells, String(g.shells));
  setText("g", el.gun, R.weapons[g.cur].name);
  setText("e", el.eyes, g.eyesClosed ? "KAPALI" : "açık");
  const dk = Math.min(1, g.dry / R.eyes.dryMax);
  const w = (dk * 100).toFixed(0) + "%";
  if (hudCache.d !== w) { hudCache.d = w; el.dry.style.width = w; el.dry.style.background = g.dry >= R.eyes.dryWarn ? "#d04030" : "#6fb283"; }
  swapBtn.classList.toggle("hidden", g.owned.length < 2);
}

// ---------- Ana döngü ----------
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  ui.time = now / 1000;
  if (avatarR && ui.phase === "menu" && !loginView.classList.contains("hidden")) avatarR.renderAvatar(ui.time);

  if (g && renderer) {
    if (ui.phase === "play") {
      // göz girdisi (kamera ya da elle)
      if (!bot) {
        if (ui.mode === "camera") eyesT.read(video); else eyesT.set(ui.keys.eye || ui.btnEye);
      }
      acc += dt * ui.speed;
      let n = 0, first = true;
      while (acc >= STEP && n++ < 10 * ui.speed && g.state === "play") {
        step(g, STEP, bot ? bot(STEP) : humanInput(first));
        first = false; acc -= STEP;
        onEvents();
      }
      if (ui.phase === "menu") { ui.lid = 0; ui.flick = 1; renderer.render(g, fx()); requestAnimationFrame(frame); return; }   // kazanıldı: menü açıldı
      adaptQuality(dt);
      ui.lid += ((g.eyesClosed ? 1 : 0) - ui.lid) * Math.min(1, dt * 22);
      if (Math.random() < 0.02 + g.danger * 0.1) ui.dip = 0.35 + Math.random() * 0.4;
      ui.dip *= Math.pow(0.02, dt);
      ui.flick = (0.9 + 0.06 * Math.sin(ui.time * 13) + 0.04 * Math.sin(ui.time * 31.7)) * (1 - ui.dip);
      for (const p of ui.puffs) p.t += dt; ui.puffs = ui.puffs.filter((p) => p.t < 0.7);
      A.heartbeat(dt, g.danger);
      updateHud();
      if (ui.phase === "play") renderer.render(g, fx());
      else renderer.renderScare(g, fx());
    } else if (ui.phase === "scare") {
      ui.scareT += dt;
      if (!ui.scareHit && ui.scareT >= 0.55) { ui.scareHit = true; A.playScream(); safeVibrate([150, 40, 200, 40, 400]); }   // göz kapakları açıldığı an
      renderer.renderScare(g, fx());
      if (ui.scareT > R.scare.seconds) endGame(false);
    } else {
      // menü: arka planda karanlık sahne
      ui.lid = 0; ui.flick = 0.85 + 0.1 * Math.sin(ui.time * 9);
      g.yaw += dt * 0.15;
      renderer.render(g, fx());
    }
  }
  requestAnimationFrame(frame);
}
// Kare süresi uzun sürerse iç çözünürlüğü kademeli düşür (yavaş tabletler için)
let ema = 1 / 60, slowFor = 0;
function adaptQuality(dt) {
  ema += (dt - ema) * 0.05;
  slowFor = ema > 0.034 ? slowFor + dt : 0;
  if (slowFor > 2 && (renderer.quality || 1) > 0.5) { renderer.quality = Math.max(0.5, (renderer.quality || 1) - 0.15); renderer.resize(); slowFor = 0; ema = 1 / 60; }
}
const fx = () => ({ time: ui.time, lid: ui.lid, flick: ui.flick, hurt: ui.hurt, puffs: ui.puffs, scareT: ui.scareT });

// ---------- Hesap ----------
function showView() {
  const me = auth.current();
  loginView.classList.toggle("hidden", !!me);
  mainView.classList.toggle("hidden", !me);
  window.GAME.me = me;
  if (!me) return;
  const st = auth.stats();
  ui.best = st.best;
  $("who").textContent = me.guest ? "Misafir" : me.name;
  $("statline").textContent = st.games ? `· ${st.wins} galibiyet / ${st.games} oyun · rekor ${st.best ? st.best + " sn" : "-"}` : "· henüz oyun yok";
}
function setMode(reg) {
  regMode = reg;
  tabLogin.classList.toggle("on", !reg); tabReg.classList.toggle("on", reg);
  pass2In.classList.toggle("hidden", !reg);
  passIn.autocomplete = reg ? "new-password" : "current-password";
  authBtn.textContent = reg ? "Hesap oluştur" : "Giriş yap";
  authMsg.textContent = "";
}
tabLogin.addEventListener("click", () => setMode(false));
tabReg.addEventListener("click", () => setMode(true));
authForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  authBtn.disabled = true; authMsg.className = "authmsg"; authMsg.textContent = "…";
  try {
    const r = regMode ? await auth.register(userIn.value, passIn.value, pass2In.value) : await auth.login(userIn.value, passIn.value);
    if (!r.ok) { authMsg.textContent = r.error; }
    else { passIn.value = pass2In.value = ""; authMsg.textContent = ""; showView(); }
  } catch (err) { authMsg.textContent = err.message || String(err); }
  authBtn.disabled = false;
});
$("guestBtn").addEventListener("click", () => { auth.guest(); showView(); });
$("logout").addEventListener("click", () => { auth.logout(); resultEl.textContent = ""; setMode(false); showView(); });

// ---------- Butonlar ----------
async function startCamera() {
  startBtn.disabled = true;
  A.initAudio();
  setStatus("Yüz modeli yükleniyor…");
  try {
    await loadLandmarker();
    setStatus("Kamera izni bekleniyor…");
    await openCamera(video);
    video.style.display = "block";
    ui.mode = "camera";
    startGame();
  } catch (err) {
    console.error(err);
    startBtn.disabled = false;
    setStatus("Kamera açılamadı: " + (err && err.message ? err.message : err) + " — kamerasız modu deneyebilirsin.");
  }
}
startBtn.addEventListener("click", () => { if (ui.mode === "camera") startGame(); else startCamera(); });
keyBtn.addEventListener("click", () => { ui.mode = "keyboard"; video.style.display = "none"; startGame(); });

// ---------- Hata ayıklama: galeri ----------
function galleryGame(page) {
  const gg = createGame(1, R);
  const S = 40, map = new Uint8Array(S * S);
  for (let i = 0; i < S; i++) { map[i] = map[(S - 1) * S + i] = map[i * S] = map[i * S + S - 1] = 1; }
  Object.assign(gg, { map, S, props: [], enemies: [], flies: [], boxes: [], gunItems: [], lights: [], px: 4, py: 20, yaw: 0 });
  const propKinds = Object.keys(R.props.scale);
  const items = [];
  if (page === 0) for (const k of propKinds.slice(0, 10)) items.push(["prop", k]);
  if (page === 1) for (const k of propKinds.slice(10)) items.push(["prop", k]);
  if (page === 2) { for (const k of Object.keys(R.enemies.types)) items.push(["enemy", k]); items.push(["box"]); items.push(["fly"]); }
  if (page === 3) for (const k of Object.keys(R.weapons).filter((k) => R.weapons[k].model)) items.push(["gun", k]);
  if (page === 4) { items.push(["enemy", "witch"]); items.push(["player", "Hazmat"]); items.push(["enemy", "jack"]); }
  const n = items.length;
  items.forEach((it, i) => {
    const a = (n === 1 ? 0 : (i / (n - 1) - 0.5)) * 1.0, d = 2.6;
    const x = gg.px + Math.cos(a) * d, y = gg.py + Math.sin(a) * d;
    if (it[0] === "prop") gg.props.push({ kind: it[1], x, y, yaw: Math.PI + a });
    if (it[0] === "enemy") gg.enemies.push({ id: i, type: it[1], x, y, hp: 1, stun: 0, alive: true, yaw: Math.PI + a, walk: 0, hit: 0 });
    if (it[0] === "box") gg.boxes.push({ x, y, taken: false, ph: 0 });
    if (it[0] === "fly") gg.flies.push({ x, y, taken: false, ph: 0 });
    if (it[0] === "player") gg.players.push({ id: "p" + i, name: it[1], x, y, yaw: Math.PI + a, walk: 1.4, moving: 0.8 });
    if (it[0] === "gun") gg.gunItems.push({ x, y, taken: false, ph: 0, weapon: it[1] });
  });
  gg.lights = gg.props.filter((p) => R.props.lights[p.kind]).map((p) => ({ x: p.x, y: p.y, ...R.props.lights[p.kind] }));
  return gg;
}

// ---------- Açılış ----------
async function boot() {
  setStatus("Modeller yükleniyor…");
  startBtn.disabled = keyBtn.disabled = true;
  const models = await loadModels("models/");
  renderer = new Renderer(canvas, models);
  renderer.rulesRef = R;
  avatarR = new Renderer($("avatar"), models, { size: [120, 160] }); avatarR.rulesRef = R;
  showView();
  addEventListener("resize", () => renderer.resize());
  startBtn.disabled = keyBtn.disabled = false;
  setStatus("Kamera görüntüsü hiçbir yere gönderilmez, her şey cihazında çalışır.");
  const seed = newSeed();
  g = createGame(seed, R);

  if (Q.has("gallery")) {
    g = galleryGame(Number(Q.get("gallery")) || 0);
    menuEl.classList.add("off");
    for (let i = 0; i < 2; i++) renderer.render(g, { time: 3, lid: 0, flick: 1, puffs: [] });
    $("debuglog").textContent = `gallery ${Q.get("gallery")} props=${g.props.length} enemies=${g.enemies.length}`;
    window.__ready = true;
    return;
  }
  if (Q.has("players")) {      // hata ayıklama: yakınlara N sahte oyuncu koy (çok oyunculu önizlemesi)
    const n = Number(Q.get("players")) || 2;
    for (let i = 0; i < n; i++) setPlayer(g, { id: "bot" + i, name: ["Ayşe", "Kaan", "Zeynep", "Mert"][i % 4], x: 1.5 + (i % 2) * 0.0 + 1.6 + i, y: 1.5, yaw: Math.PI / 2 + i, walk: i * 2, moving: i % 2 });
  }
  if (Q.has("sim")) {
    // bot N saniye oynar, son durum çizilir (headless ekran görüntüsü için)
    const secs = Number(Q.get("sim")) || 30;
    const b = makeBot(g, { rand: rng(seed * 7919 + 1) });
    while (g.state === "play" && g.time < secs) { step(g, STEP, b(STEP)); onEvents(); }
    ui.mode = "keyboard"; ui.phase = "play"; ui.flick = 1;
    menuEl.classList.add("off"); hudEl.style.display = "flex";
    if (Q.has("closed")) ui.lid = 1;
    if (g.state === "dead") { enterScare(); ui.scareT = Number(Q.get("scareT") || 0.5); }
    updateHud();
    if (ui.phase === "scare") renderer.renderScare(g, fx()); else { renderer.render(g, fx()); renderer.render(g, fx()); }
    const alive = g.enemies.filter((e) => e.alive).length;
    $("debuglog").textContent = `seed=${seed} state=${g.state} t=${g.time.toFixed(1)} flies=${g.collected}/${R.goal.flies} shells=${g.shells} gun=${g.cur} kills=${g.kills} alive=${alive}`;
    window.__ready = true;
    return;
  }
  if (Q.has("scare")) {
    // en yakın gölgeyi yanımıza getir, yakalansın, sahnenin ortasını çiz
    ui.mode = "keyboard";
    const e = g.enemies[0];
    e.x = g.px + 0.3; e.y = g.py; g.yaw = 0;
    step(g, STEP, { eyes: true });
    enterScare(); ui.scareT = Number(Q.get("scare")) || 0.5;
    menuEl.classList.add("off");
    renderer.renderScare(g, fx());
    $("debuglog").textContent = `scare state=${g.state}`;
    window.__ready = true;
    return;
  }
  if (Q.has("play") || Q.has("autoplay")) { ui.mode = "keyboard"; startGame(seed); }
  window.__ready = true;
  requestAnimationFrame(frame);
}
boot().catch((e) => { console.error(e); setStatus("Başlatılamadı: " + e.message); });
