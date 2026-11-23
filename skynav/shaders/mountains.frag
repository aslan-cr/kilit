#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// SkyNav dağları: üç katman sivri sırt (Figma formülü), güneş yönüne göre ışık/gölge alan yamaçlar,
// eğim boyunca erozyon çizgileri, dik yerlerde tutmayan gerçekçi kar, katman derinliğiyle artan pus.
// Uniform'lar yalnızca vec4: her GPU'da (Vulkan/GLES std140) hizalama kayması olmaz.
uniform vec4 uA;      // xy: alan (mantıksal px), zw: güneş/ay konumu (px)
uniform vec4 uB;      // x: ışık şiddeti (gündüz 1, gece ~0.35), y: zirve karı, z: ön plan karı, w: tohum
uniform vec4 uF1;
uniform vec4 uF2;
uniform vec4 uM1;
uniform vec4 uM2;
uniform vec4 uN1;
uniform vec4 uN2;
uniform vec4 uHz;
uniform vec4 uSl;     // güneşe bakan karın rengi (gün batımında pembe: dağ alevi)
uniform vec4 uP;      // x: görüntü pikseli / mantıksal px
#define uSize uA.xy
#define uSun uA.zw
#define uLight uB.x
#define uSnow uB.y
#define uGround uB.z
#define uSeed uB.w
#define uFar1 uF1.rgb
#define uFar2 uF2.rgb
#define uMid1 uM1.rgb
#define uMid2 uM2.rgb
#define uNear1 uN1.rgb
#define uNear2 uN2.rgb
#define uHaze uHz.rgb
#define uSnowLit uSl.rgb
#define uPx uP.x

out vec4 fragColor;

const float FW = 376.0;

vec2 hash2(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))) + uSeed;
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float gnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = dot(hash2(i), f);
  float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return 0.5 + 0.7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 4; i++) { v += a * gnoise(p); p = mat2(1.6, 1.2, -1.2, 1.6) * p; a *= 0.5; }
  return v / 0.9375;
}

// Figma sırt formülü + ince kayalık pürüz
float ridge(float u, float k0, float k1, float k2, float k3, float k4, float k5) {
  float peaks = pow(1.0 - abs(sin(u * k0 + k1)), k2);
  float second = pow(1.0 - abs(sin(u * k3 + k4)), 2.0) * k5;
  float r = min(1.0, peaks * 0.85 + second + 0.04 * sin(u * 61.0 + k1));
  return r + 0.018 * (gnoise(vec2(u * 90.0, k1 * 7.0)) - 0.5);
}

struct Layer { float base; float amp; float k0; float k1; float k2; float k3; float k4; float k5; float snow; float thr; float depth; };

float ry(Layer L, float x, float W) {
  return L.base - L.amp * ridge(x / W, L.k0, L.k1, L.k2, L.k3, L.k4, L.k5);
}

vec3 shadeLayer(Layer L, vec3 c1, vec3 c2, vec2 pos, float W, float H, float k, float top) {
  float x = pos.x, y = pos.y;
  // Yamaç eğimi: derinlere inildikçe daha geniş ölçekte bakılır (yüz yumuşar, sırt omurgası korunur).
  float below = max(0.0, y - top);
  float e = 1.5 + below * 0.45;
  float s = (ry(L, x + e, W) - ry(L, x - e, W)) / (2.0 * e);   // >0: yüz sağa bakıyor
  float facing = clamp(s * 1.4, -1.0, 1.0);
  float sunSide = clamp((uSun.x - x) / (0.45 * W), -1.0, 1.0);
  float lit = 0.5 + 0.5 * facing * sunSide;                     // 1: güneşe bakan yüz
  // Taban rengi: tepeden aşağı c1 → c2
  float g = clamp((y - (L.base - L.amp)) / (H - (L.base - L.amp)), 0.0, 1.0);
  vec3 col = mix(c1, c2, g);
  // Erozyon olukları yüzün eğimi boyunca (çapraz) akar; ince kaya dokusu
  float shear = clamp(s, -1.5, 1.5) * 0.55;
  float gully = fbm(vec2((x - below * shear) / (5.5 * k), y / (22.0 * k)));
  float rock = fbm(vec2(x, y) / (3.5 * k));
  col *= 0.90 + 0.16 * (gully - 0.5) * 2.0 * smoothstep(0.0, 18.0 * k, below + 6.0 * k) + 0.06 * (rock - 0.5);
  // Işık: güneşe bakan yüz aydınlık, öbürü mavimsi gölge
  float amt = mix(0.82, 0.70 + 0.42 * lit, uLight);
  col *= amt;
  col = mix(col, col * vec3(0.86, 0.92, 1.06), (1.0 - lit) * 0.6 * uLight);
  // Kar: eşik dalgalı, dik yerde ve oluk diplerinde tutmaz
  if (L.snow > 0.0 && uSnow > 0.0) {
    float thrY = L.base - L.amp * L.thr + (fbm(vec2(x / (12.0 * k), L.k1 * 3.0)) - 0.5) * 30.0 * k;
    float m = 1.0 - smoothstep(thrY - 2.5 * k, thrY + 2.5 * k, y + (gully - 0.5) * 14.0 * k);
    m *= 1.0 - smoothstep(1.8, 3.2, abs(s)) * 0.6;
    vec3 snowCol = mix(vec3(0.74, 0.80, 0.90), uSnowLit, lit);
    snowCol = mix(snowCol * vec3(0.62, 0.66, 0.78), snowCol, uLight);
    col = mix(col, snowCol, clamp(m, 0.0, 1.0) * L.snow * uSnow);
  }
  // Hava perspektifi: uzak katman ve vadi tabanı pusa karışır
  float valley = smoothstep(L.base - L.amp * 0.25, L.base + 10.0 * k, y);
  col = mix(col, uHaze, clamp(L.depth + valley * (0.14 + L.depth * 0.45), 0.0, 0.75));
  return col;
}

