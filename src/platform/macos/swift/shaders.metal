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
  float2 texcoord [[attribute(1)]];
  float4 color [[attribute(2)]];
  ushort xform_index [[attribute(3)]];
};

struct VertexOut {
  float4 position [[position]];
  float2 texcoord;
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

  return {.position = float4(clip, 0.0, 1.0),
          .texcoord = in.texcoord,
          .color = in.color};
}

fragment float4 fragment_main(VertexOut input [[stage_in]]) {
  constexpr sampler s(mag_filter::nearest, min_filter::nearest);
  return tex.sample(s, input.texcoord) * input.color;
}
