const std = @import("std");
const Allocator = std.mem.Allocator;
const bridge = @import("metal_bridge.zig");
const BridgeError = bridge.BridgeError;
const mb = bridge.MetalBridge;
const GeometryBatch = @import("geometry_batch.zig").GeometryBatch;
const TextureBatch = @import("texture_batch.zig").TextureBatch;
const metal = @import("metal_types.zig");
const MTLDevice = metal.MTLDevice;
const MTLRenderCommandEncoder = metal.MTLRenderCommandEncoder;
const MTLCommandQueue = metal.MTLCommandQueue;
const MTLCommandBuffer = metal.MTLCommandBuffer;
const CAMetalLayer = metal.CAMetalLayer;
const CAMetalDrawable = metal.CAMetalDrawable;
const MTLRenderPipelineState = metal.MTLRenderPipelineState;
const MTLBuffer = metal.MTLBuffer;
const MTLLibrary = metal.MTLLibrary;
const MTLPixelFormat = metal.MTLPixelFormat;
const ClearColor = metal.ClearColor;
const Vertex = metal.Vertex;
const TextureVertex = metal.TextureVertex;
const MTLResourceOptions = metal.MTLResourceOptions;
const MTLError = metal.MetalError;
const MTLLoadAction = metal.MTLLoadAction;
const MTLStoreAction = metal.MTLStoreAction;
const MTLTexture = metal.MTLTexture;
const MetalFrameContext = metal.MetalFrameContext;
const MetalFrame = metal.MetalFrame;
const rend = @import("../../renderer.zig");
const WorldPoint = rend.WorldPoint;
const RenderConfig = rend.RendererConfig;
const ShapeData = rend.ShapeData;
const Color = @import("../../color.zig").Color;
const Colors = @import("../../color.zig").Colors;
const RenderContext = @import("../../RenderContext.zig");
const utils = @import("../../geometry_utils.zig");
const Transform = utils.Transform;
const debug = @import("debug");
const log = debug.log;

const Self = @This();
const SLOT_BYTES: usize = 2 * 1024 * 1024;
const TEX_SLOT_BYTES: usize = 512 * 1024;
const FRAMES_IN_FLIGHT: usize = 3;

pub const Texture = MTLTexture;
pub const Device = MTLDevice;

device: *MTLDevice,
command_queue: *MTLCommandQueue,
layer: *CAMetalLayer,

pipeline_state: *MTLRenderPipelineState,

batch: GeometryBatch,

texture_pipeline_state: *MTLRenderPipelineState,
texture_batch: TextureBatch,

frame_ctx: *MetalFrameContext,
frame_index: u8, // ring cursor (0..2)
vertex_buffers: [3]*MTLBuffer, // geometry ring
texture_vertex_buffers: [3]*MTLBuffer, // sprite ring

width: u32,
height: u32,
scale_factor: f32,
clear_color: Color,
frame_number: u64,
start_time: f64,
last_frame_time: f64,

persistent: Allocator,

