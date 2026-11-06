// Kamera + MediaPipe Face Landmarker ile göz kapanması. Dil/ağız algılama YOK, yalnızca göz.
// Hassasiyet rules.js'te (eyes.closeAt / eyes.openAt): yüksek = daha az hassas.
const WASM_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm";
const MODULE_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm";
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task";

let landmarker = null;

export async function loadLandmarker() {
  if (landmarker) return landmarker;
  const { FaceLandmarker, FilesetResolver } = await import(MODULE_URL);
  const fileset = await FilesetResolver.forVisionTasks(WASM_URL);
  const opts = (delegate) => ({
    baseOptions: { modelAssetPath: MODEL_URL, delegate },
    runningMode: "VIDEO",
    numFaces: 1,
    outputFaceBlendshapes: true,
  });
  try { landmarker = await FaceLandmarker.createFromOptions(fileset, opts("GPU")); }
  catch { landmarker = await FaceLandmarker.createFromOptions(fileset, opts("CPU")); }
  return landmarker;
}

export async function openCamera(video) {
  if (!video.srcObject) {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { width: 640, height: 480, frameRate: { ideal: 60, min: 30 }, facingMode: "user" },
      audio: false,
    });
    video.srcObject = stream;
    await video.play();
  }
}

// Göz durumu: iki göz de eşiği aşınca "kapalı". Histerezis: kapanış closeAt, açılış openAt.
export function makeEyeTracker(rules) {
  const E = rules.eyes;
  const t = { left: 0, right: 0, closedL: false, closedR: false, lastVideoTime: -1, noFaceAt: 0, noFace: false };
  t.read = (video) => {
    if (!landmarker || video.readyState < 2 || video.currentTime === t.lastVideoTime) return;
    t.lastVideoTime = video.currentTime;
    const res = landmarker.detectForVideo(video, performance.now());
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
