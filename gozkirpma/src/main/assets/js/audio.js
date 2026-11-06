// Prosedürel ses (WebAudio): uğultu, rüzgâr, kalp atışı, adımlar, silah sesleri, çığlık.
let AC = null, master = null, beatT = 0, noiseBuf = null;

export function initAudio() {
  if (AC) { if (AC.state === "suspended") AC.resume(); return; }
  try {
    AC = new (window.AudioContext || window.webkitAudioContext)();
    master = AC.createGain();
    master.gain.value = 0.9;
    master.connect(AC.destination);
    for (const [f, type, g] of [[38, "sawtooth", 0.035], [41.5, "sine", 0.06], [57, "triangle", 0.02]]) {
      const o = AC.createOscillator(); o.type = type; o.frequency.value = f;
      const lp = AC.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 160;
      const gn = AC.createGain(); gn.gain.value = g;
      o.connect(lp); lp.connect(gn); gn.connect(master); o.start();
    }
    const len = AC.sampleRate * 2;
    noiseBuf = AC.createBuffer(1, len, AC.sampleRate);
    const ch = noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) ch[i] = Math.random() * 2 - 1;
    const src = AC.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
    const bp = AC.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 380; bp.Q.value = 0.7;
    const wg = AC.createGain(); wg.gain.value = 0.025;
    const lfo = AC.createOscillator(); lfo.frequency.value = 0.12;
    const lg = AC.createGain(); lg.gain.value = 0.015;
    lfo.connect(lg); lg.connect(wg.gain); lfo.start();
    src.connect(bp); bp.connect(wg); wg.connect(master); src.start();
  } catch { AC = null; }
}

function thump(vol, at = 0, f0 = 70, f1 = 34, dur = 0.2) {
  if (!AC) return;
  const t = AC.currentTime + at;
  const o = AC.createOscillator(); o.type = "sine";
  o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + dur * 0.7);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.012);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + dur + 0.03);
}

function noiseBurst(vol, dur, freq, type = "bandpass", at = 0, q = 0.7) {
  if (!AC) return;
  const len = Math.floor(AC.sampleRate * dur);
  const buf = AC.createBuffer(1, len, AC.sampleRate);
  const ch = buf.getChannelData(0);
  for (let i = 0; i < len; i++) ch[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 1.6);
  const s = AC.createBufferSource(); s.buffer = buf;
  const f = AC.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
  const g = AC.createGain(); g.gain.value = vol;
  s.connect(f); f.connect(g); g.connect(master); s.start(AC.currentTime + at);
}

export function heartbeat(dt, danger) {
  beatT -= dt;
  if (beatT > 0) return;
  beatT = 1.15 - 0.7 * danger;
  const v = 0.12 + 0.5 * danger;
  thump(v); thump(v * 0.65, 0.2);
}

export function playStep(near) {
  const v = Math.max(0, Math.min(0.55, 1.4 / (near + 0.5) - 0.1));
  if (v > 0.02) noiseBurst(v, 0.09, 140, "lowpass");
}

export function playPickup() {
  if (!AC) return;
  const t = AC.currentTime;
  const o = AC.createOscillator(); o.type = "sine";
  o.frequency.setValueAtTime(520, t); o.frequency.exponentialRampToValueAtTime(1040, t + 0.18);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.12, t + 0.03);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.4);
}

// Silah: gürleyen patlama + keskin çatırtı + alçak vuruş. Çifte namlu iki kez patlar.
export function playShot(weapon) {
  if (!AC) return;
  const big = weapon === "double" || weapon === "sawed";
  noiseBurst(big ? 1.0 : 0.85, big ? 0.55 : 0.4, 900, "lowpass");
  noiseBurst(0.6, 0.12, 3200, "highpass");
  thump(big ? 0.9 : 0.7, 0, 120, 28, big ? 0.35 : 0.25);
  if (weapon === "double") { noiseBurst(0.8, 0.45, 800, "lowpass", 0.07); thump(0.7, 0.07, 110, 30, 0.3); }
  // yankı
  noiseBurst(0.22, 0.9, 400, "lowpass", 0.12);
  // sürgü / kilit sesi
  setTimeout(() => { noiseBurst(0.18, 0.05, 2400, "bandpass", 0, 4); thump(0.15, 0.09, 220, 90, 0.08); }, weapon === "pump" ? 380 : 520);
}