pub fn init(
    p_gpa: std.mem.Allocator,
    io: std.Io,
    config: RenderConfig,
) (MTLError || std.mem.Allocator.Error)!Self {
    const layer = try mb.getLayerFromView(config.native_handle.?);
    const device = try mb.createDevice();
    const queue = try mb.createCommandQueue(device);

    const shader_path = try getShaderPath(p_gpa, io);
    defer p_gpa.free(shader_path);
    const shader_path_z = try p_gpa.dupeZ(u8, shader_path);
    defer p_gpa.free(shader_path_z);
    const library = try mb.createLibraryFromFile(device, shader_path_z);
    const vertex_fn = try mb.createFunction(library, "vertex_main");
    const fragment_fn = try mb.createFunction(library, "fragment_main");
    const tex_vertex_fn = try mb.createFunction(library, "texture_vertex_main");
    const tex_fragment_fn = try mb.createFunction(library, "texture_fragment_main");

    const pipeline_state = try mb.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_fn,
        MTLPixelFormat.bgra8Unorm,
    );
    const texture_pipeline_state = try mb.createTexturePipelineState(
        device,
        tex_vertex_fn,
        tex_fragment_fn,
        MTLPixelFormat.bgra8Unorm,
    );

    // CPU-side batches
    const batch = GeometryBatch.init(p_gpa);
    const tex_batch = TextureBatch.init(p_gpa);

    // Vertex buffers: rings of FRAMES_IN_FLIGHT
    const options = @intFromEnum(MTLResourceOptions.storageModeShared);
    var vertex_buffers: [3]*MTLBuffer = undefined;
    var texture_vertex_buffers: [3]*MTLBuffer = undefined;
    for (&vertex_buffers) |*b| b.* = try mb.createBuffer(
        device,
        SLOT_BYTES,
        options,
    );
    for (&texture_vertex_buffers) |*b| b.* = try mb.createBuffer(
        device,
        TEX_SLOT_BYTES,
        options,
    );

    const frame_ctx = try mb.frameContextCreate(
        device,
        queue,
        layer,
        FRAMES_IN_FLIGHT,
    );

    return Self{
        .device = device,
        .command_queue = queue,
        .layer = layer,
        .pipeline_state = pipeline_state,
        .batch = batch,
        .texture_pipeline_state = texture_pipeline_state,
        .texture_batch = tex_batch,
        .frame_ctx = frame_ctx,
        .frame_index = 0,
        .vertex_buffers = vertex_buffers,
        .texture_vertex_buffers = texture_vertex_buffers,
        .width = config.width,
        .height = config.height,
        .scale_factor = 1.0, // need to get from platform?
        .clear_color = Colors.MAGENTA,
        .frame_number = 0,
        .start_time = 0.0,
        .last_frame_time = 0.0,
        .persistent = p_gpa,
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
    self.texture_batch.deinit();

    for (self.vertex_buffers) |b| mb.release(b);
    for (self.texture_vertex_buffers) |tb| mb.release(tb);

    mb.release(self.pipeline_state);
    mb.release(self.texture_pipeline_state);
    mb.frameContextDestroy(self.frame_ctx);
}

