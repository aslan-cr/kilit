#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// SkyNav bulutları: tek parça bulut kütleleri. Büyük ölçekli gürültü kütleyi, kabarık (billow)
// ayrıntı gürültüsü kenarları aşındırır; güneşe doğru kısa örnekleme gölgeli alt/iç kısım verir.
uniform vec2 uSize;      // çizim alanı (mantıksal px)
uniform float uTime;     // sn
uniform float uCover;    // bulut örtüsü 0..1
uniform vec2 uSun;       // güneş/ay konumu (px)
uniform vec4 uLit;       // aydınlık renk (rgb) + en yüksek opaklık (a)
uniform vec4 uShade;     // gölge rengi (rgb) + ağırlık (a: 0 açık pamuk, 1 koyu yağmur bulutu)
uniform vec2 uWind;      // kayma (gürültü birimi/sn)
uniform float uScale;    // 1 gürültü birimi kaç px
uniform float uHorizon;  // bulutların sönümlendiği yükseklik oranı (0..1)
uniform float uSeed;
uniform vec2 uOffset;    // görünüm kaydırma (px): kubbede bakış yönüyle bulutlar da kayar

out vec4 fragColor;

vec2 hash2(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))) + uSeed;
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Gradyan gürültüsü (yönsüz, çizgisiz)
float gnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(hash2(i), f);
  float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return 0.5 + 0.7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 R = mat2(1.6, 1.2, -1.2, 1.6);

float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 4; i++) { v += a * gnoise(p); p = R * p; a *= 0.5; }
  return v / 0.9375;
}

// Kabarık ayrıntı: |gürültü| ters çevrilince yuvarlak kabarcıklar ve ince boğumlar
float billow(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 3; i++) { v += a * (1.0 - abs(gnoise(p) * 2.0 - 1.0)); p = R * p; a *= 0.5; }
  return v / 0.875;
}

float density(vec2 p, float t) {
  vec2 w = p + uWind * t;
  // Kütle: yatayda biraz geniş; ayrıntı kenarları kabarık kabarık aşındırır.
  float base = fbm(w * vec2(0.82, 1.0) + vec2(0.0, t * 0.004));
  float det = billow(w * 2.3 + vec2(t * 0.02, 0.0));
  float n = base - (1.0 - det) * 0.30 + 0.06;
  float thr = mix(0.64, 0.16, uCover);
  return smoothstep(thr, thr + 0.13, n);
}

void main() {
  vec2 fc0 = FlutterFragCoord().xy;
  vec2 uv = fc0 / uSize;
  vec2 fc = fc0 + uOffset;
  float h = clamp(uv.y / uHorizon, 0.0, 1.0);
  // Ufka yaklaştıkça bulutlar yassılaşır ve küçülür (perspektif).
  vec2 p = vec2(fc.x / (uScale * (1.0 - 0.35 * h)), fc.y / (uScale * (1.0 - 0.6 * h)));
  float d = density(p, uTime);
  float fade = 1.0 - smoothstep(uHorizon * 0.65, uHorizon, uv.y);
  if (d * fade < 0.004) { fragColor = vec4(0.0); return; }

  // Güneşe doğru iki örnek: kalın bölgeler kendi gölgesinde kalır.
  vec2 dir = normalize(uSun - fc0 + vec2(0.001, 0.001)) * 0.07;
  float acc = density(p + dir, uTime) + density(p + 2.4 * dir, uTime);
  float light = exp(-acc * (0.32 + 1.2 * uShade.a));
  // Alt kısım: bulutun yoğun, aşağı bakan yüzü koyulaşır.
  float below = density(p + vec2(0.0, 0.12), uTime);
  float under = d * below * (0.35 + 0.45 * uShade.a);
  // Üst kenar: güneşe bakan kabarık tepeler daha parlak.
  float above = density(p - vec2(0.0, 0.10), uTime);
  float rim = d * (1.0 - above) * 0.22;
  vec3 col = mix(uShade.rgb, uLit.rgb, clamp(light * (1.0 - under) + rim, 0.0, 1.0));
  // Kapalı havada dokulu, dalgalı taban (düz gri değil).
  float mott = billow(p * 1.3 + uWind * uTime * 0.7);
  col *= 1.0 + (mott - 0.55) * 0.35 * uShade.a;
  // Güneşe yakın ince kenarlarda gümüş parlaklık.
  float sd = length(fc0 - uSun) / max(uSize.x, uSize.y);
  col += vec3(1.0, 0.96, 0.88) * (1.0 - d) * d * 1.0 * exp(-sd * 4.0) * (1.0 - uShade.a) * (1.0 - uShade.a);
  float a = clamp(d * uLit.a * fade, 0.0, 1.0);
  fragColor = vec4(col * a, a);
}
