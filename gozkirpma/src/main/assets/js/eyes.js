// Kamera + MediaPipe Face Landmarker ile göz kapanması. Dil/ağız algılama YOK, yalnızca göz.
// Hassasiyet rules.js'te (eyes.closeAt / eyes.openAt): yüksek = daha az hassas.
// Önce APK/uygulamanın içindeki kopya (internetsiz çalışır); yoksa internetten (CDN) denenir.
// Yerel dosyalar derleme sırasında indirilir (.github/workflows/build.yml, tools/fetch-mediapipe.sh).
const LOCAL = new URL("../mediapipe/", import.meta.url).href;
const CDN = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/";
const SOURCES = [
  { module: LOCAL + "vision_bundle.js", wasm: LOCAL + "wasm", model: LOCAL + "face_landmarker.task", name: "yerel" },
  { module: CDN + "+esm", wasm: CDN + "wasm",
    model: "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task", name: "internet" },
];

let landmarker = null;
export let landmarkerSource = "";

export async function loadLandmarker() {
  if (landmarker) return landmarker;
  let lastErr;
  for (const src of SOURCES) {
    try {
      const { FaceLandmarker, FilesetResolver } = await import(src.module);
      const fileset = await FilesetResolver.forVisionTasks(src.wasm);
      const opts = (delegate) => ({
        baseOptions: { modelAssetPath: src.model, delegate },
        runningMode: "VIDEO",
        numFaces: 1,
        outputFaceBlendshapes: true,
      });
      try { landmarker = await FaceLandmarker.createFromOptions(fileset, opts("GPU")); }
      catch { landmarker = await FaceLandmarker.createFromOptions(fileset, opts("CPU")); }
      landmarkerSource = src.name;
      return landmarker;
    } catch (e) { lastErr = e; }
  }
  throw new Error("Yüz modeli yüklenemedi (yerel dosya yok, internet de yok): " + (lastErr && lastErr.message || lastErr));
}

export async function openCamera(video) {
  if (!video.srcObject) {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30, max: 30 }, facingMode: "user" },   // küçük görüntüde göz kırpma okunmuyordu: 640x480; kasma, algılamayı seyrelterek önlenir,
      audio: false,
    });
    video.srcObject = stream;
    await video.play();
  }
}

// Göz durumu: iki göz de eşiği aşınca "kapalı". Eşikler KİŞİYE göre ayarlanır: gözü doğal olarak yarı açık (düşük göz kapağı) olan
// birinde "açık göz" değeri yüksek çıkar; bu yüzden her gözün açık hâlini (taban) sürekli ölçeriz. Taban hemen aşağı iner, yavaşça yukarı çıkar;
// kapalı göz tabanı şişirmez. Kapanış = taban + closeDelta (en az closeFloor), açılış = taban + openDelta (en az openFloor).
export function eyeLimits(base, E) {
  const close = Math.min(E.closeMax ?? 0.8, Math.max(E.closeFloor ?? E.closeAt, base + (E.closeDelta ?? 0.28)));
  const open = Math.min(close - 0.1, Math.max(E.openFloor ?? E.openAt, base + (E.openDelta ?? 0.14)));
  return { close, open };
}
export function updateBase(base, score, E) {           // base: null = henüz ölçülmedi
  const cap = E.baseMax ?? 0.45;
  if (base === null) return Math.min(cap, score);
  if (score < base) return score;                       // gözü daha açık gördük: taban hemen iner
  if (score < base + (E.closeDelta ?? 0.28) * 0.8) return Math.min(cap, base + (score - base) * (E.baseRise ?? 0.01));   // açık hâlin yavaş kayması
  return base;                                          // kapalı/kırpma: tabanı etkilemez
}
export function makeEyeTracker(rules) {
  const E = rules.eyes;
  const t = { left: 0, right: 0, baseL: null, baseR: null, closedL: false, closedR: false, lastVideoTime: -1, noFaceAt: 0, noFace: false, nextAt: 0, every: E.detectMs || 66, cost: 0 };
  t.read = (video) => {
    if (!landmarker || video.readyState < 2 || video.currentTime === t.lastVideoTime) return;
    const now = performance.now();
    if (now < t.nextAt) return;                       // her çizimde değil, ~15 Hz: kasmayı önler
    t.lastVideoTime = video.currentTime;
    const res = landmarker.detectForVideo(video, now);
    t.cost = t.cost * 0.8 + (performance.now() - now) * 0.2;
    t.nextAt = performance.now() + Math.max(t.every, t.cost * 3);   // algılama yavaşsa daha da seyrelt (oyun akıcı kalsın)
    const shapes = res.faceBlendshapes && res.faceBlendshapes[0];
    if (!shapes) { t.left = t.right = 0; t.noFace = true; return; }   // yüz yoksa gözler açık sayılır (takılı kalmasın)
    t.noFace = false;
    for (const c of shapes.categories) {
      if (c.categoryName === "eyeBlinkLeft") t.left = c.score;
      else if (c.categoryName === "eyeBlinkRight") t.right = c.score;
    }
    t.baseL = updateBase(t.baseL, t.left, E); t.baseR = updateBase(t.baseR, t.right, E);
  };
  t.set = (closed) => { t.left = t.right = closed ? 1 : 0; };
  t.limits = () => ({ l: eyeLimits(t.baseL ?? 0, E), r: eyeLimits(t.baseR ?? 0, E) });
  t.closed = () => {
    const { l, r } = t.limits();
    if (!t.closedL && t.left > l.close) t.closedL = true; else if (t.closedL && t.left < l.open) t.closedL = false;
    if (!t.closedR && t.right > r.close) t.closedR = true; else if (t.closedR && t.right < r.open) t.closedR = false;
    return t.closedL && t.closedR;
  };
  return t;
}
