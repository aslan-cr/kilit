#!/bin/sh
# Kamera (göz algılama) dosyalarını uygulamanın içine koyar; böylece internetsiz çalışır.
# Derleme sırasında (GitHub Actions) çalışır. Kullanım: sh tools/fetch-mediapipe.sh [hedef klasör]
set -e
OUT="${1:-$(dirname "$0")/../src/main/assets/mediapipe}"
V=0.10.14
B="https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@$V"
mkdir -p "$OUT/wasm"
get() { curl -fsSL --retry 3 "$1" -o "$2"; test -s "$2"; }
get "$B/vision_bundle.mjs" "$OUT/vision_bundle.js"          # .js adıyla: WebView doğru MIME türünü verir
for f in vision_wasm_internal.js vision_wasm_internal.wasm vision_wasm_nosimd_internal.js vision_wasm_nosimd_internal.wasm; do get "$B/wasm/$f" "$OUT/wasm/$f"; done
get "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task" "$OUT/face_landmarker.task"
ls -l "$OUT" "$OUT/wasm"