pub fn createTexture(self: *Self, width: u32, height: u32) !*MTLTexture {
    return mb.createTexture(self.device, width, height);
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

pub fn drawTextureQuad(
    self: *Self,
    texture: *MTLTexture,
    // position: WorldPoint, // center position in world space
    width: f32, // world-space width
    height: f32, // world-space height
    origin: [2]f32, // normalized origin [0-1, 0-1] within the sprite
    transform: ?Transform, // scale/rotate/translate
    ctx: RenderContext,
    flip_h: bool,
    flip_v: bool,
) void {
    const half_w = width / 2;
    const half_h = height / 2;
    const ox = (origin[0] - 0.5) * width;
    const oy = (origin[1] - 0.5) * height;
    var tl: WorldPoint = .{ .x = -half_w - ox, .y = half_h - oy };
    var tr: WorldPoint = .{ .x = half_w - ox, .y = half_h - oy };
    var bl: WorldPoint = .{ .x = -half_w - ox, .y = -half_h - oy };
    var br: WorldPoint = .{ .x = half_w - ox, .y = -half_h - oy };

    if (transform) |t| {
        tl = utils.transformPoint(tl, t);
        tr = utils.transformPoint(tr, t);
        bl = utils.transformPoint(bl, t);
        br = utils.transformPoint(br, t);
    }

    const clip_tl = utils.worldToClipSpace(tl, ctx);
    const clip_tr = utils.worldToClipSpace(tr, ctx);
    const clip_bl = utils.worldToClipSpace(bl, ctx);
    const clip_br = utils.worldToClipSpace(br, ctx);

    const u_tl: f32 = if (flip_h) 1.0 else 0.0;
    const u_tr: f32 = if (flip_h) 0.0 else 1.0;
    const u_bl: f32 = if (flip_h) 1.0 else 0.0;
    const u_br: f32 = if (flip_h) 0.0 else 1.0;

    const v_tl: f32 = if (flip_v) 1.0 else 0.0;
    const v_tr: f32 = if (flip_v) 1.0 else 0.0;
    const v_bl: f32 = if (flip_v) 0.0 else 1.0;
    const v_br: f32 = if (flip_v) 0.0 else 1.0;

    self.texture_batch.addSprite(texture, .{ clip_tl, clip_tr, clip_bl, clip_br }, .{
        .{ u_tl, v_tl },
        .{ u_tr, v_tr },
        .{ u_bl, v_bl },
        .{ u_br, v_br },
    }) catch |err| {
        log.err(.renderer, "Failed to batch textured sprite {any}", .{err});
    };
}
pub fn drawShape(
    self: *Self,
    shape: ShapeData,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
    ctx: RenderContext,
) void {
    self.batch.addShape(
        shape,
        transform,
        fill_color,
        stroke_color,
        stroke_width,
        ctx,
    ) catch {
        log.err(.renderer, "Failed to batch shape {any}", .{@TypeOf(shape)});
    };
}

pub fn beginFrame(self: *Self) !void {
    self.batch.clear();
    self.texture_batch.clear();
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

    try self.flushGeometryBatch(enc, idx);
    try self.flushTextureBatch(enc, idx);

    mb.frameEnd(self.frame_ctx, frame);
}

fn flushGeometryBatch(self: *Self, encoder: *MTLRenderCommandEncoder, idx: u8) !void {
    const vertices = self.batch.vertices.items;
    if (vertices.len == 0) return;

    const buffer = self.vertex_buffers[idx];
    const buffer_ptr = try mb.getBufferContents(buffer);
    const vertex_size = @sizeOf(Vertex);
    const bytes_to_copy = vertices.len * vertex_size;

    const copy_bytes = if (bytes_to_copy > SLOT_BYTES) blk: {
        const clamped = (SLOT_BYTES / vertex_size) * vertex_size;
        log.err(
            .renderer,
            "Geometry overflow: {d}B > slot {d} B; truncated to {d} verts",
            .{ bytes_to_copy, SLOT_BYTES, clamped / vertex_size },
        );
        break :blk clamped;
    } else bytes_to_copy;
    const copied_vertex_count = copy_bytes / vertex_size;

    @memcpy(
        @as([*]u8, @ptrCast(buffer_ptr))[0..copy_bytes],
        @as([*]const u8, @ptrCast(vertices.ptr))[0..copy_bytes],
    );

    mb.setPipelineState(encoder, self.pipeline_state);
    mb.setVertexBuffer(encoder, buffer, 0, 0);

    for (self.batch.draw_calls.items) |call| {
        if (call.vertex_start + call.vertex_count > copied_vertex_count) break;

        mb.drawPrimitives(
            encoder,
            call.primitive_type,
            call.vertex_start,
            call.vertex_count,
        );
    }
}

fn flushTextureBatch(self: *Self, encoder: *MTLRenderCommandEncoder, idx: u8) !void {
    const vertices = self.texture_batch.vertices.items;
    if (vertices.len == 0) return;

    const buffer = self.texture_vertex_buffers[idx];
    const buffer_ptr = try mb.getBufferContents(buffer);
    const vertex_size = @sizeOf(TextureVertex);
    const bytes_to_copy = vertices.len * vertex_size;

    const copy_bytes = if (bytes_to_copy > TEX_SLOT_BYTES) blk: {
        const clamped = (TEX_SLOT_BYTES / vertex_size) * vertex_size;
        log.err(.renderer, "Texture overflow: {d} B > slot {d} B; truncating to {d} verts", .{
            bytes_to_copy, TEX_SLOT_BYTES, clamped / vertex_size,
        });
        break :blk clamped;
    } else bytes_to_copy;
    const copied_vertex_count = copy_bytes / vertex_size;

    @memcpy(
        @as([*]u8, @ptrCast(buffer_ptr))[0..copy_bytes],
        @as([*]const u8, @ptrCast(vertices.ptr))[0..copy_bytes],
    );

    mb.setPipelineState(encoder, self.texture_pipeline_state);
    mb.setVertexBuffer(encoder, buffer, 0, 0);

    for (self.texture_batch.draw_calls.items) |call| {
        if (call.vertex_start + call.vertex_count > copied_vertex_count) break;

        mb.setFragmentTexture(encoder, call.texture, 0);
        mb.drawPrimitives(encoder, .triangle, call.vertex_start, call.vertex_count);
    }
}
