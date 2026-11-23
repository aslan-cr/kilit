#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Açılış ölçümü: bu cihazda FlutterFragCoord ekran dışı görüntüde hangi koordinatı veriyor?
// (x, y) / 64 renk olarak yazılır; Dart tarafı okuyup ölçeği ve y yönünü doğrular.
uniform vec4 uA; // x: bölen (64)
out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  fragColor = vec4(p.x / uA.x, p.y / uA.x, 0.0, 1.0);
}
