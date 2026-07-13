#include <metal_stdlib>
using namespace metal;

// 8-byte aligned to match Zig LocalXform (6x f32 = 24B, no padding).
// A float4 here would force 16-byte alignment -> 32B stride -> misreads past
// index 0.
struct LocalXFrom {
  float2 m0; // m00, m01
  float2 m1; // m10, m11
  float2 t;  // tx, ty
};

struct Uniforms {
  float2 scale;
  float2 offset;
};

struct VertexIn {
  float2 position [[attribute(0)]];
  float4 color [[attribute(1)]];
  ushort xform_index [[attribute(2)]];
};

struct VertexOut {
  float4 position [[position]];
  float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]],
                             constant LocalXFrom *xforms [[buffer(2)]]) {
  LocalXFrom xf = xforms[in.xform_index];

  float2 world =
      float2(xf.m0.x * in.position.x + xf.m0.y * in.position.y + xf.t.x,
             xf.m1.x * in.position.x + xf.m1.y * in.position.y + xf.t.y);
  float2 clip = world * u.scale + u.offset;

  return {.position = float4(clip, 0.0, 1.0), .color = in.color};
}

fragment float4 fragment_main(VertexOut input [[stage_in]]) {
  return input.color;
}

struct TextureVertexIn {
  float2 position [[attribute(0)]];
  float2 texcoord [[attribute(1)]];
  half4 color [[attribute(2)]];
};

struct TextureVertexOut {
  float4 position [[position]];
  float2 texcoord;
  half4 color;
};

vertex TextureVertexOut texture_vertex_main(TextureVertexIn in [[stage_in]]) {
  TextureVertexOut out;

  out.position = float4(in.position, 0, 1);
  out.texcoord = in.texcoord;
  out.color = in.color;

  return out;
}

fragment float4 texture_fragment_main(TextureVertexOut input [[stage_in]],
                                      texture2d<float> tex [[texture(0)]]) {
  constexpr sampler s(mag_filter::nearest, min_filter::nearest);
  float4 texel = tex.sample(s, input.texcoord);

  return texel * float4(input.color);
}
