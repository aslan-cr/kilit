// Karanlık Bataklık: giriş noktası. Sim (sim.js) + çizici (render.js) + girdiler + ses + göz algılama.
// Hata ayıklama kancaları: ?seed=N  ?play  ?sim=N (bot N sn oynar, son kare çizilir)  ?autoplay&speed=4
//                          ?scare  ?gallery=0..3  ?lobby&server=127.0.0.1:8080 (lobiye doğrudan gir)  ?r.enemies.count=3 (rules.js'teki sayıyı değiştir)
import { RULES, applyOverrides } from "./rules.js";
import { createGame, step, rng, setPlayer } from "./sim.js";
import { makeBot } from "./bot.js";
import { Renderer, loadModels } from "./render.js";
import * as A from "./audio.js";
import { makeEyeTracker, loadLandmarker, openCamera, landmarkerSource } from "./eyes.js";
import { ruleLines, HINT_FIRST } from "./texts.js";
import { createAuth } from "./auth.js";
import { createLobby, stepLobby, applySnapshot, smoothPlayers, updateSigns } from "./lobby.js";
import { connectLobby, connectLocal, normalizeUrl } from "./net.js";
import { cabin } from "./rooms.js";

const Q = new URLSearchParams(location.search);
const R = applyOverrides(RULES, location.search);
const STEP = 1 / 60;

const $ = (id) => document.getElementById(id);
const canvas = $("game"), video = $("cam"), touchLayer = $("touch"), joyEl = $("joy"), knobEl = $("knob");
const hudEl = $("hud"), msgEl = $("msg"), eyeBtn = $("eyeBtn"), fireBtn = $("fireBtn"), swapBtn = $("swapBtn"), lightBtn = $("lightBtn");
const menuEl = $("menu"), resultEl = $("result"), startBtn = $("start"), keyBtn = $("keyboard"), statusEl = $("status");
const guestBtn = $("guestBtn");
const el = { coins: $("coins"), flies: $("flies"), need: $("need"), time: $("time"), shells: $("shells"), gun: $("gun"), eyes: $("eyes"), dry: $("dryFill"), dryBox: $("dry") };
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
  btnEye: false, btnFire: false, tapFire: false, swap: false, light: false, lookAcc: 0,
  best: 0,
  speed: Math.max(1, Number(Q.get("speed") || 1)),
};
let g = null, renderer = null, bot = null, acc = 0, last = performance.now();
const eyesT = makeEyeTracker(R);
// Lobi / çok oyunculu durum
const lobbyBar = $("lobbyBar"), lobbyInfo = $("lobbyInfo"), lobbyExit = $("lobbyExit");
const serverIn = $("serverUrl"), useCam = $("useCam"), lobbyBtn = $("lobbyBtn");
const mp = { net: null, id: null, lobby: null, snap: null, room: -1, inGame: false, sendT: 0 };
window.GAME = { get mp() { return mp; }, get g() { return g; }, get renderer() { return renderer; }, R, ui, fx: () => fx() };

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
    case "KeyL": if (down) ui.light = true; break;
  }
}

// ---------- Girdiler: dokunma ----------
// Sol yarı: parmak nerede değerse joystick orada belirir, uzaklık sınırı yoktur.
// Sağ yarı: yalnızca ekranı (bakışı) döndürür, hareket ettirmez. Kısa dokunuş = ateş.
const joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 };
const look = { id: null, x: 0, y: 0, x0: 0, y0: 0, t0: 0, moved: 0 };
const half = () => (window.innerWidth || 800) / 2;
const isLive = () => ui.phase === "play" || ui.phase === "lobby";

