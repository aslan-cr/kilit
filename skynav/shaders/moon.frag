#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Gerçek Ay: NASA LRO verisinden Ay haritası küreye sarılır; Ay'a özgü yansıma (Lommel-Seeliger + Lambert)
// ile gerçek evreye göre aydınlatılır. Karanlık tarafta Dünya ışığı, ufka yakınken atmosfer rengi.
uniform vec2 uCenter;     // px
uniform float uRadius;    // px
uniform vec3 uSun;        // Ay'dan güneşe yön (x sağ, y yukarı, z izleyiciye)
uniform float uRot;       // ekranda Ay kuzeyinin dönüşü (radyan)
uniform vec3 uTint;       // atmosfer rengi çarpanı (ufka yakın sarı-turuncu)
uniform float uEarthshine;// karanlık tarafın Dünya ışığı (0..1)
uniform float uAlpha;     // genel saydamlık (bulut/pus)
uniform sampler2D uTex;   // eşdikdörtgen Ay haritası (boylam 0 ortada)

out vec4 fragColor;

const float PI = 3.14159265;

void main() {
  vec2 fc = FlutterFragCoord().xy;
  vec2 p = (fc - uCenter) / uRadius;
  float r2 = dot(p, p);
  float aa = 1.5 / uRadius;
  float edge = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, sqrt(r2));
  if (edge <= 0.0) { fragColor = vec4(0.0); return; }
  // Ekran (y aşağı) → görünüm (y yukarı), Ay kuzeyine göre döndür
  vec2 q = vec2(p.x, -p.y);
  float c = cos(uRot), s = sin(uRot);
  vec2 qr = vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
  float z = sqrt(max(0.0, 1.0 - dot(qr, qr)));
  vec3 n = vec3(qr, z);
  // Seleno koordinatları: yakın yüzün merkezi boylam 0
  float lon = atan(n.x, n.z);
  float lat = asin(clamp(n.y, -1.0, 1.0));
  vec2 uv = vec2(0.5 + lon / (2.0 * PI), 0.5 - lat / PI);
  vec3 alb = texture(uTex, uv).rgb;
  // Kenara yaklaştıkça doku sıkışır: birkaç örnekle yumuşat (kırpışma olmasın)
  if (z < 0.45) {
    float du = (0.45 - z) * 0.006;
    alb = (alb + texture(uTex, uv + vec2(du, 0.0)).rgb + texture(uTex, uv - vec2(du, 0.0)).rgb
          + texture(uTex, uv + vec2(0.0, du * 0.5)).rgb + texture(uTex, uv - vec2(0.0, du * 0.5)).rgb) / 5.0;
  }
  // Ayın kendi rengi hafif sıcak gri
  alb *= vec3(1.0, 0.985, 0.955);

  // Işık: görünüm-uzayı güneş yönü
  vec3 L = normalize(uSun);
  float mu0 = dot(n, L);          // geliş açısı kosinüsü
  float mu = max(n.z, 0.02);      // bakış açısı kosinüsü
  float lit = 0.0;
  if (mu0 > 0.0) {
    // Ay yüzeyi: çoğunlukla Lommel-Seeliger (dolunayda disk düz parlak görünür)
    float ls = 2.0 * mu0 / (mu0 + mu);
    lit = mix(mu0, ls, 0.85);
  }
  // Yumuşak terminatör (dağlık sınırın pürüzü)
  float term = smoothstep(-0.03, 0.06, mu0 + (alb.r - 0.5) * 0.04);
  vec3 col = alb * lit * 1.18 * term;
  // Dünya ışığı: karanlık taraf çok sönük mavimsi gri
  col += alb * vec3(0.62, 0.70, 0.86) * uEarthshine * 0.07 * (1.0 - term);
  col *= uTint;
  // Aşırı pozlamada yumuşak doygunluk (patlamadan beyaza yaklaşır)
  col = col / (1.0 + max(col - 1.0, 0.0));
  col = min(col, vec3(1.0));
  float a = edge * uAlpha;
  // Karanlık taraf gökyüzüyle aynı görünür (atmosfer önünde): yalnızca Dünya ışığı eklenir.
  fragColor = vec4(col * a, a * term);
}