void main() {
  // Ekran dışı görüntü pikseli → mantıksal px. uP.y > 0: bu GPU'da y ekseni ters (açılışta ölçülür).
  vec2 raw = FlutterFragCoord().xy;
  if (uP.y > 0.0) raw.y = uP.y - raw.y;
  vec2 pos = raw / uPx;
  float W = uSize.x, H = uSize.y, k = H / 380.0;
  Layer lf = Layer(H * 0.70, 120.0 * k, 7.3, 0.6, 1.6, 17.0, 1.1, 0.12, 0.92, 0.45, 0.26);
  Layer lm = Layer(H * 0.80, 96.0 * k, 5.1, 2.2, 1.4, 13.0, 0.4, 0.14, 0.86, 0.5, 0.10);
  Layer ln = Layer(H * 0.96, 70.0 * k, 3.4, 1.3, 1.1, 9.0, 2.0, 0.18, 0.0, 0.0, 0.0);
  float aa = 0.8;
  float yN = ry(ln, pos.x, W), yM = ry(lm, pos.x, W), yF = ry(lf, pos.x, W);
  vec4 outc = vec4(0.0);
  // Arkadan öne katmanlar ön-çarpımlı "üstüne" kuralıyla bindirilir (kenarlar yumuşak, koyu çizgisiz).
  float cF = smoothstep(yF - aa, yF + aa, pos.y);
  if (cF > 0.0) { vec3 c = shadeLayer(lf, uFar1, uFar2, pos, W, H, k, yF); outc = vec4(c * cF, cF); }
  float cM = smoothstep(yM - aa, yM + aa, pos.y);
  if (cM > 0.0) { vec3 c = shadeLayer(lm, uMid1, uMid2, pos, W, H, k, yM); outc = vec4(c * cM, cM) + outc * (1.0 - cM); }
  float cN = smoothstep(yN - aa, yN + aa, pos.y);
  if (cN > 0.0) { vec3 c = shadeLayer(ln, uNear1, uNear2, pos, W, H, k, yN); outc = vec4(c * cN, cN) + outc * (1.0 - cN); }
  // Ön plan kar örtüsü: yumuşak dalgalı, gölgeli
  if (uGround > 0.0) {
    float fx = pos.x / (W / FW);
    float gy = H - (14.0 + 5.0 * sin(fx / 37.0) + 3.0 * sin(fx / 11.0) + 4.0 * (fbm(vec2(fx / 30.0, 2.0)) - 0.5)) * k;
    float cg = smoothstep(gy - aa, gy + aa, pos.y) * uGround;
    float shade = 0.9 + 0.1 * fbm(pos / (12.0 * k));
    vec3 gc = mix(vec3(0.62, 0.68, 0.80), vec3(0.97, 0.98, 1.0), uLight) * shade;
    outc = vec4(gc * cg, cg) + outc * (1.0 - cg);
  }
  fragColor = outc;
}