export function playEmpty() { noiseBurst(0.22, 0.03, 3000, "bandpass", 0, 6); }
export function playHit() { noiseBurst(0.5, 0.18, 260, "lowpass"); thump(0.4, 0, 90, 40, 0.2); }
export function playKill() {
  if (!AC) return;
  noiseBurst(0.5, 0.7, 180, "lowpass");
  const t = AC.currentTime;
  const o = AC.createOscillator(); o.type = "sawtooth";
  o.frequency.setValueAtTime(220, t); o.frequency.exponentialRampToValueAtTime(45, t + 0.6);
  const g = AC.createGain();
  g.gain.setValueAtTime(0.18, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.65);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.7);
}
export function playGunPick() { playPickup(); setTimeout(() => noiseBurst(0.25, 0.05, 2000, "bandpass", 0, 4), 160); }
export function playForcedBlink() { thump(0.5, 0, 60, 30, 0.3); noiseBurst(0.25, 0.25, 500, "lowpass"); }

// Yakalanma: 1) kalp atışı susar, nefes + alçak vızıltı (0.55 sn) 2) playScream(): ani darbe + çığlık
export function playScareStart() {
  if (!AC) return;
  const t = AC.currentTime;
  // nefes: yavaşça yükselen bant geçiren gürültü
  const src = AC.createBufferSource(); src.buffer = noiseBuf; src.loop = true;
  const bp = AC.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 700; bp.Q.value = 2;
  const g = AC.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.35, t + 0.5); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
  src.connect(bp); bp.connect(g); g.connect(master); src.start(t); src.stop(t + 0.65);
  // yükselen gerilim tonu
  const o = AC.createOscillator(); o.type = "sawtooth";
  o.frequency.setValueAtTime(55, t); o.frequency.exponentialRampToValueAtTime(220, t + 0.55);
  const og = AC.createGain(); og.gain.setValueAtTime(0.0001, t); og.gain.exponentialRampToValueAtTime(0.12, t + 0.5); og.gain.exponentialRampToValueAtTime(0.0001, t + 0.58);
  o.connect(og); og.connect(master); o.start(t); o.stop(t + 0.6);
}

function distortion(amount = 40) {
  const ws = AC.createWaveShaper(), n = 256, c = new Float32Array(n);
  for (let i = 0; i < n; i++) { const x = (i * 2) / n - 1; c[i] = ((3 + amount) * x * 20 * (Math.PI / 180)) / (Math.PI + amount * Math.abs(x)); }
  ws.curve = c; return ws;
}

export function playScream() {
  if (!AC) return;
  const t = AC.currentTime;
  noiseBurst(1.0, 1.4, 2200, "highpass");
  noiseBurst(1.0, 0.5, 120, "lowpass");
  thump(1.0, 0, 90, 24, 0.7);                          // gövdeye çarpan alçak boom
  const ds = distortion(60);
  ds.connect(master);
  // üç katmanlı, hafif uyumsuz çığlık: yükselip titreyen
  for (const [f0, f1, det] of [[180, 880, 0], [190, 930, 1.04], [95, 440, 0.5]]) {
    const o = AC.createOscillator(); o.type = "sawtooth";
    o.frequency.setValueAtTime(f0, t + 0.02); o.frequency.exponentialRampToValueAtTime(f1, t + 0.45); o.frequency.exponentialRampToValueAtTime(f1 * 0.7, t + 1.6);
    const lfo = AC.createOscillator(); lfo.frequency.value = 22 + det * 6;
    const lg = AC.createGain(); lg.gain.value = f1 * 0.04; lfo.connect(lg); lg.connect(o.frequency); lfo.start(t); lfo.stop(t + 1.8);
    const g = AC.createGain();
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.28, t + 0.04); g.gain.setValueAtTime(0.28, t + 1.2); g.gain.exponentialRampToValueAtTime(0.0001, t + 1.8);
    o.connect(g); g.connect(ds); o.start(t); o.stop(t + 1.85);
  }
  // ikinci vuruş: sahne kararırken
  thump(0.8, 1.3, 70, 22, 0.5);
}
