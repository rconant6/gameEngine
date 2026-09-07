const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const math = @import("math");
const WorldPoint = math.WorldPoint;
const bridge = @import("metal_bridge.zig");
const mb = bridge.MetalBridge;
const Batch = @import("../../batch.zig").IndexedBatch;
const tess = @import("../../tess.zig");
const LocalXTransform = tess.LocalXform;
const ClipMap = tess.ClipMap;
const visual = @import("visual");
const Renderable = visual.Renderable;
const Transform = visual.Transform;
const Color = visual.Color;
const Colors = visual.Colors;
const ctxm = @import("../../context.zig");
const RenderConfig = ctxm.RendererConfig;
const log = @import("debug").log;

const metal = @import("metal_types.zig");
const CAMetalDrawable = metal.CAMetalDrawable;
const CAMetalLayer = metal.CAMetalLayer;
const ClearColor = metal.ClearColor;
const DrawKey = metal.DrawKey;
const MTLBuffer = metal.MTLBuffer;
const MTLCommandBuffer = metal.MTLCommandBuffer;
const MTLCommandQueue = metal.MTLCommandQueue;
const MTLDevice = metal.MTLDevice;
const MTLError = metal.MetalError;
const MTLLibrary = metal.MTLLibrary;
const MTLLoadAction = metal.MTLLoadAction;
const MTLPixelFormat = metal.MTLPixelFormat;
const MTLRenderCommandEncoder = metal.MTLRenderCommandEncoder;
const MTLRenderPipelineState = metal.MTLRenderPipelineState;
const MTLResourceOptions = metal.MTLResourceOptions;
const MTLStoreAction = metal.MTLStoreAction;
const MTLTexture = metal.MTLTexture;
const MetalFrame = metal.MetalFrame;
const MetalFrameContext = metal.MetalFrameContext;
const MetalVertex = metal.MetalVertex;

const Self = @This();

const SLOT_BYTES: usize = 2 * 1024 * 1024;
const INDEX_SLOT_BYTES: usize = 2 * 1024 * 1024;
const XFORM_SLOT_BYTES: usize = 1024 * 1024;
const FRAMES_IN_FLIGHT: usize = 3;

pub const Texture = MTLTexture;
pub const Device = MTLDevice;

device: *MTLDevice,
command_queue: *MTLCommandQueue,
layer: *CAMetalLayer,
submission_seq: u32,
clip_world: ClipMap = .{},
clip_screen: ClipMap = .{},

pipeline_shape: *MTLRenderPipelineState, // fragment_shape (tex * color)
pipeline_sdf: *MTLRenderPipelineState, // fragment_sdf (coverage blend)
batch: Batch(MetalVertex, DrawKey),
frame_ctx: *MetalFrameContext,
frame_index: u8, // ring cursor (0..2)
vertex_buffers: [3]*MTLBuffer, // geometry ring
index_buffers: [3]*MTLBuffer, // sprite ring
xform_buffers: [3]*MTLBuffer, // xform ring
xforms: ArrayList(LocalXTransform),

width: u32,
height: u32,

clear_color: Color,
white_texture: *MTLTexture,

frame_number: u64,
start_time: f64,
last_frame_time: f64,

persistent: Allocator,

