const std = @import("std");
const metal = @import("metal_types.zig");
const CAMetalDrawable = metal.CAMetalDrawable;
const CAMetalLayer = metal.CAMetalLayer;
const ClearColor = metal.ClearColor;
const MTLBuffer = metal.MTLBuffer;
const MTLCommandBuffer = metal.MTLCommandBuffer;
const MTLCommandQueue = metal.MTLCommandQueue;
const MTLDevice = metal.MTLDevice;
const MTLFunction = metal.MTLFunction;
const MTLLibrary = metal.MTLLibrary;
const MTLLoadAction = metal.MTLLoadAction;
const MTLPixelFormat = metal.MTLPixelFormat;
const MTLPrimitiveType = metal.MTLPrimitiveType;
const MTLRenderCommandEncoder = metal.MTLRenderCommandEncoder;
const MTLRenderPassDescriptor = metal.MTLRenderPassDescriptor;
const MTLRenderPipelineState = metal.MTLRenderPipelineState;
const MTLStoreAction = metal.MTLStoreAction;
const MTLTexture = metal.MTLTexture;
const MTLError = metal.MetalError;

extern fn metal_create_device() ?*MTLDevice;
extern fn metal_create_command_queue(device: *MTLDevice) ?*MTLCommandQueue;
extern fn metal_create_command_buffer(queue: *MTLCommandQueue) ?*MTLCommandBuffer;
extern fn metal_get_layer_from_view(view: *anyopaque) ?*CAMetalLayer;
extern fn metal_layer_next_drawable(layer: *CAMetalLayer) ?*CAMetalDrawable;
extern fn metal_drawable_get_texture(drawable: *CAMetalDrawable) ?*MTLTexture;
extern fn metal_begin_render_pass(
    commandBuffer: *MTLCommandBuffer,
    descriptor: *MTLRenderPassDescriptor,
) void;
extern fn metal_set_pipeline_state(
    encoder: *MTLRenderCommandEncoder,
    state: *MTLRenderPipelineState,
) void;
extern fn metal_device_create_library_from_file(
    device: *MTLDevice,
    path: [*:0]const u8,
) ?*MTLLibrary;
extern fn metal_create_render_pass_descriptor() ?*MTLRenderPassDescriptor;
extern fn metal_render_pass_set_color_attachment(
    desc: *MTLRenderPassDescriptor,
    texture: *MTLTexture,
    load_action: u64,
    store_action: u64,
    r: f64,
    g: f64,
    b: f64,
    a: f64,
) void;
extern fn metal_command_buffer_create_render_encoder(
    buffer: *MTLCommandBuffer,
    descriptor: *MTLRenderPassDescriptor,
) ?*MTLRenderCommandEncoder;
extern fn metal_render_encoder_set_vertex_buffer(
    encoder: *MTLRenderCommandEncoder,
    buffer: *MTLBuffer,
    offset: u64,
    index: u64,
) void;
extern fn metal_render_encoder_draw_primitives(
    encoder: *MTLRenderCommandEncoder,
    primitive_type: u64,
    vertex_start: u64,
    vertex_count: u64,
) void;
extern fn metal_render_encoder_end(encoder: *MTLRenderCommandEncoder) void;
extern fn metal_device_create_buffer(
    device: *MTLDevice,
    length: u64,
    options: u64,
) ?*MTLBuffer;
extern fn metal_buffer_contents(buffer: *MTLBuffer) ?*anyopaque;
extern fn metal_device_create_default_library(device: *MTLDevice) ?*MTLLibrary;
extern fn metal_library_create_function(
    library: *MTLLibrary,
    name: [*:0]const u8,
) ?*MTLFunction;
extern fn metal_create_render_pipeline_state(
    device: *MTLDevice,
    vertex_function: *MTLFunction,
    fragment_function: *MTLFunction,
    pixel_format: u64,
) ?*MTLRenderPipelineState;
extern fn metal_command_buffer_commit(buffer: *MTLCommandBuffer) void;
extern fn metal_command_buffer_present_drawable(
    buffer: *MTLCommandBuffer,
    drawable: *CAMetalDrawable,
) void;
extern fn metal_buffer_length(buffer: *MTLBuffer) u64;

