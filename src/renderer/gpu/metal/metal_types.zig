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
pub const MetalFrameContext = opaque {};
pub const MetalFrame = opaque {};

const Color = @import("../../color.zig").Color;

pub const MetalError = error{
    DeviceCreationFailed,
    CommandQueueCreationFailed,
    CommandBufferCreationFailed,

    BufferCreationFailed,
    BufferContentsUnavailable,

    LibraryCreationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    ShaderPathError,

    LayerUnavailable,
    DrawableUnavailable,
    TextureUnavailable,
    TextureCreationFailed,

    FrameContextCreationFailed,

    RenderPassCreationFailed,
    RenderEncoderCreationFailed,
};

pub const MetalVertex = extern struct {
    position: [2]f32, // x, y, in clip space [-1, 1]
    color: [4]f16, // LINEAR rgba, half precision (HW encodes to sRGB on write)
    xform_index: u16,
    _pad: u16 = 0,
};
pub const MetalTextureVertex = extern struct {
    position: [2]f32, // clip space x,y
    texcoord: [2]f32, // u, v in [0,1]
};
pub const VertexBufferPool = struct {
    buffers: std.ArrayList(*MTLBuffer),
    current_index: usize,
    buffer_size: usize,
    gpa: std.mem.Allocator,
};

const MTLStorageMode = enum(u32) {
    shared = 0x00,
    managed = 0x10,
    private = 0x20,
    memoryless = 0x30,
};
const MTLCPUCacheMode = enum(u32) {
    defaultCache = 0x00,
    writeCombined = 0x01,
};
const MTLHazardTrackingMode = enum(u32) {
    tracked = 0x00,
    untracked = 0x100,
};
pub const MTLResourceOptions = enum(u32) {
    storageModeShared = @intFromEnum(MTLStorageMode.shared),
    // storageModeManaged = @intFromEnum(MTLStorageMode.managed),
    // storageModePrivate = @intFromEnum(MTLStorageMode.private),
    // storageModeMemoryless = @intFromEnum(MTLStorageMode.memoryless),
    // cpuCacheModeDefaultCache = @intFromEnum(MTLCPUCacheMode.defaultCache),
    // cpuCacheModeWriteCombined = @intFromEnum(MTLCPUCacheMode.writeCombined),
    // hazardTrackingModeTracked = @intFromEnum(MTLHazardTrackingMode.tracked),
    // hazardTrackingModeUntracked = @intFromEnum(MTLHazardTrackingMode.untracked),
};

pub const MTLPixelFormat = enum(u64) {
    invalid = 0,
    bgra8Unorm = 80,
    bgra8Unorm_sRGB = 81, // sRGB twin of 80: HW encodes linear->sRGB on write
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

pub const Space = enum(u8) { world, screen };
// Grouping keys for Batch(V, K).pushCall merge logic.
pub const GeomKey = struct {
    prim: MTLPrimitiveType,
    space: Space,

    pub fn eql(a: GeomKey, b: GeomKey) bool {
        return a.prim == b.prim and a.space == b.space;
    }
};
pub const TexKey = struct {
    tex: *MTLTexture,
    pub fn eql(a: TexKey, b: TexKey) bool {
        return a.tex == b.tex;
    }
};

pub fn makeVertex(pos: [2]f32, color: [4]f32, xform_index: u16) MetalVertex {
    return .{
        .position = pos,
        .color = .{
            @floatCast(color[0]),
            @floatCast(color[1]),
            @floatCast(color[2]),
            @floatCast(color[3]),
        },
        .xform_index = xform_index,
    };
}

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

    pub fn fromColor(c: Color) ClearColor {
        // LINEAR: the .bgra8Unorm_sRGB attachment encodes linear->sRGB on write,
        // so the clear value must be linear too (same funnel as the vertices).
        return .{
            .r = c.lin[0],
            .g = c.lin[1],
            .b = c.lin[2],
            .a = c.lin[3],
        };
    }
};

// TODO: helper functions
// Color to vertexColor (f32RGBA)
