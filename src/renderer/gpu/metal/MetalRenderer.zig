const std = @import("std");
const types = @import("metal_types.zig");
const bridge = @import("metal_bridge.zig");
const MetalBridge = bridge.MetalBridge;
const GeometryBatch = @import("geometry_batch.zig").GeometryBatch;

const MTLDevice = types.MTLDevice;
const MTLCommandQueue = types.MTLCommandQueue;
const MTLCommandBuffer = types.MTLCommandBuffer;
const CAMetalLayer = types.CAMetalLayer;
const CAMetalDrawable = types.CAMetalDrawable;
const MTLRenderPipelineState = types.MTLRenderPipelineState;
const MTLBuffer = types.MTLBuffer;
const MTLLibrary = types.MTLLibrary;
const MTLPixelFormat = types.MTLPixelFormat;
const ClearColor = types.ClearColor;

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

pub fn init(allocator: std.mem.Allocator, config: RenderConfig) !Self {
    const layer = try MetalBridge.getLayerFromView(config.native_handle.?);

    // const device = try MetalBridge.createDevice();

    // const queue = try MetalBridge.createCommandQueue(device);

    // const pipeline = try createPipelineState(device); // TODO: setup shaders

    const initial_buffer_size = 1024 * 1024; // 1MB initial size
    // const vertex_buffer = try MetalBridge.createBuffer(device, initial_buffer_size, 0);

    const batch = GeometryBatch.init(allocator);

    return Self{
        .device = undefined, // TODO: from bridge
        .command_queue = undefined, // TODO: from bridge
        .layer = layer,
        .pipeline_state = undefined, // TODO: need to set up shaders
        .vertex_buffer = undefined, // TODO: from bridge
        .vertex_buffer_size = initial_buffer_size,
        .batch = batch,
        .current_drawable = null,
        .current_command_buffer = null,
        .width = config.width,
        .height = config.height,
        .scale_factor = 1.0, // TODO: get from platform
        .clear_color = Color.init(0, 0, 0, 255),
        .frame_number = 0,
        .start_time = 0.0, // TODO: get time from platform
        .last_frame_time = 0.0,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.batch.deinit();
    // TODO: Release all the MTL resources
}

pub fn beginFrame(self: *Self) !void {
    self.batch.clear();
    // TODO: get the drawable
    // self.current_drawable = try MetalBridge.nextDrawable(self.layer);

    // TODO: create the command buffer
    // self.current_command_buffer = try MetalBridge.createCommandBuffer(self.comamndBuffer);

    self.frame_number += 1;
}

pub fn endFrame(self: *Self) !void {
    try self.flushBatch();

    // TODO: Present the drawable
    if (self.current_drawable) |drawable| {
        if (self.current_command_buffer) |cmd_buf| {
            MetalBridge.presentDrawable(cmd_buf, drawable);
            MetalBridge.commitCommandBuffer(cmd_buf);
        }
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
        std.log.err("Failed to add shape to batch: {e}\n", .{err});
    };
}
fn flushBatch(self: *Self) !void {
    const vertices = self.batch.getVertexSlice();
    if (vertices.len == 0) return; // Nothing to draw

    // TODO: Upload vertices to GPU buffer (Phase 2)
    // const vertex_data = std.mem.sliceAsBytes(vertices);
    // const buffer_contents = try MetalBridge.getBufferContents(self.vertex_buffer);
    // @memcpy(buffer_contents, vertex_data);

    // TODO: Create render pass (Phase 2)
    // const render_pass = try MetalBridge.createRenderPassDescriptor();
    // Set clear color, texture, etc.

    // TODO: Create render encoder (Phase 2)
    // const encoder = try MetalBridge.createRenderEncoder(cmd_buf, render_pass);

    // TODO: Set pipeline state (Phase 2)
    // MetalBridge.setPipelineState(encoder, self.pipeline_state);

    // TODO: Set vertex buffer (Phase 2)
    // MetalBridge.setVertexBuffer(encoder, self.vertex_buffer, 0, 0);

    // TODO: Issue draw calls (Phase 2)
    // for (self.batch.draw_calls.items) |draw_call| {
    //     MetalBridge.drawPrimitives(
    //         encoder,
    //         draw_call.primitive_type,
    //         draw_call.vertex_start,
    //         draw_call.vertex_count,
    //     );
    // }

    // TODO: End encoding (Phase 2)
    // MetalBridge.endEncoding(encoder);
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