// MARK: Zig wrappers for extern functions
pub const MetalBridge = struct {
    pub fn createDevice() !*MTLDevice {
        return metal_create_device() orelse MTLError.DeviceCreationFailed;
    }
    pub fn createCommandQueue(device: *MTLDevice) !*MTLCommandQueue {
        return metal_create_command_queue(device) orelse
            MTLError.CommandQueueCreationFailed;
    }
    pub fn getLayerFromView(view: *anyopaque) !*CAMetalLayer {
        return metal_get_layer_from_view(view) orelse MTLError.LayerUnavailable;
    }
    pub fn nextDrawable(layer: *CAMetalLayer) !*CAMetalDrawable {
        return metal_layer_next_drawable(layer) orelse
            MTLError.DrawableUnavailable;
    }
    pub fn getDrawableTexture(drawable: *CAMetalDrawable) !*MTLTexture {
        return metal_drawable_get_texture(drawable) orelse MTLError.TextureUnavailable;
    }
    pub fn createCommandBuffer(queue: *MTLCommandQueue) !*MTLCommandBuffer {
        return metal_create_command_buffer(queue) orelse
            MTLError.CommandBufferCreationFailed;
    }
    pub fn createRenderPassDescriptor() !*MTLRenderPassDescriptor {
        return metal_create_render_pass_descriptor() orelse
            MTLError.RenderPassCreationFailed;
    }
    pub fn createRenderEncoder(
        buffer: *MTLCommandBuffer,
        descriptor: *MTLRenderPassDescriptor,
    ) !*MTLRenderCommandEncoder {
        return metal_command_buffer_create_render_encoder(buffer, descriptor) orelse
            MTLError.EncoderCreationFailed;
    }
    pub fn createBuffer(device: *MTLDevice, length: u64, options: u64) !*MTLBuffer {
        return metal_device_create_buffer(device, length, options) orelse
            MTLError.BufferCreationFailed;
    }
    pub fn getBufferContents(buffer: *MTLBuffer) !*anyopaque {
        return metal_buffer_contents(buffer) orelse MTLError.BufferContentsUnavailable;
    }
    pub fn createDefaultLibrary(device: *MTLDevice) !*MTLLibrary {
        return metal_device_create_default_library(device) orelse
            MTLError.LibraryCreationFailed;
    }
    pub fn createLibraryFromFile(device: *MTLDevice, path: [*:0]const u8) !*MTLLibrary {
        return metal_device_create_library_from_file(device, path) orelse MTLError.LibraryCreationFailed;
    }
    pub fn createFunction(library: *MTLLibrary, name: [*:0]const u8) !*MTLFunction {
        return metal_library_create_function(library, name) orelse
            MTLError.FunctionNotFound;
    }
    pub fn createRenderPipelineState(
        device: *MTLDevice,
        vertex_function: *MTLFunction,
        fragment_function: *MTLFunction,
        pixel_format: MTLPixelFormat,
    ) !*MTLRenderPipelineState {
        std.log.debug("Here in createRenderPipelineState\n", .{});
        return metal_create_render_pipeline_state(
            device,
            vertex_function,
            fragment_function,
            @intFromEnum(pixel_format),
        ) orelse MTLError.PipelineCreationFailed;
    }
    pub fn setColorAttachment(
        desc: *MTLRenderPassDescriptor,
        texture: *MTLTexture,
        load_action: MTLLoadAction,
        store_action: MTLStoreAction,
        clear: ClearColor,
    ) void {
        metal_render_pass_set_color_attachment(
            desc,
            texture,
            @intFromEnum(load_action),
            @intFromEnum(store_action),
            clear.r,
            clear.g,
            clear.b,
            clear.a,
        );
    }
    pub fn setVertexBuffer(
        encoder: *MTLRenderCommandEncoder,
        buffer: *MTLBuffer,
        offset: u64,
        index: u64,
    ) void {
        metal_render_encoder_set_vertex_buffer(encoder, buffer, offset, index);
    }
    pub fn drawPrimitives(
        encoder: *MTLRenderCommandEncoder,
        primitive_type: MTLPrimitiveType,
        vertex_start: u64,
        vertex_count: u64,
    ) void {
        metal_render_encoder_draw_primitives(
            encoder,
            @intFromEnum(primitive_type),
            vertex_start,
            vertex_count,
        );
    }
    pub fn endEncoding(encoder: *MTLRenderCommandEncoder) void {
        metal_render_encoder_end(encoder);
    }
    pub fn commitCommandBuffer(buffer: *MTLCommandBuffer) void {
        metal_command_buffer_commit(buffer);
    }
    pub fn presentDrawable(
        buffer: *MTLCommandBuffer,
        drawable: *CAMetalDrawable,
    ) void {
        metal_command_buffer_present_drawable(buffer, drawable);
    }
    pub fn setPipelineState(
        encoder: *MTLRenderCommandEncoder,
        state: *MTLRenderPipelineState,
    ) void {
        metal_set_pipeline_state(encoder, state);
    }

    pub fn getBufferLength(buffer: *MTLBuffer) u64 {
        return metal_buffer_length(buffer);
    }
};