pub fn init(
    persistent: std.mem.Allocator,
    io: std.Io,
    config: RenderConfig,
) (MTLError || std.mem.Allocator.Error)!Self {
    const layer = try mb.getLayerFromView(config.native_handle.?);
    const device = try mb.createDevice();
    const queue = try mb.createCommandQueue(device);

    const shader_path = try getShaderPath(persistent, io);
    defer persistent.free(shader_path);
    const shader_path_z = try persistent.dupeZ(u8, shader_path);
    defer persistent.free(shader_path_z);
    const library = try mb.createLibraryFromFile(device, shader_path_z);
    const vertex_fn = try mb.createFunction(library, "vertex_main");
    const fragment_shape_fn = try mb.createFunction(library, "fragment_shape");
    const fragment_sdf_fn = try mb.createFunction(library, "fragment_sdf");

    // Two pipelines sharing everything but the fragment fn. Selected per draw by
    const pipeline_shape = try mb.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_shape_fn,
        MTLPixelFormat.bgra8Unorm_sRGB,
        config.msaa_samples,
    );
    const pipeline_sdf = try mb.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_sdf_fn,
        MTLPixelFormat.bgra8Unorm_sRGB,
        config.msaa_samples,
    );

    // CPU-side batches
    const batch = Batch(MetalVertex, DrawKey).init(persistent);

    // Vertex buffers: rings of FRAMES_IN_FLIGHT
    const options = @intFromEnum(MTLResourceOptions.storageModeShared);
    var vertex_buffers: [3]*MTLBuffer = undefined;
    var index_buffers: [3]*MTLBuffer = undefined;
    var xform_buffers: [3]*MTLBuffer = undefined;
    for (&vertex_buffers) |*b| b.* = try mb.createBuffer(
        device,
        SLOT_BYTES,
        options,
    );
    for (&index_buffers) |*b| b.* = try mb.createBuffer(
        device,
        INDEX_SLOT_BYTES,
        options,
    );
    for (&xform_buffers) |*b| b.* = try mb.createBuffer(
        device,
        XFORM_SLOT_BYTES,
        options,
    );

    const white_tex = try mb.createTexture(device, 1, 1, .rgba8Unorm);
    const white_px = [_]u8{ 255, 255, 255, 255 };
    mb.uploadTextureData(white_tex, 1, 1, &white_px, 4);

    const frame_ctx = try mb.frameContextCreate(
        device,
        queue,
        layer,
        FRAMES_IN_FLIGHT,
    );

    mb.frameContextSetMsaa(
        frame_ctx,
        config.msaa_samples,
        config.width,
        config.height,
    );

    return Self{
        .device = device,
        .command_queue = queue,
        .layer = layer,
        .pipeline_shape = pipeline_shape,
        .pipeline_sdf = pipeline_sdf,
        .batch = batch,
        .frame_ctx = frame_ctx,
        .frame_index = 0,
        .vertex_buffers = vertex_buffers,
        .index_buffers = index_buffers,
        .width = config.width,
        .height = config.height,
        .clear_color = Colors.MAGENTA,
        .white_texture = white_tex,
        .frame_number = 0,
        .start_time = 0.0,
        .last_frame_time = 0.0,
        .persistent = persistent,
        .xforms = .empty,
        .xform_buffers = xform_buffers,
        .submission_seq = 0,
    };
}
fn getShaderPath(gpa: std.mem.Allocator, io: std.Io) ![]const u8 {
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &path_buf) catch return MTLError.ShaderPathError;
    const exe_path = path_buf[0..exe_len];
    const exe_dir = std.fs.path.dirname(exe_path) orelse return MTLError.ShaderPathError;

    return std.fs.path.join(gpa, &.{ exe_dir, "default.metallib" }) catch {
        return MTLError.ShaderPathError;
    };
}

pub fn deinit(self: *Self) void {
    mb.frameContextWaitIdle(self.frame_ctx);

    self.batch.deinit();

    for (self.vertex_buffers) |b| mb.release(b);
    for (self.index_buffers) |tb| mb.release(tb);
    for (self.xform_buffers) |xb| mb.release(xb);

    mb.release(self.pipeline_shape);
    mb.release(self.pipeline_sdf);
    mb.frameContextDestroy(self.frame_ctx);

    self.xforms.deinit(self.persistent);
}

// Narrow the engine's backend-agnostic PixelFormat to Metal's native type. The
// only place MTLPixelFormat meets the engine enum — nothing above here sees MTL*.
fn toMTL(f: visual.PixelFormat) MTLPixelFormat {
    return switch (f) {
        .r8 => .r8Unorm,
        .rgba8 => .rgba8Unorm,
        .bgra8_srgb => .bgra8Unorm_sRGB,
    };
}

