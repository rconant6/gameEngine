const std = @import("std");

pub const CAMetalDrawable = opaque {};
pub const CAMetalLayer = opaque {};
pub const MTLBuffer = opaque {};
pub const MTLCommandBuffer = opaque {};
pub const MTLCommandQueue = opaque {};
pub const MTLDevice = opaque {};
pub const MTLFunction = opaque {};
pub const MTLLibrary = opaque {};
pub const MTLRenderCommandEncoder = opaque {};
pub const MTLRenderPassDescriptor = opaque {};
pub const MTLRenderPipelineState = opaque {};
pub const MTLTexture = opaque {};

pub const Vertex = extern struct {
    position: [2]f32, // x, y, in clip space [-1, 1]
    color: [4]f32, // r, g, b, a in range [0, 1]
};
pub const VertexBufferPool = struct {
    buffers: std.ArrayList(*MTLBuffer),
    current_index: usize,
    buffer_size: usize,
    allocator: std.mem.Allocator,
};

pub const MTLPixelFormat = enum(u64) {
    invalid = 0,
    bgra8Unorm = 80,
    rgba8Unorm = 70,
    rgba16Float = 115,
    rgba32Float = 125,
};
pub const MTLLoadAction = enum(u64) {
    dontCare = 0,
    load = 1,
    clear = 2,
};
pub const MTLStoreAction = enum(u64) {
    dontCare = 0,
    store = 1,
    multisampleResolve = 2,
};
pub const MTLPrimitiveType = enum(u64) {
    point = 0,
    line = 1,
    lineStrip = 2,
    triangle = 3,
    triangleStrip = 4,
};

pub const PipelineConfig = struct {
    vertex_function_name: []const u8,
    fragment_function_name: []const u8,
    pixel_format: MTLPixelFormat,
    blend_enabled: bool,
};
pub const PipelineStates = struct {
    filled_shapes: ?*MTLRenderPipelineState,
    outlined_shapes: ?*MTLRenderPipelineState,
};

pub const ClearColor = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64,
};

// TODO: helper functions
// Color to vertexColor (f32RGBA)
