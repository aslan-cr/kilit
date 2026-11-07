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
      video: { width: { ideal: 320 }, height: { ideal: 240 }, frameRate: { ideal: 30, max: 30 }, facingMode: "user" },
      audio: false,
    });
    video.srcObject = stream;
    await video.play();
  }
}

// Göz durumu: iki göz de eşiği aşınca "kapalı". Histerezis: kapanış closeAt, açılış openAt.
export function makeEyeTracker(rules) {
  const E = rules.eyes;
  const t = { left: 0, right: 0, closedL: false, closedR: false, lastVideoTime: -1, noFaceAt: 0, noFace: false, nextAt: 0, every: E.detectMs || 66, cost: 0 };
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
  };
  t.set = (closed) => { t.left = t.right = closed ? 1 : 0; };
  t.closed = () => {
    if (!t.closedL && t.left > E.closeAt) t.closedL = true; else if (t.closedL && t.left < E.openAt) t.closedL = false;
    if (!t.closedR && t.right > E.closeAt) t.closedR = true; else if (t.closedR && t.right < E.openAt) t.closedR = false;
    return t.closedL && t.closedR;
  };
  return t;
}
