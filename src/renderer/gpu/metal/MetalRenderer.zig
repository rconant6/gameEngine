const std = @import("std");
const bridge = @import("metal_bridge.zig");
const BridgeError = bridge.BridgeError;
const MetalBridge = bridge.MetalBridge;
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
const rend = @import("../../renderer.zig");
const WorldPoint = rend.WorldPoint;
const RenderConfig = rend.RendererConfig;
const ShapeData = rend.ShapeData;
const Color = @import("../../color.zig").Color;
const RenderContext = @import("../../RenderContext.zig");
const utils = @import("../../geometry_utils.zig");
const Transform = utils.Transform;
const debug = @import("debug");
const log = debug.log;

const Self = @This();
const MAX_VERT_SIZE: usize = 1024 * 1024 * 12; // 12MB of vertices storage

pub const Texture = MTLTexture;
pub const Device = MTLDevice;

device: *MTLDevice,
command_queue: *MTLCommandQueue,
layer: *CAMetalLayer,

pipeline_state: *MTLRenderPipelineState,
vertex_buffer: *MTLBuffer,
vertex_buffer_size: usize,
batch: GeometryBatch,

texture_pipeline_state: *MTLRenderPipelineState,
texture_vertex_buffer: *MTLBuffer,
texture_batch: TextureBatch,

current_drawable: ?*CAMetalDrawable,
current_command_buffer: ?*MTLCommandBuffer,

width: u32,
height: u32,
scale_factor: f32,
clear_color: Color,
frame_number: u64,
start_time: f64,
last_frame_time: f64,

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, io: std.Io, config: RenderConfig) (MTLError || std.mem.Allocator.Error)!Self {
    const layer = try MetalBridge.getLayerFromView(config.native_handle.?);
    const device = try MetalBridge.createDevice();
    const queue = try MetalBridge.createCommandQueue(device);

    const shader_path = try getShaderPath(allocator, io);
    defer allocator.free(shader_path);
    const shader_path_z = try allocator.dupeZ(u8, shader_path);
    defer allocator.free(shader_path_z);
    const library = try MetalBridge.createLibraryFromFile(device, shader_path_z);
    const vertex_fn = try MetalBridge.createFunction(library, "vertex_main");
    const fragment_fn = try MetalBridge.createFunction(library, "fragment_main");
    const tex_vertex_fn = try MetalBridge.createFunction(library, "texture_vertex_main");
    const tex_fragment_fn = try MetalBridge.createFunction(library, "texture_fragment_main");

    const vertex_size = @sizeOf(Vertex);
    const buffer_size = MAX_VERT_SIZE * vertex_size;
    const options = @intFromEnum(MTLResourceOptions.storageModeShared);
    const vertex_buffer = try MetalBridge.createBuffer(device, buffer_size, options);
    const batch = GeometryBatch.init(allocator);
    const pipeline_state = try MetalBridge.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_fn,
        MTLPixelFormat.bgra8Unorm,
    );

    const tex_buffer_size = 256 * 1024; // 256KB
    const tex_vertex_buffer = try MetalBridge.createBuffer(device, tex_buffer_size, options);
    const tex_batch = TextureBatch.init(allocator);
    const texture_pipeline_state = try MetalBridge.createTexturePipelineState(
        device,
        tex_vertex_fn,
        tex_fragment_fn,
        MTLPixelFormat.bgra8Unorm,
    );

    return Self{
        .device = device,
        .command_queue = queue,
        .layer = layer,
        .pipeline_state = pipeline_state,
        .vertex_buffer = vertex_buffer,
        .vertex_buffer_size = buffer_size,
        .batch = batch,
        .texture_pipeline_state = texture_pipeline_state,
        .texture_vertex_buffer = tex_vertex_buffer,
        .texture_batch = tex_batch,
        .current_drawable = null,
        .current_command_buffer = null,
        .width = config.width,
        .height = config.height,
        .scale_factor = 1.0, // TODO: get from platform
        .clear_color = Color.initRgba(255, 0, 255, 255), // black for now
        .frame_number = 0,
        .start_time = 0.0, // TODO: get time from platform
        .last_frame_time = 0.0,
        .allocator = allocator,
    };
}
fn getShaderPath(allocator: std.mem.Allocator, io: std.Io) ![]const u8 {
    var path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &path_buf) catch return MTLError.ShaderPathError;
    const exe_path = path_buf[0..exe_len];
    const exe_dir = std.fs.path.dirname(exe_path) orelse return MTLError.ShaderPathError;

    return std.fs.path.join(allocator, &.{ exe_dir, "default.metallib" }) catch {
        return MTLError.ShaderPathError;
    };
}