touchLayer.addEventListener("pointerdown", (e) => {
  e.preventDefault();
  if (!isLive()) return;
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
    if (e.clientX >= half() && isLive()) ui.lookAcc += (e.clientX - look.x) * R.player.lookSens;
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
holdButton(lightBtn, () => { ui.light = true; }, () => {});

function resetTouch() {
  joy.id = null; look.id = null; joyEl.classList.remove("on");
  ui.btnEye = ui.btnFire = ui.tapFire = ui.swap = ui.light = false; ui.lookAcc = 0;
  padEdges.rt = padEdges.lb = padEdges.rb = false;   // menüde basılmış eski tuşlar oyuna taşınmasın
  for (const b of [eyeBtn, fireBtn, swapBtn, lightBtn]) b.classList.remove("down");
}

// ---------- Girdiler: Xbox kontrolcüsü (Gamepad API, standart eşleme) ----------
// Sol çubuk: yürü · Sağ çubuk: bak · RT: ateş / (fenerdeyken) ışığı aç-kapat · RB: silah <-> fener
// LB: sıradaki silah · LT (basılı): gözü kapat · A (menüde): başla
const PAD_DEAD = 0.18;
const padEdges = { rt: false, lb: false, rb: false, a: false };
const padPrev = { rt: false, lb: false, rb: false, a: false };
const dz = (v) => (Math.abs(v) < PAD_DEAD ? 0 : (v - Math.sign(v) * PAD_DEAD) / (1 - PAD_DEAD));
function activePad() {
  const list = navigator.getGamepads ? navigator.getGamepads() : [];
  for (const p of list) if (p && p.connected) return p;
  return null;
}
function pollPad() {                       // her kare bir kez: tuş kenarlarını (yeni basış) yakalar
  const p = activePad();
  if (!p) { padPrev.rt = padPrev.lb = padPrev.rb = padPrev.a = false; return null; }
  const b = (i) => !!(p.buttons[i] && (p.buttons[i].pressed || p.buttons[i].value > 0.5));
  const now = { rt: b(7), lb: b(4), rb: b(5), a: b(0) };
  for (const k of Object.keys(now)) { if (now[k] && !padPrev[k]) padEdges[k] = true; padPrev[k] = now[k]; }
  return { p, now };
}
let padState = null;
function readPad() {
  if (!padState) return null;
  const { p, now } = padState;
  return {
    fwd: -dz(p.axes[1] || 0), str: dz(p.axes[0] || 0), turn: dz(p.axes[2] || 0),
    rt: now.rt, rtEdge: padEdges.rt, lbEdge: padEdges.lb, rbEdge: padEdges.rb,
    lt: !!(p.buttons[6] && (p.buttons[6].pressed || p.buttons[6].value > 0.5)),
  };
}
addEventListener("gamepadconnected", () => { if (ui.phase === "menu") setStatus("Xbox kontrolcüsü bağlı. A ile başla."); });

// ---------- Girdi -> sim ----------
let joyMag = 0;
function humanInput(first) {
  const k = ui.keys;
  let fwd = (k.w ? 1 : 0) - (k.s ? 1 : 0), str = (k.d ? 1 : 0) - (k.a ? 1 : 0);
  if (joy.id !== null) {
    const dx = joy.x - joy.ox, dy = joy.y - joy.oy, d = Math.hypot(dx, dy), DEAD = 10, FULL = 60;
    if (d > DEAD) { const mag = Math.min(1, (d - DEAD) / (FULL - DEAD)); fwd += (-dy / d) * mag; str += (dx / d) * mag; }
  }
  const pad = readPad();
  if (pad) { fwd += pad.fwd; str += pad.str; }
  fwd = Math.max(-1, Math.min(1, fwd)); str = Math.max(-1, Math.min(1, str));
  const inLight = !!g && g.slot === "light";
  const input = {
    fwd, str,
    turn: ((k.right ? 1 : 0) - (k.left ? 1 : 0)) * R.player.turnKeys + (pad ? pad.turn * R.player.turnKeys * 1.6 : 0),
    yaw: first ? ui.lookAcc : 0,
    eyes: eyesT.closed(),
    // RT: silah elindeyken basılı tutunca ateş; fener elindeyken her basışta ışığı açar/kapatır
    fire: k.fire || ui.btnFire || ui.tapFire || !!(pad && pad.rt && !inLight),
    beamToggle: !!(pad && pad.rtEdge && inLight),
    switchWeapon: ui.swap || !!(pad && pad.lbEdge),     // LB: sıradaki silaha geç
    light: ui.light || !!(pad && pad.rbEdge),           // RB: silah <-> el feneri
  };
  if (first) { ui.lookAcc = 0; ui.tapFire = false; ui.swap = false; ui.light = false; if (pad) { pad.rtEdge = pad.lbEdge = pad.rbEdge = false; padEdges.rt = padEdges.lb = padEdges.rb = false; } }
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
  lobbyBar.classList.add("hidden");
  startBtn.disabled = false;
  hudEl.style.display = "flex";
  const manual = ui.mode === "keyboard";
  eyeBtn.classList.toggle("hidden", !manual);
  fireBtn.classList.remove("hidden"); lightBtn.classList.remove("hidden"); updateSwapBtn();
  el.dryBox.classList.remove("hidden");
  showMsg(HINT_FIRST, 4200);
  updateHud(true);
}

function endGame(win) {
  ui.phase = "menu";
  hudEl.style.display = "none";
  for (const b of [eyeBtn, fireBtn, swapBtn, lightBtn]) b.classList.add("hidden");
  msgEl.classList.remove("on");
  resetTouch();
  menuEl.classList.remove("off");
  startBtn.textContent = ui.mode === "camera" ? "Tekrar oyna" : "Kamerayı aç ve başla";
  if (win) {
    const t = Math.round(g.time), before = auth.stats().best;
    const st = auth.recordGame({ win: true, time: g.time, kills: g.kills, coins: g.money });
    let line = `Kurtuldun! Süre: ${t} sn, ${g.kills} gölge vurdun, ${g.money} para topladın.`;
    line += !before || t < before ? " Yeni rekor!" : ` Rekor: ${before} sn.`;
    ui.best = st.best;
    resultEl.style.color = "#b6f0c0"; resultEl.textContent = line;
  } else {
    auth.recordGame({ win: false, time: g.time, kills: g.kills, coins: g.money });
    resultEl.style.color = "#ffb4a8";
    resultEl.textContent = `Seni yakaladılar. ${g.collected}/${R.goal.flies} ışık böceği, ${g.money} para toplamıştın.`;
  }
  showView();
  setStatus(ui.mode === "camera" ? "Tekrar denemek için butona bas." : "Tekrar denemek için bir mod seç.");
  if (mp.net && mp.inGame) {                          // çok oyunculu: sonuç yazısı kalır, odanın kabinine geri dön
    mp.net.send({ t: "back" });
    const line = resultEl.textContent;
    returnToLobby();
    showMsg(line, 5000);
  }
}

function enterScare() {
  ui.phase = "scare"; ui.scareT = 0; ui.scareHit = false; resetTouch();
  hudEl.style.display = "none"; msgEl.classList.remove("on");
  for (const b of [eyeBtn, fireBtn, swapBtn, lightBtn]) b.classList.add("hidden");
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
      case "coin": A.playCoin(); showMsg(`🪙 +${ev.value} para (toplam ${ev.n})`, 1600); break;
      case "ammo": A.playPickup(); showMsg(`Mermi kutusu: ${ev.n} mermi.`, 1600); break;
      case "gun": A.playGunPick(); showMsg(`Yeni silah: ${R.weapons[ev.weapon].name}`, 2400); break;
      case "switch": A.playGunPick(); showMsg(R.weapons[ev.weapon].name, 1200); break;
      case "lightSlot": A.playGunPick(); showMsg("El feneri — ışığa koşan gölgelere dikkat. Fenerdeyken ateş edemezsin. RT: aç/kapat, RB: silaha dön.", 2600); break;
      case "beam": A.playEmpty(); showMsg(ev.on ? "Fener açık" : "Fener kapalı", 900); break;
      case "forcedBlink": A.playForcedBlink(); showMsg("Gözlerin yandı! Kırpmak zorundasın, gölgeler geliyor.", 2600); break;
      case "caught": enterScare(); A.playScareStart(); break;
      case "win": endGame(true); break;
    }
  }
  g.events.length = 0;
}
function safeVibrate(p) { if (navigator.vibrate) { try { navigator.vibrate(p); } catch { /* yoksay */ } } }

