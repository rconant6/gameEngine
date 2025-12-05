#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float2 position [[attribute(0)]];
  float4 color [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
  return {.position = float4(in.position, 0.0, 1.0), .color = in.color};
}

fragment float4 fragment_main(VertexOut input [[stage_in]]) {
  return input.color;
}
