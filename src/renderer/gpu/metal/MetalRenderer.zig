const std = @import("std");
const metal = @import("metal_types.zig");
const bridge = @import("metal_bridge.zig");
const BridgeError = bridge.BridgeError;
const MetalBridge = bridge.MetalBridge;
const GeometryBatch = @import("geometry_batch.zig").GeometryBatch;

const MTLDevice = metal.MTLDevice;
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
const MTLResourceOptions = metal.MTLResourceOptions;
const MTLError = metal.MetalError;
const MTLLoadAction = metal.MTLLoadAction;
const MTLStoreAction = metal.MTLStoreAction;

const Color = @import("../../color.zig").Color;
const shapes = @import("../../shapes.zig");
const ShapeData = shapes.ShapeData;
const RenderContext = @import("../../RenderContext.zig");
const utils = @import("../../geometry_utils.zig");
const Transform = utils.Transform;
const rend = @import("../../renderer.zig");
const RenderConfig = rend.RendererConfig;

const Self = @This();

device: *MTLDevice,
command_queue: *MTLCommandQueue,
layer: *CAMetalLayer,
pipeline_state: *MTLRenderPipelineState,
vertex_buffer: *MTLBuffer,
vertex_buffer_size: usize,
batch: GeometryBatch,
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

pub fn init(allocator: std.mem.Allocator, config: RenderConfig) (MTLError || std.mem.Allocator.Error)!Self {
    const layer = try MetalBridge.getLayerFromView(config.native_handle.?);
    const device = try MetalBridge.createDevice();
    const queue = try MetalBridge.createCommandQueue(device);
    const pipeline_state = try createPipelineState(allocator, device);

    const vertex_size = @sizeOf(Vertex);
    const max_vertices = 10000;
    const buffer_size = max_vertices * vertex_size;
    const options = @intFromEnum(MTLResourceOptions.storageModeShared);
    const vertex_buffer = try MetalBridge.createBuffer(device, buffer_size, options);

    const batch = GeometryBatch.init(allocator);

    return Self{
        .device = device,
        .command_queue = queue,
        .layer = layer,
        .pipeline_state = pipeline_state,
        .vertex_buffer = vertex_buffer,
        .vertex_buffer_size = buffer_size,
        .batch = batch,
        .current_drawable = null,
        .current_command_buffer = null,
        .width = config.width,
        .height = config.height,
        .scale_factor = 1.0, // TODO: get from platform
        .clear_color = Color.init(0, 0, 255, 255), // black for now
        .frame_number = 0,
        .start_time = 0.0, // TODO: get time from platform
        .last_frame_time = 0.0,
        .allocator = allocator,
    };
}
fn getShaderPath(allocator: std.mem.Allocator) ![]const u8 {
    const exe_dir = std.fs.selfExeDirPathAlloc(allocator) catch |err| {
        std.log.err("Failed to get exe dir: {}", .{err});
        return MTLError.ShaderPathError;
    };
    defer allocator.free(exe_dir);

    return std.fs.path.join(allocator, &.{ exe_dir, "default.metallib" }) catch |err| {
        std.log.err("Failed to join path: {}", .{err});
        return MTLError.ShaderPathError;
    };
}
fn createPipelineState(allocator: std.mem.Allocator, device: *MTLDevice) !*MTLRenderPipelineState {
    const shader_path = try getShaderPath(allocator);
    defer allocator.free(shader_path);
    const shader_path_z = try allocator.dupeZ(u8, shader_path);
    defer allocator.free(shader_path_z);

    const library = try MetalBridge.createLibraryFromFile(device, shader_path_z);

    const vertex_fn = try MetalBridge.createFunction(library, "vertex_main");
    const fragment_fn = try MetalBridge.createFunction(library, "fragment_main");

    // const pixel_format = @intFromEnum(MTLPixelFormat.bgra8Unorm);

    return try MetalBridge.createRenderPipelineState(
        device,
        vertex_fn,
        fragment_fn,
        MTLPixelFormat.bgra8Unorm,
    );
}

pub fn deinit(self: *Self) void {
    self.batch.deinit();
    // TODO: Release all the MTL resources
}

pub fn beginFrame(self: *Self) !void {
    self.batch.clear();

    self.current_drawable = try MetalBridge.nextDrawable(self.layer);
    self.current_command_buffer = try MetalBridge.createCommandBuffer(self.command_queue);

    self.frame_number += 1;
}

pub fn endFrame(self: *Self) !void {
    try self.flushBatch();

    if (self.current_command_buffer) |cmd_buf| {
        if (self.current_drawable) |drawable| {
            MetalBridge.presentDrawable(cmd_buf, drawable);
        }
        MetalBridge.commitCommandBuffer(cmd_buf);
    }
    self.current_drawable = null;
    self.current_command_buffer = null;
}

pub fn resize(self: *Self, width: u32, height: u32) !void {
    self.width = width;
    self.height = height;

    // TODO: Recreate metal resources if needed on resize
}

pub fn clear(self: Self) void {
    // Nothing needs to happen, render pass does it
    _ = self;
}

pub fn setClearColor(self: *Self, color: Color) void {
    self.clear_color = color;
}
pub fn drawShape(
    self: *Self,
    shape: ShapeData,
    transform: ?Transform,
) void {
    const ctx = self.getRenderContext();
    self.batch.addShape(shape, transform, &ctx) catch |err| {
        std.log.err("Failed to add shape to batch: {any}\n", .{err});
    };
}
fn flushBatch(self: *Self) !void {
    const vertices = self.batch.getVertexSlice();
    if (vertices.len == 0) return;

    // DEBUG: Log what we're drawing
    std.log.debug("Flushing batch: {} vertices", .{vertices.len});
    std.log.debug("First vertex: pos=({d:.2}, {d:.2}) color=({d:.2}, {d:.2}, {d:.2}, {d:.2})", .{
        vertices[0].position[0],
        vertices[0].position[1],
        vertices[0].color[0],
        vertices[0].color[1],
        vertices[0].color[2],
        vertices[0].color[3],
    });

    const buffer_ptr = try MetalBridge.getBufferContents(self.vertex_buffer);
    const vertex_size = @sizeOf(Vertex);
    const bytes_to_copy = vertices.len * vertex_size;
    @memcpy(
        @as([*]u8, @ptrCast(buffer_ptr))[0..bytes_to_copy],
        @as([*]const u8, @ptrCast(vertices.ptr))[0..bytes_to_copy],
    );

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
    MetalBridge.setPipelineState(encoder, self.pipeline_state);
    MetalBridge.setVertexBuffer(encoder, self.vertex_buffer, 0, 0);

    const draw_calls = self.batch.draw_calls.items;
    for (draw_calls) |call| {
        MetalBridge.drawPrimitives(
            encoder,
            call.primitive_type,
            call.vertex_start,
            call.vertex_count,
        );
    }

    MetalBridge.endEncoding(encoder);
}

fn getRenderContext(self: *const Self) RenderContext {
    return RenderContext{
        .width = self.width,
        .height = self.height,
        .scale_factor = self.scale_factor,
        .frame_number = self.frame_number,
        .time = 0.0, // TODO
        .delta_time = 0.0, // TODO
    };
}