pub fn createTexture(self: *Self, width: u32, height: u32, format: visual.PixelFormat) !*MTLTexture {
    return mb.createTexture(self.device, width, height, toMTL(format));
}

pub fn uploadTextureData(
    _: *Self,
    texture: *MTLTexture,
    width: u32,
    height: u32,
    data: [*]const u8,
    bytes_per_row: u32,
) void {
    mb.uploadTextureData(texture, width, height, data, bytes_per_row);
}

pub fn resize(self: *Self, width: u32, height: u32) !void {
    self.width = width;
    self.height = height;

    // TODO: Recreate metal resources if needed on resize
}

pub fn clear(self: Self) void {
    // NOTE: nothing needs to happen, render pass does it
    _ = self;
}

pub fn setClearColor(self: *Self, color: Color) void {
    self.clear_color = color;
}

// TODO:TODO sprites route through render() as a textured Renderable
// (unified vertex + one batch). The old CPU-baked addSprite path is gone.
pub fn drawTextureQuad(
    _: *Self,
    _: *MTLTexture,
    _: f32,
    _: f32,
    _: [2]f32,
    _: ?Transform,
    _: anytype,
    _: bool,
    _: bool,
    _: Color,
) void {}

pub fn render(self: *Self, r: Renderable, ctx: anytype) void {
    const xform_index: u16 = if (r.transform == null) 0 else blk: {
        const idx: u16 = @intCast(self.xforms.items.len);
        self.xforms.append(
            self.persistent,
            tess.LocalXform.from(r.transform),
        ) catch |err| {
            log.err(.renderer, "Failed to store xform {any}", .{err});
            break :blk 0; // fall back to identity rather than a bad index
        };
        break :blk idx;
    };

    const is_screen = r.space == .screen;

    if (is_screen) {
        self.clip_screen = ClipMap.fromScreen(ctx);
    } else {
        self.clip_world = ClipMap.fromWorld(ctx);
    }

    const tex: *MTLTexture = if (r.texture) |t|
        @ptrCast(@alignCast(t))
    else
        self.white_texture;

    const idx0 = self.batch.indexMark();

    const px_per_unit =
        if (is_screen)
            1.0
        else
            @as(f32, @floatFromInt(ctx.height)) / (2.0 * ctx.ortho_size);

    const half = r.style.stroke_width / 2.0;

    const hw: f32 = if (is_screen) half else blk: {
        break :blk half / px_per_unit;
    };

    tess.tessellate(
        MetalVertex,
        DrawKey,
        &self.batch,
        metal.makeVertex,
        r.shape,
        r.uv,
        xform_index,
        r.style,
        hw,
        px_per_unit,
    ) catch {
        log.err(.renderer, "Failed to tessellate shape {any}", .{@TypeOf(r.shape)});
    };

    const key: DrawKey = .{
        .prim = .triangle,
        .space = @enumFromInt(@intFromEnum(r.space)),
        .tex = tex,
        .is_sdf = r.sdf,
    };

    const sort_key = (@as(u64, @bitCast(@as(i64, r.layer))) << 32) | self.submission_seq;
    self.submission_seq += 1;

    self.batch.pushIndexed(
        key,
        sort_key,
        idx0,
        self.batch.indexMark() - idx0,
    ) catch |err| {
        log.err(.renderer, "Failed to push draw call {any}", .{err});
    };
}

pub fn beginFrame(self: *Self) !void {
    self.batch.clear();
    self.xforms.clearRetainingCapacity();
    try self.xforms.append(self.persistent, LocalXTransform.identity);
    self.frame_index +%= 1;
    self.frame_number += 1;
}