pub fn deinit(self: *Self) void {
    self.batch.deinit();
    self.texture_batch.deinit();
    // TODO: Release all the MTL resources
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
    // NOTE: Check if batch is getting too full, flush early to prevent overflow of 12MB
    const estimated_vertices_per_shape = 96;
    if (self.batch.vertices.items.len + estimated_vertices_per_shape > MAX_VERT_SIZE) {
        log.warn(.renderer, "Warning: Failed to flush batch before adding shape", .{});
    }

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

    self.current_drawable = try MetalBridge.nextDrawable(self.layer);
    self.current_command_buffer = try MetalBridge.createCommandBuffer(self.command_queue);

    self.frame_number += 1;
}

pub fn endFrame(self: *Self) !void {
    const render_pass = try MetalBridge.createRenderPassDescriptor();
    const drawable_texture = try MetalBridge.getDrawableTexture(self.current_drawable.?);
    MetalBridge.setColorAttachment(
        render_pass,
        drawable_texture,
        MTLLoadAction.clear,
        MTLStoreAction.store,
        ClearColor.fromColor(self.clear_color),
    );

    const encoder = try MetalBridge.createRenderEncoder(self.current_command_buffer.?, render_pass);

    try self.flushGeometryBatch(encoder);
    try self.flushTextureBatch(encoder);

    MetalBridge.endEncoding(encoder);

    if (self.current_command_buffer) |cmd_buf| {
        if (self.current_drawable) |drawable| {
            MetalBridge.presentDrawable(cmd_buf, drawable);
        }
        MetalBridge.commitCommandBuffer(cmd_buf);
    }
    self.current_drawable = null;
    self.current_command_buffer = null;
}

fn flushGeometryBatch(self: *Self, encoder: *MTLRenderCommandEncoder) !void {
    const vertices = self.batch.vertices.items;
    if (vertices.len == 0) return;

    const buffer_ptr = try MetalBridge.getBufferContents(self.vertex_buffer);
    const vertex_size = @sizeOf(Vertex);
    const bytes_to_copy = vertices.len * vertex_size;

    if (bytes_to_copy > self.vertex_buffer_size) {
        log.err(
            .renderer,
            "Vertex buffer overflow: trying to copy {d} bytes but buffer size is {d} bytes ({d} vertices vs {d} max)",
            .{
                bytes_to_copy,
                self.vertex_buffer_size,
                vertices.len,
                self.vertex_buffer_size / vertex_size,
            },
        );
        const clamped_bytes = self.vertex_buffer_size;
        const clamped_vertices = clamped_bytes / vertex_size;
        @memcpy(
            @as([*]u8, @ptrCast(buffer_ptr))[0..clamped_bytes],
            @as([*]const u8, @ptrCast(vertices.ptr))[0..clamped_bytes],
        );
        log.warn(.renderer, "Rendering truncated to {d} vertices", .{clamped_vertices});
    } else {
        @memcpy(
            @as([*]u8, @ptrCast(buffer_ptr))[0..bytes_to_copy],
            @as([*]const u8, @ptrCast(vertices.ptr))[0..bytes_to_copy],
        );
    }

    MetalBridge.setPipelineState(encoder, self.pipeline_state);
    MetalBridge.setVertexBuffer(encoder, self.vertex_buffer, 0, 0);

    for (self.batch.draw_calls.items) |call| {
        MetalBridge.drawPrimitives(
            encoder,
            call.primitive_type,
            call.vertex_start,
            call.vertex_count,
        );
    }
}

fn flushTextureBatch(self: *Self, encoder: *MTLRenderCommandEncoder) !void {
    const vertices = self.texture_batch.vertices.items;
    if (vertices.len == 0) return;

    const buffer_ptr = try MetalBridge.getBufferContents(self.texture_vertex_buffer);
    const vertex_size = @sizeOf(TextureVertex);
    const bytes_to_copy = vertices.len * vertex_size;

    @memcpy(
        @as([*]u8, @ptrCast(buffer_ptr))[0..bytes_to_copy],
        @as([*]const u8, @ptrCast(vertices.ptr))[0..bytes_to_copy],
    );

    MetalBridge.setPipelineState(encoder, self.texture_pipeline_state);
    MetalBridge.setVertexBuffer(encoder, self.texture_vertex_buffer, 0, 0);

    for (self.texture_batch.draw_calls.items) |call| {
        MetalBridge.setFragmentTexture(encoder, call.texture, 0);
        MetalBridge.drawPrimitives(
            encoder,
            .triangle,
            call.vertex_start,
            call.vertex_count,
        );
    }
}
