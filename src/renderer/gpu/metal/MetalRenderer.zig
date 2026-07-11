const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("math");
const WorldPoint = math.WorldPoint;
const bridge = @import("metal_bridge.zig");
const BridgeError = bridge.BridgeError;
const mb = bridge.MetalBridge;
const Batch = @import("../../batch.zig").Batch;
const tess = @import("../../tess.zig");
const LocalXTransform = tess.LocalXform;
const ClipMap = tess.ClipMap;
const rt = @import("../../render_types.zig");
const DrawStyle = rt.DrawStyle;
const Renderable = rt.Renderable;
const RenderConfig = rt.RendererConfig;
const RenderContext = rt.RenderContext;
const Transform = rt.Transform;
const col = @import("../../color.zig");
const Color = col.Color;
const Colors = col.Colors;
const ShapeData = @import("registry").ShapeData;
const log = @import("debug").log;

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
const MetalVertex = metal.MetalVertex;
const MetalTextureVertex = metal.MetalTextureVertex;
const MTLResourceOptions = metal.MTLResourceOptions;
const MTLError = metal.MetalError;
const MTLLoadAction = metal.MTLLoadAction;
const MTLStoreAction = metal.MTLStoreAction;
const MTLTexture = metal.MTLTexture;
const MetalFrameContext = metal.MetalFrameContext;
const MetalFrame = metal.MetalFrame;

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

batch: Batch(MetalVertex, metal.GeomKey),

texture_pipeline_state: *MTLRenderPipelineState,
texture_batch: Batch(MetalTextureVertex, metal.TexKey),

frame_ctx: *MetalFrameContext,
frame_index: u8, // ring cursor (0..2)
vertex_buffers: [3]*MTLBuffer, // geometry ring
texture_vertex_buffers: [3]*MTLBuffer, // sprite ring

width: u32,
height: u32,
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

    // Both pipelines' rasterSampleCount MUST match the render target's sample
    // count (the MSAA texture below), or Metal throws at draw.
    const pipeline_state = try mb.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_fn,
        MTLPixelFormat.bgra8Unorm,
        config.msaa_samples,
    );
    const texture_pipeline_state = try mb.createTexturePipelineState(
        device,
        tex_vertex_fn,
        tex_fragment_fn,
        MTLPixelFormat.bgra8Unorm,
        config.msaa_samples,
    );

    // CPU-side batches
    const batch = Batch(MetalVertex, metal.GeomKey).init(p_gpa);
    const tex_batch = Batch(MetalTextureVertex, metal.TexKey).init(p_gpa);

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
    // Create the MSAA color texture the render pass resolves from. Sized to the
    // physical drawable (config.width/height). msaa_samples <= 1 → nil → MSAA off.
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
    const tl: WorldPoint = .{ .x = -half_w - ox, .y = half_h - oy };
    const tr: WorldPoint = .{ .x = half_w - ox, .y = half_h - oy };
    const bl: WorldPoint = .{ .x = -half_w - ox, .y = -half_h - oy };
    const br: WorldPoint = .{ .x = half_w - ox, .y = -half_h - oy };

    // Same local→clip pipeline as tess.emit: LocalXform (scale/rotate/translate)
    // then ClipMap. Sprites are always world-space. Keeps sprites and shapes on
    // one transform path so 2.2's camera-on-GPU move only touches one place.
    const xf = tess.LocalXform.from(transform);
    const map = tess.ClipMap.fromWorld(ctx);
    const clip_tl = map.apply(xf.apply(tl));
    const clip_tr = map.apply(xf.apply(tr));
    const clip_bl = map.apply(xf.apply(bl));
    const clip_br = map.apply(xf.apply(br));

    const u_tl: f32 = if (flip_h) 1.0 else 0.0;
    const u_tr: f32 = if (flip_h) 0.0 else 1.0;
    const u_bl: f32 = if (flip_h) 1.0 else 0.0;
    const u_br: f32 = if (flip_h) 0.0 else 1.0;

    const v_tl: f32 = if (flip_v) 1.0 else 0.0;
    const v_tr: f32 = if (flip_v) 1.0 else 0.0;
    const v_bl: f32 = if (flip_v) 0.0 else 1.0;
    const v_br: f32 = if (flip_v) 0.0 else 1.0;

    self.addSprite(texture, .{ clip_tl, clip_tr, clip_bl, clip_br }, .{
        .{ u_tl, v_tl },
        .{ u_tr, v_tr },
        .{ u_bl, v_bl },
        .{ u_br, v_br },
    }) catch |err| {
        log.err(.renderer, "Failed to batch textured sprite {any}", .{err});
    };
}

// Emits a textured quad (2 tris, 6 verts) into the texture batch. Metal-specific
// sprite geometry — lives with the renderer that owns MetalTextureVertex/TexKey.
fn addSprite(
    self: *Self,
    texture: *MTLTexture,
    clip_corners: [4][2]f32, // TL, TR, BL, BR in clip space
    uvs: [4][2]f32, // TL, TR, BL, BR in uv coords
) !void {
    const start: u32 = self.texture_batch.mark();
    const verts = [6]MetalTextureVertex{
        // TRI 1
        .{ .position = clip_corners[0], .texcoord = uvs[0] },
        .{ .position = clip_corners[1], .texcoord = uvs[1] },
        .{ .position = clip_corners[2], .texcoord = uvs[2] },
        // TRI 2
        .{ .position = clip_corners[1], .texcoord = uvs[1] },
        .{ .position = clip_corners[3], .texcoord = uvs[3] },
        .{ .position = clip_corners[2], .texcoord = uvs[2] },
    };
    for (verts) |v| try self.texture_batch.vertex(v);
    try self.texture_batch.pushCall(.{ .tex = texture }, start, 6);
}

pub fn render(self: *Self, r: Renderable, ctx: RenderContext) void {
    const xf = tess.LocalXform.from(r.transform);
    const is_screen = r.space == .screen;
    const px_per_unit =
        if (is_screen) 1.0 else @as(
            f32,
            @floatFromInt(ctx.height),
        ) / (2.0 * ctx.ortho_size);
    const map = if (is_screen)
        ClipMap.fromScreen(ctx)
    else
        ClipMap.fromWorld(ctx);
    const half = r.style.stroke_width / 2.0;
    const hw: f32 = if (is_screen) half else blk: {
        break :blk half / px_per_unit;
    };
    tess.tessellate(
        MetalVertex,
        metal.GeomKey,
        &self.batch,
        metal.makeVertex,
        .{ .prim = .triangle },
        r.shape,
        xf,
        r.style,
        map,
        hw,
        px_per_unit,
    ) catch {
        log.err(.renderer, "Failed to tessellate shape {any}", .{@TypeOf(r.shape)});
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
    const vertex_size = @sizeOf(MetalVertex);
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
            call.key.prim,
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
    const vertex_size = @sizeOf(MetalTextureVertex);
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

        mb.setFragmentTexture(encoder, call.key.tex, 0);
        mb.drawPrimitives(encoder, .triangle, call.vertex_start, call.vertex_count);
    }
}