pub fn endFrame(self: *Self) !void {
    const frame = mb.frameBegin(
        self.frame_ctx,
        ClearColor.fromColor(self.clear_color),
    ) orelse return;

    const idx = @mod(self.frame_index, 3);
    const enc = mb.frameEncoder(frame);

    try self.flushOrdered(enc, idx);

    mb.frameEnd(self.frame_ctx, frame);
}

fn flushOrdered(self: *Self, encoder: *MTLRenderCommandEncoder, idx: usize) !void {
    if (self.batch.vertices.items.len == 0) return;

    const v_copied = try uploadRing(
        MetalVertex,
        self.vertex_buffers[idx],
        self.batch.vertices.items,
        SLOT_BYTES,
        "vertex",
    );
    const i_copied = try uploadRing(
        u32,
        self.index_buffers[idx],
        self.batch.indices.items,
        INDEX_SLOT_BYTES,
        "index",
    );
    const x_copied = try uploadRing(
        LocalXTransform,
        self.xform_buffers[idx],
        self.xforms.items,
        XFORM_SLOT_BYTES,
        "xform",
    );
    _ = x_copied;

    // Pipeline is bound inside the loop, keyed on is_sdf (see cur_sdf guard).
    // Vertex buffers are pipeline-independent, bind once here.
    mb.setVertexBuffer(encoder, self.vertex_buffers[idx], 0, 0);
    mb.setVertexBuffer(encoder, self.xform_buffers[idx], 0, 2);

    self.batch.sortCalls();
    self.batch.mergeAdjacent();

    if (self.frame_number % 60 == 0)
        log.info(.renderer, "draw_calls={d} verts={d} idxs={d}", .{
            self.batch.draw_calls.items.len,
            self.batch.vertices.items.len,
            self.batch.indices.items.len,
        });

    var cur_tex: ?*MTLTexture = null;
    var cur_space: ?metal.Space = null;
    var cur_sdf: ?bool = null;

    _ = v_copied;
    for (self.batch.draw_calls.items) |call| {
        if (call.index_start + call.index_count > i_copied) break;

        if (cur_space == null or cur_space.? != call.key.space) {
            const map = if (call.key.space == .screen)
                &self.clip_screen
            else
                &self.clip_world;

            mb.setVertexBytes(encoder, map, @sizeOf(ClipMap), 1);
            cur_space = call.key.space;
        }

        if (cur_tex == null or cur_tex.? != call.key.tex) {
            mb.setFragmentTexture(encoder, call.key.tex, 0);
            cur_tex = call.key.tex;
        }

        if (cur_sdf == null or cur_sdf.? != call.key.is_sdf) {
            const pipeline = if (call.key.is_sdf)
                self.pipeline_sdf
            else
                self.pipeline_shape;
            mb.setPipelineState(encoder, pipeline);
            cur_sdf = call.key.is_sdf;
        }

        mb.drawIndexedPrimitives(
            encoder,
            call.key.prim,
            call.index_count,
            self.index_buffers[idx],
            call.index_start * @sizeOf(u32), // byte offset into the index buffer
            0, // absolute indices — GPU adds no base_vertex
        );
    }
}

fn uploadRing(
    comptime T: type,
    dst: *MTLBuffer,
    items: []const T,
    slot_bytes: usize,
    label: []const u8,
) !usize {
    const dst_ptr = try mb.getBufferContents(dst);
    const elem = @sizeOf(T);
    const want = items.len * elem;
    const copy_bytes = @min(want, slot_bytes - slot_bytes % elem);

    if (want > slot_bytes) {
        log.err(
            .renderer,
            "{s} ring overflow: {d} B > slot {d} B; truncating to {d} items",
            .{ label, want, slot_bytes, copy_bytes / elem },
        );
    }

    @memcpy(
        @as([*]u8, @ptrCast(dst_ptr))[0..copy_bytes],
        @as([*]const u8, @ptrCast(items.ptr))[0..copy_bytes],
    );
    return copy_bytes / elem;
}