function updateSwapBtn() { if (g) swapBtn.classList.toggle("hidden", !(g.owned.length > 1 || g.slot === "light")); }

// ---------- HUD ----------
const hudCache = {};
function setText(key, node, v) { if (hudCache[key] !== v) { hudCache[key] = v; node.textContent = v; } }
function updateHud() {
  if (ui.phase === "scare") return;
  setText("c", el.coins, String(g.money || 0));
  setText("f", el.flies, String(g.collected));
  setText("t", el.time, String(Math.floor(g.time)));
  setText("s", el.shells, String(g.shells));
  setText("g", el.gun, g.slot === "light" ? "Fener" : R.weapons[g.cur].name);
  setText("e", el.eyes, g.eyesClosed ? "KAPALI" : "açık");
  const dk = Math.min(1, g.dry / R.eyes.dryMax);
  const w = (dk * 100).toFixed(0) + "%";
  if (hudCache.d !== w) { hudCache.d = w; el.dry.style.width = w; el.dry.style.background = g.dry >= R.eyes.dryWarn ? "#d04030" : "#6fb283"; }
  updateSwapBtn();
}

// ---------- Ana döngü ----------
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  ui.time = now / 1000;
  padState = pollPad();
  if (padState && padEdges.a && ui.phase === "menu") {            // menüde A: misafir girişi / kamerasız başlat
    padEdges.a = false;
    if (!loginView.classList.contains("hidden")) guestBtn.click();
    else if (!mainView.classList.contains("hidden")) keyBtn.click();
  }
  padEdges.a = false;
  if (avatarR && ui.phase === "menu" && !loginView.classList.contains("hidden")) avatarR.renderAvatar(ui.time);

  if (g && renderer) {
    if (ui.phase === "play") {
      // göz girdisi (kamera ya da elle)
      if (!bot) {
        if (ui.mode === "camera") eyesT.read(video); else eyesT.set(ui.keys.eye || ui.btnEye || !!(padState && padState.p.buttons[6] && (padState.p.buttons[6].pressed || padState.p.buttons[6].value > 0.5)));
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
      if (mp.inGame) { smoothPlayers(g, dt); netTick(dt); }
      ui.lid += ((g.eyesClosed ? 1 : 0) - ui.lid) * Math.min(1, dt * 22);
      if (Math.random() < 0.02 + g.danger * 0.1) ui.dip = 0.35 + Math.random() * 0.4;
      ui.dip *= Math.pow(0.02, dt);
      ui.flick = (0.9 + 0.06 * Math.sin(ui.time * 13) + 0.04 * Math.sin(ui.time * 31.7)) * (1 - ui.dip);
      for (const p of ui.puffs) p.t += dt; ui.puffs = ui.puffs.filter((p) => p.t < 0.7);
      A.heartbeat(dt, g.danger);
      updateHud(); updateEyeDbg();
      if (ui.phase === "play") renderer.render(g, fx());
      else renderer.renderScare(g, fx());
    } else if (ui.phase === "lobby") {
      ui.lid = 0; ui.flick = 1;
      acc += dt; let n = 0, first = true;
      while (acc >= STEP && n++ < 10) { stepLobby(g, STEP, humanInput(first)); first = false; acc -= STEP; }
      if (ui.mode === "camera" && !lobbySet.classList.contains("hidden")) eyesT.read(video);
      smoothPlayers(g, dt); updateSigns(g); lobbyEvents(); netTick(dt); updateLobbyBar(); updateEyeDbg();
      renderer.render(g, fx());
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
// Oyun açılınca / giriş yapınca doğrudan lobiye (?nolobby ile kapatılır: testler)
function autoLobby() { if (!Q.has("nolobby") && auth.current() && !mp.net) enterLobby(); }
function showView() {
  const me = auth.current();
  loginView.classList.toggle("hidden", !!me);
  mainView.classList.toggle("hidden", !me);
  window.GAME.me = me;
  if (!me) return;
  const st = auth.stats();
  ui.best = st.best;
  $("who").textContent = me.guest ? "Misafir" : me.name;
  $("statline").textContent = st.games ? `· ${st.wins} galibiyet / ${st.games} oyun · rekor ${st.best ? st.best + " sn" : "-"} · 🪙 ${st.coins || 0}` : "· henüz oyun yok";
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
    else { passIn.value = pass2In.value = ""; authMsg.textContent = ""; showView(); autoLobby(); }
  } catch (err) { authMsg.textContent = err.message || String(err); }
  authBtn.disabled = false;
});
guestBtn.addEventListener("click", () => { auth.guest(); showView(); autoLobby(); });
$("logout").addEventListener("click", () => { auth.logout(); resultEl.textContent = ""; setMode(false); showView(); });

// ---------- Lobi (çok oyunculu) ----------
// Oyun açılınca doğrudan lobiye girilir. Lobide dolaşırsın; kuzeydeki 4 kabinden birine girince o odaya katılırsın
// (oda başına en fazla 10 kişi). Odaya girince sayaç başlar; bitince oyun OTOMATİK başlar, odadakiler aynı labirentte
// (aynı seed) başlar ve birbirini görür. Sunucu adresi yoksa ya da bağlanılamazsa lobi bu cihazda çevrimdışı çalışır.
// Gölgeler henüz her oyuncuda ayrı hesaplanır (ağ üzerinden eşitlenmiyor).
const settings = { cam: (safeGet("gk_cam") ?? "1") === "1", server: Q.get("server") || safeGet("gk_server") || R.lobby.net.url || "" };
const lobbySet = $("lobbySet"), netState = $("netState"), camState = $("camState"), eyeDbg = $("eyeDbg");
useCam.checked = settings.cam; serverIn.value = settings.server;

async function ensureCamera() {
  if (ui.mode === "camera" && video.srcObject) return;
  camState.textContent = "Yüz modeli yükleniyor…"; setStatus("Yüz modeli yükleniyor…");
  await loadLandmarker();
  camState.textContent = "Kamera izni bekleniyor…"; setStatus("Kamera izni bekleniyor…");
  await openCamera(video);
  video.style.display = "block"; ui.mode = "camera";
}
async function applyCamera() {
  if (settings.cam) {
    try { await ensureCamera(); camState.textContent = `Kamera açık (${landmarkerSource || "?"} model). Gözünü kapat: yukarıdaki sayılar yükselmeli.`; return; }
    catch (err) {
      console.error(err);
      settings.cam = false; useCam.checked = false; safeSet("gk_cam", "0");
      camState.textContent = "Kamera açılamadı: " + (err && err.message ? err.message : err);
      showMsg("Kamera açılamadı, kamerasız devam ediliyor (ayarlardan tekrar dene).", 4000);
    }
  }
  ui.mode = "keyboard"; video.style.display = "none";
  if (!camState.textContent.startsWith("Kamera açılamadı")) camState.textContent = "Kamera kapalı: gözünü GÖZÜ KAPAT düğmesiyle (Boşluk) kapatırsın.";
}
function updateEyeDbg() {
  const on = ui.mode === "camera" && (ui.phase === "play" || (ui.phase === "lobby" && !lobbySet.classList.contains("hidden")));
  eyeDbg.classList.toggle("hidden", !on);
  if (!on) return;
  const t = `👁 sol ${eyesT.left.toFixed(2)} · sağ ${eyesT.right.toFixed(2)} · ${eyesT.noFace ? "YÜZ GÖRÜNMÜYOR" : eyesT.closed() ? "KAPALI" : "açık"}`;
  if (eyeDbg.textContent !== t) eyeDbg.textContent = t;
}

function onSnap(m) {
  mp.snap = m;
  const me = m.players.find((p) => p.id === mp.id);
  mp.room = me ? me.room : -1;
  if (mp.inGame && g) applySnapshot(g, m, mp.id, (p) => p.g && p.room === mp.room);
  else if (mp.lobby) applySnapshot(mp.lobby, m, mp.id);
}
function startNetGame(m) {
  if (!mp.net || mp.inGame || (ui.phase !== "lobby")) return;
  mp.inGame = true; mp.room = m.room;
  lobbyBar.classList.add("hidden"); lobbySet.classList.add("hidden");
  startGame(m.seed);
}
function returnToLobby() {
  mp.inGame = false;
  g = mp.lobby;
  if (mp.room >= 0) { const c = cabin(R, mp.room); Object.assign(g, { px: c.cx, py: c.cy }); }   // oyundan dönünce odanın kabinine
  Object.assign(g, { myRoom: mp.room, state: "lobby" });
  if (mp.snap) applySnapshot(g, mp.snap, mp.id);
  ui.phase = "lobby"; ui.lid = 0; ui.flick = 1;
  menuEl.classList.add("off"); hudEl.style.display = "none";
  for (const b of [eyeBtn, fireBtn, swapBtn, lightBtn]) b.classList.add("hidden");
  lobbyBar.classList.remove("hidden");
  resetTouch();
}
function leaveLobby(statusText) {
  if (mp.net) { const n = mp.net; mp.net = null; n.close(); }
  Object.assign(mp, { id: null, lobby: null, snap: null, room: -1, inGame: false });
  lobbyBar.classList.add("hidden"); lobbySet.classList.add("hidden"); lobbyBtn.disabled = false; eyeDbg.classList.add("hidden");
  g = createGame(newSeed(), R);
  ui.phase = "menu"; ui.lid = 0; resetTouch();
  menuEl.classList.remove("off");
  showView();
  if (statusText) setStatus(statusText);
}
function onNetClose() {
  if (!mp.net || mp.net.local) return;
  if (mp.inGame) { mp.net = null; mp.inGame = false; if (g) g.players = []; showMsg("Sunucu bağlantısı koptu, tek başına devam ediyorsun.", 4000); return; }
  netState.textContent = "Sunucu bağlantısı koptu — çevrimdışı lobi.";
  showMsg("Sunucu bağlantısı koptu, çevrimdışı lobiye geçildi.", 3500);
  connectNet().then(() => { returnToLobby(); mp.lobby.myRoom = -1; });
}
// Sunucuya (yoksa bu cihazdaki lobiye) bağlan
async function connectNet() {
  if (mp.net) { const n = mp.net; mp.net = null; n.close(); }
  Object.assign(mp, { id: null, lobby: null, snap: null, room: -1, inGame: false });
  const me = auth.current(), name = me ? me.name : "Misafir";
  const h = {
    onWelcome: (m) => { mp.id = m.id; mp.lobby = createLobby(R); mp.lobby.px = m.x; mp.lobby.py = m.y; },
    onSnap, onStart: startNetGame, onClose: onNetClose,
    onDeny: (m) => { if (ui.phase === "lobby" && g) { g.px = m.x; g.py = m.y; g.myRoom = -1; } showMsg(m.reason, 2200); },
    onErr: (t) => showMsg(t, 2600),
  };
  const url = normalizeUrl(settings.server);
  let note = "";
  if (url) {
    try { mp.net = await connectLobby(url, name, h); note = "Sunucuya bağlısın: " + url; }
    catch (e) { note = `Sunucuya bağlanılamadı (${e.message}) — çevrimdışı lobi.`; }
  } else note = "Çevrimdışı lobi (yalnızca sen). Başkalarıyla buluşmak için sunucu adresi gir.";
  if (!mp.net) mp.net = connectLocal(R, name, h);
  netState.textContent = note;
}
async function enterLobby() {
  lobbyBtn.disabled = true; A.initAudio();
  setStatus("Lobiye giriliyor…");
  await applyCamera();
  await connectNet();
  returnToLobby();
  mp.lobby.myRoom = -1;
  showMsg("Lobidesin. Bir odaya girmek için yukarıdaki kabinlerden birine yürü. ⚙ ayarlar yukarıda.", 4500);
}
function updateLobbyBar() {
  const m = mp.snap, n = m ? m.players.length : 1;
  const r = mp.room >= 0 && m ? m.rooms[mp.room] : null;
  const ln = m && m.lobby ? `Lobi ${m.lobby} · ` : "";
  const text = r ? `${ln}ODA ${mp.room + 1} · ${r.n}/${R.lobby.maxPerRoom} kişi · ${r.t !== null ? `oyun ${r.t} sn sonra başlıyor` : r.st === "playing" ? "oyun sürüyor" : "bekleniyor"}` : `${ln || "Lobi · "}${n}/${R.lobby.maxPlayers} oyuncu · bir odaya yürü (girince ${R.lobby.countdown} sn sayaç başlar)`;
  if (lobbyInfo.textContent !== text) lobbyInfo.textContent = text;
}
function lobbyEvents() {
  for (const e of g.lobbyEvents) {
    if (e.t === "denied") showMsg(e.reason, 2000);
    else if (e.t === "enter") showMsg(`Oda ${e.room + 1}'e girdin.`, 1800);
    else if (e.t === "exit") showMsg("Salona çıktın.", 1200);
  }
  g.lobbyEvents.length = 0;
}
function netTick(dt) {
  if (!mp.net || !mp.net.open || !(ui.phase === "lobby" || mp.inGame)) return;
  mp.sendT += dt;
  if (mp.sendT < 1 / R.lobby.sendHz) return;
  mp.sendT = 0;
  mp.net.send({ t: "pos", x: +g.px.toFixed(2), y: +g.py.toFixed(2), yaw: +g.yaw.toFixed(2), walk: +(g.bob || 0).toFixed(1), moving: +(g.moving || 0).toFixed(2) });
}
lobbyBtn.addEventListener("click", enterLobby);
lobbyExit.addEventListener("click", () => leaveLobby("Menüdesin."));
$("lobbyGear").addEventListener("click", () => lobbySet.classList.toggle("hidden"));
useCam.addEventListener("change", async () => { settings.cam = useCam.checked; safeSet("gk_cam", settings.cam ? "1" : "0"); await applyCamera(); });
$("serverGo").addEventListener("click", async () => {
  settings.server = serverIn.value.trim(); safeSet("gk_server", settings.server);
  netState.textContent = "Bağlanılıyor…";
  await connectNet(); returnToLobby(); mp.lobby.myRoom = -1;
});
addEventListener("pointerdown", () => A.initAudio(), { once: true });

// ---------- Butonlar ----------
async function startCamera() {
  startBtn.disabled = true;
  A.initAudio();
  try { await ensureCamera(); startGame(); }
  catch (err) {
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
  if (Q.has("lobby")) { if (!auth.current()) auth.guest(); showView(); requestAnimationFrame(frame); await enterLobby(); window.__ready = true; return; }
  if (!Q.has("play") && !Q.has("autoplay")) autoLobby();
  if (Q.has("play") || Q.has("autoplay")) { ui.mode = "keyboard"; startGame(seed); if (Q.has("coin") && g.coins[0]) { const c = g.coins[0]; g.px = c.x - 1.2; g.py = c.y; g.ang = 0; } if (Q.has("hold")) { const h = Q.get("hold"); if (h === "light") { g.slot = "light"; g.lightOn = true; } else if (R.weapons[h]) { g.cur = h; if (!g.owned.includes(h)) g.owned.push(h); } if (Q.has("flash")) g.flashModel = Q.get("flash"); if (Q.has("low")) { g.sw = { t: 0.01, to: { slot: g.slot, weapon: g.cur }, applied: true }; g.raise = Number(Q.get("low")); } } }
  window.__ready = true;
  requestAnimationFrame(frame);
}
boot().catch((e) => { console.error(e); setStatus("Başlatılamadı: " + e.message); });
