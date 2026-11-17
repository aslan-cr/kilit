// Yakalanma sahnelerinin ses tasarımı. Hepsi WebAudio ile anında üretilir (ses dosyası yok, internetsiz çalışır).
// Katmanlar: et/kemik darbeleri, ıslak gurultular, kan fışkırması, damlalar, canavar kükremeleri (gırtlak filtreleriyle),
// nefes, kalp atışı, kulak çınlaması, sinematik vuruşlar; hepsi ortak bir yankı ve kompresörden geçer.
// makeSfx(ac, out, ambLP): ac canlı ya da OfflineAudioContext olabilir (tools/sfx-render.mjs sahneleri dosyaya kaydeder).
export function makeSfx(ac, out, ambLP = null) {
  const sr = ac.sampleRate;
  let seed = 12345;
  const rnd = () => { seed = (Math.imul(seed, 1664525) + 1013904223) | 0; return (seed >>> 8) / 16777216; };
  const R = (a, b) => a + (b - a) * rnd();

  // ---------- zincir: ses -> (boğuklaştırma) -> kompresör -> çıkış; yankı gönderimi ----------
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -18; comp.knee.value = 10; comp.ratio.value = 4.5; comp.attack.value = 0.003; comp.release.value = 0.22;
  const outG = ac.createGain(); outG.gain.value = 1.0;
  const lim = ac.createDynamicsCompressor();                         // son sınırlayıcı: kırpılma (cızırtı) olmasın
  lim.threshold.value = -4; lim.knee.value = 0; lim.ratio.value = 20; lim.attack.value = 0.001; lim.release.value = 0.1;
  comp.connect(outG); outG.connect(lim); lim.connect(out);
  const muffLP = ac.createBiquadFilter(); muffLP.type = "lowpass"; muffLP.frequency.value = 20000; muffLP.Q.value = 0.5;
  muffLP.connect(comp);
  const bus = ac.createGain(); bus.connect(muffLP);
  // yankı: taş koridor (erken yansımalar + 2.6 sn sönümlenen, yükseği yutulmuş kuyruk)
  const irLen = Math.floor(sr * 2.6), ir = ac.createBuffer(2, irLen, sr);
  for (let ch = 0; ch < 2; ch++) {
    const d = ir.getChannelData(ch); let lp = 0;
    for (let i = 0; i < irLen; i++) {
      const x = i / irLen, damp = 0.35 + 0.55 * x;                 // zamanla daha boğuk
      lp = lp * damp + (rnd() * 2 - 1) * (1 - damp);
      d[i] = lp * Math.pow(1 - x, 3.4) * 1.6;
    }
    for (let k = 0; k < 9; k++) { const at = Math.floor(sr * R(0.008, 0.07)); d[at] += R(-0.6, 0.6); }
  }
  const verb = ac.createConvolver(); verb.buffer = ir;
  const vret = ac.createGain(); vret.gain.value = 0.55; verb.connect(vret); vret.connect(muffLP);
  const send = ac.createGain(); send.connect(verb);

  const white = ac.createBuffer(1, sr * 3, sr);
  { const d = white.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = rnd() * 2 - 1; }
  const brown = ac.createBuffer(1, sr * 3, sr);
  { const d = brown.getChannelData(0); let b = 0; for (let i = 0; i < d.length; i++) { b = (b + 0.02 * (rnd() * 2 - 1)) / 1.02; d[i] = b * 3.5; } }

  const now = () => ac.currentTime;
  const route = (node, o = {}) => {
    let n = node;
    if (o.pan && ac.createStereoPanner) { const p = ac.createStereoPanner(); p.pan.value = o.pan; n.connect(p); n = p; }
    n.connect(bus);
    if (o.wet) { const w = ac.createGain(); w.gain.value = o.wet; n.connect(w); w.connect(send); }
  };
  // zarf: a sn'de tepeye, hold sn tut, rel sn'de sön
  const env = (gain, t, peak, a, hold, rel) => {
    gain.setValueAtTime(0.0001, t); gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a);
    gain.setValueAtTime(Math.max(0.0002, peak), t + a + hold); gain.exponentialRampToValueAtTime(0.0001, t + a + hold + rel);
    return t + a + hold + rel;
  };
  const src = (buf, t, end) => { const s = ac.createBufferSource(); s.buffer = buf; s.loop = true; s.start(t, R(0, 2)); s.stop(end + 0.05); return s; };

  // ---------- temel parçalar ----------
  function noise(at, dur, o = {}) {
    const t = now() + at, f = o.f || 1000, f2 = o.f2 || f;
    const s = src(o.brown ? brown : white, t, t + dur + (o.rel || 0.05));
    const fl = ac.createBiquadFilter(); fl.type = o.type || "bandpass"; fl.Q.value = o.q ?? 1;
    fl.frequency.setValueAtTime(f, t); fl.frequency.exponentialRampToValueAtTime(f2, t + dur);
    const g = ac.createGain();
    const a = o.a ?? 0.005, rel = o.rel ?? dur * 0.6;
    env(g.gain, t, o.vol ?? 0.5, a, Math.max(0, dur - a - rel), rel);
    s.connect(fl); fl.connect(g); route(g, o);
    return g;
  }
  function tone(at, dur, o = {}) {
    const t = now() + at, f = o.f || 440, f2 = o.f2 || f;
    const os = ac.createOscillator(); os.type = o.type || "sine";
    os.frequency.setValueAtTime(f, t); os.frequency.exponentialRampToValueAtTime(f2, t + dur);
    const g = ac.createGain(); const a = o.a ?? 0.004, rel = o.rel ?? dur * 0.7;
    env(g.gain, t, o.vol ?? 0.4, a, Math.max(0, dur - a - rel), rel);
    let n = os;
    if (o.lp) { const fl = ac.createBiquadFilter(); fl.type = "lowpass"; fl.frequency.value = o.lp; os.connect(fl); n = fl; }
    n.connect(g); route(g, o); os.start(t); os.stop(t + dur + 0.05);
    return os;
  }
  function thud(at, vol = 0.8, f0 = 120, f1 = 40, dur = 0.3, wet = 0.15) {
    tone(at, dur, { f: f0, f2: f1, vol, a: 0.003, rel: dur * 0.85, wet });
    noise(at, dur * 0.5, { type: "lowpass", f: 260, f2: 90, q: 0.7, vol: vol * 0.5, a: 0.002, wet: wet * 0.5, brown: true });
  }
  // çıtırtı: seyrek, çok kısa kırılma darbeleri (kıkırdak, kemik, pençe)
  function crackle(at, dur, o = {}) {
    const t = now() + at, len = Math.max(1, Math.floor(sr * dur)), buf = ac.createBuffer(1, len, sr), d = buf.getChannelData(0);
    const n = Math.max(1, Math.round((o.rate || 300) * dur));
    for (let k = 0; k < n; k++) {
      const p = Math.floor(rnd() * len), amp = R(0.3, 1) * (rnd() < 0.5 ? -1 : 1), L = Math.floor(sr * R(0.0006, 0.003));
      for (let i = 0; i < L && p + i < len; i++) d[p + i] += amp * (rnd() * 2 - 1) * Math.pow(1 - i / L, 2);
    }
    const s = ac.createBufferSource(); s.buffer = buf;
    const fl = ac.createBiquadFilter(); fl.type = "bandpass"; fl.frequency.value = o.f || 2500; fl.Q.value = o.q || 2;
    const g = ac.createGain(); g.gain.value = o.vol ?? 0.6;
    s.connect(fl); fl.connect(g); route(g, o); s.start(t);
  }
  // ıslak gurultu: noktacıklar halinde genliği oynayan gürültü, filtresi rastgele zıplar (ezilen et, kan, ağızdaki salya)
  function squelch(at, dur, o = {}) {
    const t = now() + at, len = Math.floor(sr * dur), buf = ac.createBuffer(1, len, sr), d = buf.getChannelData(0);
    let p = 0;
    while (p < len) {
      const L = Math.floor(sr * R(0.012, 0.05)), amp = R(0.2, 1);
      for (let i = 0; i < L && p + i < len; i++) { const w = Math.sin(Math.PI * i / L); d[p + i] = (rnd() * 2 - 1) * amp * w * w; }
      p += Math.floor(L * R(0.5, 1.1));
    }
    const s = ac.createBufferSource(); s.buffer = buf;
    const fl = ac.createBiquadFilter(); fl.type = "bandpass"; fl.Q.value = o.q || 3;
    const lo = o.f1 || 300, hi = o.f2 || 1300;
    for (let x = 0; x < dur; x += R(0.02, 0.05)) fl.frequency.setValueAtTime(R(lo, hi), t + x);
    const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = o.lp || 2400;
    const g = ac.createGain(); env(g.gain, t, o.vol ?? 0.5, 0.01, Math.max(0, dur - 0.1), 0.09);
    s.connect(fl); fl.connect(lp); lp.connect(g); route(g, o); s.start(t);
  }
  function drip(at, vol = 0.18, pan = 0) {
    const f = R(1100, 1700);
    tone(at, 0.05, { f, f2: f * 0.3, vol, a: 0.001, rel: 0.045, wet: 0.5, pan });
    noise(at, 0.015, { type: "highpass", f: 4000, vol: vol * 0.3, a: 0.001, rel: 0.012, pan });
  }
  function drips(at, until, n, vol = 0.16) { for (let k = 0; k < n; k++) drip(R(at, until), vol * R(0.5, 1), R(-0.6, 0.6)); }
  function whoosh(at, dur, vol = 0.5, f0 = 250, fp = 1800, pan = 0) {
    const t = now() + at, s = src(white, t, t + dur);
    const fl = ac.createBiquadFilter(); fl.type = "bandpass"; fl.Q.value = 1.3;
    fl.frequency.setValueAtTime(f0, t); fl.frequency.exponentialRampToValueAtTime(fp, t + dur * 0.55); fl.frequency.exponentialRampToValueAtTime(f0 * 1.2, t + dur);
    const g = ac.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + dur * 0.55); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(fl); fl.connect(g); route(g, { wet: 0.25, pan });
  }
  // yükselen gerilim: tıslayan gürültü + birbirinden kayan alçak tonlar; tam vuruş anında kesilir
  function riser(at, dur, vol = 0.35) {
    const t = now() + at, end = t + dur;
    const s = src(white, t, end); const hp = ac.createBiquadFilter(); hp.type = "highpass";
    hp.frequency.setValueAtTime(300, t); hp.frequency.exponentialRampToValueAtTime(6000, end);
    const g = ac.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol * 0.6, end - 0.01); g.gain.linearRampToValueAtTime(0.0001, end + 0.01);
    s.connect(hp); hp.connect(g); route(g, { wet: 0.4 });
    for (const [f, k] of [[70, 4], [74, 4.3], [105, 3.8]]) {
      const os = ac.createOscillator(); os.type = "sawtooth"; os.frequency.setValueAtTime(f, t); os.frequency.exponentialRampToValueAtTime(f * k, end);
      const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.setValueAtTime(300, t); lp.frequency.exponentialRampToValueAtTime(3000, end);
      const og = ac.createGain(); og.gain.setValueAtTime(0.0001, t); og.gain.exponentialRampToValueAtTime(vol * 0.25, end - 0.01); og.gain.linearRampToValueAtTime(0.0001, end + 0.01);
      os.connect(lp); lp.connect(og); route(og, { wet: 0.3 }); os.start(t); os.stop(end + 0.05);
    }
  }
  // sinematik vuruş: uyumsuz yaylı/bakır kümesi + alt bas patlaması + zil çarpması, uzun yankı
  function stinger(at, vol = 0.8) {
    const t = now() + at;
    for (const f of [55, 58.27, 82.41, 87.31, 110, 116.54, 164.81, 174.61]) {
      const os = ac.createOscillator(); os.type = "sawtooth"; os.frequency.value = f * R(0.997, 1.003);
      const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.Q.value = 2;
      lp.frequency.setValueAtTime(3200, t); lp.frequency.exponentialRampToValueAtTime(380, t + 1.4);
      const g = ac.createGain(); env(g.gain, t, vol * 0.11, 0.006, 0.08, 1.7);
      os.connect(lp); lp.connect(g); route(g, { wet: 0.7, pan: R(-0.5, 0.5) }); os.start(t); os.stop(t + 2);
    }
    for (const f of [220, 233.08]) tone(at, 0.6, { type: "square", f, vol: vol * 0.08, a: 0.004, rel: 0.5, lp: 1600, wet: 0.6 });
    tone(at, 2.0, { f: 48, f2: 30, vol: vol * 0.9, a: 0.004, rel: 1.9, wet: 0.2 });
    noise(at, 1.4, { type: "highpass", f: 3500, f2: 2500, vol: vol * 0.22, a: 0.003, rel: 1.3, wet: 0.6 });
  }
  function boom(at, vol = 0.7) {
    tone(at, 3.0, { f: 52, f2: 26, vol, a: 0.01, rel: 2.9, wet: 0.35 });
    noise(at, 2.2, { type: "lowpass", f: 180, f2: 60, vol: vol * 0.5, a: 0.01, rel: 2.1, wet: 0.6, brown: true });
    noise(at, 0.4, { type: "bandpass", f: 900, f2: 300, q: 0.8, vol: vol * 0.12, a: 0.003, rel: 0.38, wet: 0.8 });
  }
  // karanlıkta kalan alçak uğultu (sahne bitince)
  function drone(at, dur, vol = 0.3) {
    const t = now() + at;
    for (const f of [41.2, 43.65, 61.74, 82.6]) {
      const os = ac.createOscillator(); os.type = "sawtooth"; os.frequency.value = f;
      const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 260;
      const g = ac.createGain(); env(g.gain, t, vol * 0.14, dur * 0.35, dur * 0.25, dur * 0.4);
      os.connect(lp); lp.connect(g); route(g, { wet: 0.6 }); os.start(t); os.stop(t + dur + 0.1);
    }
    noise(at, dur, { type: "bandpass", f: 180, f2: 120, q: 5, vol: vol * 0.4, a: dur * 0.4, rel: dur * 0.5, wet: 0.7, brown: true });
  }
  // canavar sesi: testere dişli ses telleri (titreşimli, düzensiz perde) -> bozucu -> gırtlak/ağız filtreleri (sesli harf)
  function roar(at, dur, o = {}) {
    const t = now() + at, end = t + dur, f0 = o.f0 || 120, fp = o.fp || f0 * 1.8, f1 = o.f1 || f0 * 1.2, vol = o.vol ?? 0.7;
    const mix = ac.createGain(); mix.gain.value = 1;
    const freqs = [];
    for (const [type, k, gv] of [["sawtooth", 1, 0.5], ["sawtooth", 1.012, 0.4], ["square", 0.5, 0.35], ["sawtooth", 2.01, 0.15]]) {
      const os = ac.createOscillator(); os.type = type; freqs.push([os.frequency, k]);
      const g = ac.createGain(); g.gain.value = gv; os.connect(g); g.connect(mix); os.start(t); os.stop(end + 0.1);
    }
    // perde eğrisi (f0 -> tepe -> f1) + düzensiz titreme: 50 ms'lik noktalar arası doğrusal geçiş
    const pitchAt = (x) => x < dur * 0.3 ? f0 * Math.pow(fp / f0, x / (dur * 0.3)) : fp * Math.pow(f1 / fp, (x - dur * 0.3) / (dur * 0.7));
    for (const [p, k] of freqs) p.setValueAtTime(f0 * k, t);
    for (let x = 0.05; x <= dur + 1e-6; x += 0.05) {
      const j = 1 + R(-1, 1) * (o.jitter ?? 0.06);
      for (const [p, k] of freqs) p.linearRampToValueAtTime(pitchAt(Math.min(x, dur)) * k * j, t + x);
    }
    const vib = ac.createOscillator(); vib.frequency.value = o.vib || 7;
    const vg = ac.createGain(); vg.gain.value = f0 * 0.04; vib.connect(vg); for (const [p] of freqs) vg.connect(p); vib.start(t); vib.stop(end + 0.1);
    const breath = src(white, t, end); const bg = ac.createGain(); bg.gain.value = o.breath ?? 0.35; breath.connect(bg); bg.connect(mix);
    // gırtlak hırıltısı: genliği hızlı titreten LFO
    const fry = ac.createGain(); fry.gain.value = 0.6; const fl = ac.createOscillator(); fl.frequency.value = o.fry || 28;
    const flg = ac.createGain(); flg.gain.value = 0.4; fl.connect(flg); flg.connect(fry.gain); fl.start(t); fl.stop(end + 0.1);
    mix.connect(fry);
    const ws = ac.createWaveShaper(), n = 1024, c = new Float32Array(n), amt = o.grit ?? 50;
    for (let i = 0; i < n; i++) { const x = (i * 2) / n - 1; c[i] = ((3 + amt) * x * 20 * (Math.PI / 180)) / (Math.PI + amt * Math.abs(x)); }
    ws.curve = c; fry.connect(ws);
    const sum = ac.createGain(); sum.gain.value = 1;
    for (const [f, q, gv] of o.vow || [[750, 4, 1], [1250, 5, 0.7], [2600, 7, 0.4]]) {
      const bp = ac.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = f; bp.Q.value = q;
      const g = ac.createGain(); g.gain.value = gv; ws.connect(bp); bp.connect(g); g.connect(sum);
    }
    const lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = o.lp || 6000;
    const g = ac.createGain(); env(g.gain, t, vol, o.a ?? 0.06, Math.max(0, dur - (o.a ?? 0.06) - (o.rel ?? 0.35)), o.rel ?? 0.35);
    sum.connect(lp); lp.connect(g); route(g, { wet: o.wet ?? 0.45, pan: o.pan || 0 });
  }
  const growl = (at, dur, f = 65, vol = 0.45) => roar(at, dur, { f0: f, fp: f * 1.15, f1: f * 0.95, vol, vow: [[380, 4, 1], [800, 5, 0.5], [2400, 8, 0.15]], fry: 22, grit: 30, breath: 0.5, a: dur * 0.3, rel: dur * 0.4, jitter: 0.04, wet: 0.3 });
  const hiss = (at, dur, vol = 0.35) => { noise(at, dur, { type: "bandpass", f: 3200, f2: 4200, q: 1.8, vol, a: dur * 0.4, rel: dur * 0.4, wet: 0.3 }); noise(at, dur, { type: "highpass", f: 6000, vol: vol * 0.5, a: dur * 0.4, rel: dur * 0.4 }); };
  // oyuncunun nefesi / boğulması
  const gasp = (at, vol = 0.45) => { noise(at, 0.32, { type: "bandpass", f: 900, f2: 1800, q: 3, vol, a: 0.04, rel: 0.2, wet: 0.2 }); noise(at, 0.3, { type: "bandpass", f: 2600, f2: 3000, q: 6, vol: vol * 0.35, a: 0.05, rel: 0.2 }); };
  const choke = (at, dur, vol = 0.35) => { squelch(at, dur, { f1: 180, f2: 700, q: 4, vol, lp: 1400, wet: 0.15 }); roar(at, dur, { f0: 180, fp: 150, f1: 120, vol: vol * 0.25, vow: [[500, 6, 1], [1000, 6, 0.4]], fry: 18, grit: 15, breath: 0.6, a: 0.05, rel: dur * 0.5, wet: 0.15 }); };
  function heartbeat(at, n, iv0, iv1, vol = 0.5) {
    let x = at;
    for (let k = 0; k < n; k++) {
      const v = vol * (1 - 0.5 * k / Math.max(1, n - 1)), iv = iv0 + (iv1 - iv0) * (k / Math.max(1, n - 1));
      tone(x, 0.16, { f: 62, f2: 36, vol: v, a: 0.004, rel: 0.14, lp: 180 }); tone(x + iv * 0.28, 0.13, { f: 55, f2: 34, vol: v * 0.7, a: 0.004, rel: 0.12, lp: 160 });
      x += iv;
    }
  }
  function tinnitus(at, dur, vol = 0.06) {
    tone(at, dur, { f: 6900, vol, a: 0.04, rel: dur * 0.6 }); tone(at, dur, { f: 7340, vol: vol * 0.6, a: 0.08, rel: dur * 0.6 });
  }
  // dünyanın sesi uzaklaşır (bilinç gider): ortam ve efektler boğuklaşır, sonra geri gelir
  function muffle(at, dur, to = 500) {
    const t = now() + at;
    for (const f of [muffLP.frequency, ambLP && ambLP.frequency]) {
      if (!f) continue;
      f.setTargetAtTime(to, t, 0.08); f.setTargetAtTime(20000, t + dur, 0.6);
    }
  }
  // ---------- et, kan, kemik ----------
  function fleshImpact(at, vol = 1) {
    thud(at, vol * 0.9, 150, 42, 0.32, 0.2);
    noise(at, 0.1, { type: "bandpass", f: 750, f2: 400, q: 0.9, vol: vol * 0.7, a: 0.002, rel: 0.09, wet: 0.2 });   // şaplak
    crackle(at + 0.005, 0.12, { rate: 700, f: 1900, q: 2.5, vol: vol * 0.7, wet: 0.15 });                       // kıkırdak
    squelch(at + 0.02, 0.4, { f1: 280, f2: 1200, vol: vol * 0.75, wet: 0.2 });                                 // ezilen et
  }
  // "fışşş": basınçla fışkıran kan (titrek sıvı püskürtmesi + altında ıslak gurultu)
  function spurt(at, dur = 0.5, vol = 0.7, pan = 0) {
    const t = now() + at;
    const s = src(white, t, t + dur + 0.1);
    const bp = ac.createBiquadFilter(); bp.type = "bandpass"; bp.Q.value = 1.3;
    bp.frequency.setValueAtTime(R(2600, 3200), t); bp.frequency.exponentialRampToValueAtTime(R(1200, 1600), t + dur);
    const g = ac.createGain(); env(g.gain, t, vol * 0.55, 0.008, dur * 0.35, dur * 0.6);
    const fl = ac.createGain(); fl.gain.value = 0.65;                                   // sıvı titreşimi
    const lfo = ac.createOscillator(); lfo.frequency.value = R(28, 45); const lg = ac.createGain(); lg.gain.value = 0.35;
    lfo.connect(lg); lg.connect(fl.gain); lfo.start(t); lfo.stop(t + dur + 0.1);
    s.connect(bp); bp.connect(fl); fl.connect(g); route(g, { wet: 0.25, pan });
    noise(at, dur * 0.8, { type: "highpass", f: 5500, vol: vol * 0.18, a: 0.01, rel: dur * 0.5, pan });
    squelch(at, dur * 0.9, { f1: 350, f2: 1100, q: 3, vol: vol * 0.4, wet: 0.15 });
  }
  function splat(at, vol = 0.6) {   // kameraya kan çarpması
    noise(at, 0.09, { type: "lowpass", f: 1400, f2: 500, vol: vol * 0.7, a: 0.002, rel: 0.08, wet: 0.2 });
    tone(at, 0.08, { f: 220, f2: 80, vol: vol * 0.5, a: 0.002, rel: 0.07 });
    squelch(at + 0.01, 0.15, { f1: 500, f2: 1600, vol: vol * 0.45 });
  }
  function boneCrack(at, vol = 1) {
    crackle(at, 0.05, { rate: 2200, f: 3200, q: 5, vol: vol * 0.9, wet: 0.35 });
    crackle(at + 0.035, 0.04, { rate: 1600, f: 2400, q: 4, vol: vol * 0.7, wet: 0.35 });
    noise(at, 0.06, { type: "bandpass", f: 1400, f2: 900, q: 2, vol: vol * 0.6, a: 0.001, rel: 0.05, wet: 0.3 });
    tone(at + 0.01, 0.05, { f: 750, f2: 160, vol: vol * 0.5, a: 0.001, rel: 0.045 });   // "pıt" diye yerinden çıkma
    thud(at, vol * 0.7, 230, 70, 0.18, 0.25);
    squelch(at + 0.03, 0.18, { f1: 300, f2: 900, vol: vol * 0.3 });                        // gerilen doku
  }
  function bodyFall(at, vol = 0.9) {
    thud(at, vol, 95, 30, 0.5, 0.25);
    noise(at, 0.3, { type: "lowpass", f: 400, f2: 120, vol: vol * 0.5, a: 0.003, rel: 0.25, wet: 0.2, brown: true });
    noise(at, 0.22, { type: "bandpass", f: 2600, f2: 1800, q: 0.8, vol: vol * 0.18, a: 0.01, rel: 0.18 });   // kıyafet hışırtısı
    thud(at + 0.14, vol * 0.45, 80, 35, 0.25, 0.2);                                                        // seken baş/kol
  }
  function steps(at, times, vol0, vol1, heavy = 1) {
    times.forEach((x, k) => {
      const v = vol0 + (vol1 - vol0) * (k / Math.max(1, times.length - 1));
      thud(at + x, v * heavy, 110, 45, 0.16, 0.25);
      crackle(at + x + 0.004, 0.03, { rate: 600, f: 2800, q: 3, vol: v * 0.5, wet: 0.25 });           // pençe tıkırtısı
    });
  }
  function rustle(at, dur, vol = 0.3) {   // deri/kıyafet kavrama
    squelch(at, dur, { f1: 1800, f2: 4200, q: 1.2, vol, lp: 7000 });
  }
  function bite(at, vol = 1) {
    crackle(at, 0.03, { rate: 2500, f: 4200, q: 5, vol: vol * 0.8, wet: 0.3 });                     // dişler kapanır
    boneCrack(at + 0.02, vol * 0.8);
    fleshImpact(at + 0.01, vol * 0.8);
    squelch(at + 0.05, 0.5, { f1: 200, f2: 900, q: 3, vol: vol * 0.6, wet: 0.2 });
  }

  // ---------- sahneler (T: render.js'teki zamanlar) ----------
  const scenes = {
    // Koşucu: tiz çığlıkla atılır, çarpar, devirir, kükrer, salyası damlar, ısırır
    tackle(T) {
      steps(0, [0, 0.11], 0.35, 0.5, 0.8);
      roar(0.02, T.impact + 0.05, { f0: 230, fp: 420, f1: 300, vol: 0.55, vow: [[650, 5, 1], [2200, 6, 0.8], [3100, 8, 0.5]], fry: 34, grit: 70, a: 0.04, rel: 0.15, wet: 0.35 });
      whoosh(0.08, T.impact - 0.05, 0.55, 300, 2200);
      stinger(T.impact, 0.85); fleshImpact(T.impact, 1); gasp(T.impact + 0.06, 0.55); spurt(T.impact + 0.03, 0.35, 0.45, -0.3); splat(T.impact + 0.04, 0.4);
      whoosh(T.impact + 0.05, T.down - T.impact, 0.35, 200, 900); bodyFall(T.down - 0.02, 1);
      heartbeat(T.impact + 0.15, 9, 0.26, 0.22, 0.5);
      growl(T.down, T.roar - T.down + 0.1, 70, 0.5);
      roar(T.roar, T.bite - T.roar - 0.05, { f0: 150, fp: 270, f1: 175, vol: 0.95, vow: [[780, 4, 1], [1300, 5, 0.75], [2700, 7, 0.45]], grit: 85, fry: 30, wet: 0.5 });
      squelch(T.roar + 0.1, T.bite - T.roar - 0.2, { f1: 250, f2: 800, q: 4, vol: 0.18, lp: 1500 });   // ağızdaki salya
      drips(T.roar + 0.15, T.bite, 7, 0.18);
      whoosh(T.bite - 0.12, 0.14, 0.4, 400, 1600);
      bite(T.bite + 0.02, 1); spurt(T.bite + 0.06, 0.6, 0.85); splat(T.bite + 0.08, 0.7); choke(T.bite + 0.12, 0.35, 0.3);
      muffle(T.end - 0.05, 4.5, 450); drone(T.end, 3.6, 0.3); heartbeat(T.end + 0.3, 4, 0.75, 1.5, 0.4);
    },
    // Sıska: ağır adımlar, nefes alır, saplar (fışkırma), kalp attıkça kan pompalanır, kaldırır, kükrer, çeker, düşeriz
    stab(T) {
      steps(0, [0, 0.36, 0.7], 0.3, 0.55, 1.1);
      crackle(0.05, 0.6, { rate: 25, f: 1600, q: 3, vol: 0.25, wet: 0.4 });                          // eklem çıtırtıları
      growl(0.1, 0.65, 58, 0.35); hiss(T.windup - 0.35, 0.35, 0.3);
      riser(T.windup - 0.25, T.hit - (T.windup - 0.25), 0.4);
      stinger(T.hit, 0.9); fleshImpact(T.hit, 1.05); spurt(T.hit + 0.03, 0.55, 0.95); splat(T.hit + 0.05, 0.6);
      gasp(T.hit + 0.12, 0.5); choke(T.hit + 0.45, 0.9, 0.3);
      squelch(T.hit + 0.3, 0.35, { f1: 250, f2: 900, vol: 0.45, wet: 0.15 });                       // eli içimizde döner
      for (let x = T.hit + 0.62, k = 0; x < T.pull - 0.1; x += 0.5, k++) {                           // her kalp atışında fışkırır
        spurt(x, 0.32, 0.6 * Math.pow(0.9, k), k % 2 ? 0.25 : -0.25);
        tone(x - 0.02, 0.16, { f: 60, f2: 36, vol: 0.45 * Math.pow(0.9, k), a: 0.004, rel: 0.14, lp: 180 });
      }
      whoosh(T.lift, T.up - T.lift, 0.35, 180, 700); crackle(T.lift, 0.6, { rate: 40, f: 900, q: 2, vol: 0.35, wet: 0.3 });   // kolu gerilir
      choke(T.lift + 0.2, 0.8, 0.35);
      drips(T.lift + 0.2, T.pull, 11, 0.2);
      roar(T.up + 0.1, 1.05, { f0: 92, fp: 160, f1: 105, vol: 0.85, vow: [[520, 4, 1], [950, 5, 0.6], [2400, 8, 0.35]], grit: 60, fry: 24, vib: 5, wet: 0.55 });
      squelch(T.pull - 0.05, 0.3, { f1: 300, f2: 1600, q: 2.5, vol: 0.7, wet: 0.2 });              // çekilen el
      tone(T.pull, 0.12, { f: 260, f2: 900, vol: 0.35, a: 0.003, rel: 0.1 });                      // "flup" diye emme
      spurt(T.pull + 0.03, 0.9, 1); splat(T.pull + 0.04, 0.65);
      whoosh(T.pull + 0.1, T.floor - T.pull - 0.1, 0.35, 220, 1000); bodyFall(T.floor - 0.02, 1); splat(T.floor + 0.02, 0.35);
      muffle(T.floor + 0.15, 5, 600); heartbeat(T.floor + 0.35, 5, 0.85, 1.7, 0.45); drips(T.floor, T.end, 5, 0.12);
      drone(T.end, 3.6, 0.3);
    },
    // İblis: hızlı adımlar ve hırıltı, kavrar, sıkar, kemik kırılır; sonra sessizlik, çınlama, yere yığılma
    snap(T) {
      steps(0, [0, 0.17, 0.34, 0.51, 0.68], 0.25, 0.6, 1);
      growl(0, T.grab, 78, 0.5); riser(T.grab - 0.45, T.snap - (T.grab - 0.45), 0.35);
      rustle(T.grab, 0.3, 0.35); gasp(T.grab + 0.03, 0.5);
      crackle(T.grab + 0.08, T.snap - T.grab - 0.08, { rate: 60, f: 900, q: 2, vol: 0.4, wet: 0.2 });   // sıkılan kafa
      growl(T.grab + 0.05, T.snap - T.grab + 0.05, 52, 0.45);
      whoosh(T.snap - 0.01, 0.18, 0.7, 500, 3000); boneCrack(T.snap, 1.25); stinger(T.snap + 0.01, 0.7);
      muffle(T.snap + 0.06, 6, 380); tinnitus(T.snap + 0.1, 3.2, 0.06);
      heartbeat(T.snap + 0.4, 3, 0.9, 1.6, 0.4);
      bodyFall(T.floor - 0.02, 0.85);
      drone(T.end, 3.4, 0.28);
    },
  };
  return {
    scene(name, T) { const f = scenes[name]; if (f) f(T); return !!f; },
    // karanlıkta yazı belirirken: 1. satır derin vuruş, 2. satır ürpertici tiz tını
    text(line, at = 0) {
      if (line === 1) boom(at, 0.75);
      else { boom(at, 0.35); for (const f of [1318.5, 1396.9, 1975.5]) tone(at, 2.6, { f, vol: 0.035, a: 0.6, rel: 1.8, wet: 0.8 }); }
    },
  };
}
