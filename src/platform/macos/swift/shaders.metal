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

struct TextureVertexIn {
  float2 position [[attribute(0)]];
  float2 texcoord [[attribute(1)]];
};

struct TextureVertexOut {
  float4 position [[position]];
  float2 texcoord;
};

vertex TextureVertexOut texture_vertex_main(TextureVertexIn in [[stage_in]]) {
  TextureVertexOut out;

  out.position = float4(in.position, 0, 1);
  out.texcoord = in.texcoord;

  return out;
}

fragment float4 texture_fragment_main(TextureVertexOut input [[stage_in]],
                                      texture2d<float> tex [[texture(0)]]) {
  constexpr sampler s(mag_filter::nearest, min_filter::nearest);
  return tex.sample(s, input.texcoord);
}
