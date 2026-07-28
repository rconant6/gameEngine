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
const MetalFrameContext = metal.MetalFrameContext;
const MetalFrame = metal.MetalFrame;

extern fn metal_frame_context_create(
    device: *MTLDevice,
    queue: *MTLCommandQueue,
    layer: *CAMetalLayer,
    max_frames_in_flight: u32, // 3
) ?*MetalFrameContext;
extern fn metal_frame_context_destroy(ctx: *MetalFrameContext) void;
extern fn metal_frame_begin(
    ctx: *MetalFrameContext,
    clear_r: f64,
    clear_g: f64,
    clear_b: f64,
    clear_a: f64,
) ?*MetalFrame;
extern fn metal_frame_encoder(frame: *MetalFrame) *MTLRenderCommandEncoder;
extern fn metal_frame_end(ctx: *MetalFrameContext, frame: *MetalFrame) void;
extern fn metal_release(ptr: *anyopaque) void;
extern fn metal_frame_context_wait_idle(ctx: *MetalFrameContext) void;

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
extern fn metal_render_encoder_draw_indexed_primitives(
    encoder: *MTLRenderCommandEncoder,
    primitive_type: u64,
    index_count: u64,
    index_type: u64,
    index_buffer: *MTLBuffer,
    index_offset: u64,
    base_vertex: i64,
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
    sample_count: u8,
) ?*MTLRenderPipelineState;
extern fn metal_command_buffer_commit(buffer: *MTLCommandBuffer) void;
extern fn metal_command_buffer_present_drawable(
    buffer: *MTLCommandBuffer,
    drawable: *CAMetalDrawable,
) void;
extern fn metal_buffer_length(buffer: *MTLBuffer) u64;

extern fn metal_create_texture(
    device: *MTLDevice,
    width: u32,
    height: u32,
    pixel_format: u64,
) ?*MTLTexture;

extern fn metal_texture_replace_region(
    texture: *MTLTexture,
    width: u32,
    height: u32,
    data: [*]const u8,
    bytes_per_row: u32,
) void;

extern fn metal_render_encoder_set_fragment_texture(
    encoder: *MTLRenderCommandEncoder,
    texture: *MTLTexture,
    index: u64,
) void;

extern fn metal_create_texture_pipeline_state(
    device: *MTLDevice,
    vertex_function: *MTLFunction,
    fragment_function: *MTLFunction,
    pixel_format: u64,
    sample_count: u8,
) ?*MTLRenderPipelineState;

extern fn metal_frame_context_set_msaa(
    ctx: *MetalFrameContext,
    sample_count: u8,
    width: u32,
    height: u32,
) void;

extern fn metal_render_encoder_set_vertex_bytes(
    encoder: *MTLRenderCommandEncoder,
    bytes: *const anyopaque,
    length: u64,
    index: u64,
) void;
extern fn metal_render_encoder_set_fragment_bytes(
    encoder: *MTLRenderCommandEncoder,
    bytes: *const anyopaque,
    length: u64,
    index: u64,
) void;

// MARK: Zig wrappers for extern functions
pub const MetalBridge = struct {
    pub fn frameContextCreate(
        device: *MTLDevice,
        queue: *MTLCommandQueue,
        layer: *CAMetalLayer,
        max_frames_in_flight: u32, // 3
    ) MTLError!*MetalFrameContext {
        return metal_frame_context_create(
            device,
            queue,
            layer,
            max_frames_in_flight,
        ) orelse
            MTLError.FrameContextCreationFailed;
    }
    pub fn frameContextDestroy(ctx: *MetalFrameContext) void {
        metal_frame_context_destroy(ctx);
    }
    pub fn frameBegin(ctx: *MetalFrameContext, clear: ClearColor) ?*MetalFrame {
        return metal_frame_begin(ctx, clear.r, clear.g, clear.b, clear.a);
    }
    pub fn frameEncoder(frame: *MetalFrame) *MTLRenderCommandEncoder {
        return metal_frame_encoder(frame);
    }
    pub fn frameEnd(ctx: *MetalFrameContext, frame: *MetalFrame) void {
        metal_frame_end(ctx, frame);
    }
    pub fn release(ptr: *anyopaque) void {
        metal_release(ptr);
    }
    pub fn frameContextWaitIdle(ctx: *MetalFrameContext) void {
        metal_frame_context_wait_idle(ctx);
    }

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
            MTLError.RenderEncoderCreationFailed;
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
        return metal_device_create_library_from_file(
            device,
            path,
        ) orelse MTLError.LibraryCreationFailed;
    }
    pub fn createFunction(library: *MTLLibrary, name: [*:0]const u8) !*MTLFunction {
        return metal_library_create_function(
            library,
            name,
        ) orelse
            MTLError.FunctionNotFound;
    }
    pub fn createRenderPipelineState(
        device: *MTLDevice,
        vertex_function: *MTLFunction,
        fragment_function: *MTLFunction,
        pixel_format: MTLPixelFormat,
        sample_count: u8,
    ) !*MTLRenderPipelineState {
        return metal_create_render_pipeline_state(
            device,
            vertex_function,
            fragment_function,
            @intFromEnum(pixel_format),
            sample_count,
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
    pub fn drawIndexedPrimitives(
        encoder: *MTLRenderCommandEncoder,
        primitive_type: MTLPrimitiveType,
        index_count: u64,
        index_buffer: *MTLBuffer,
        index_offset: u64,
        base_vertex: i64,
    ) void {
        metal_render_encoder_draw_indexed_primitives(
            encoder,
            @intFromEnum(primitive_type),
            index_count,
            1, // is u32, 0 is for u16
            index_buffer,
            index_offset,
            base_vertex,
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

    pub fn createTexture(
        device: *MTLDevice,
        width: u32,
        height: u32,
        format: MTLPixelFormat,
    ) !*MTLTexture {
        return metal_create_texture(
            device,
            width,
            height,
            @intFromEnum(format),
        ) orelse MTLError.TextureCreationFailed;
    }

    pub fn uploadTextureData(
        texture: *MTLTexture,
        width: u32,
        height: u32,
        data: [*]const u8,
        bytes_per_row: u32,
    ) void {
        metal_texture_replace_region(texture, width, height, data, bytes_per_row);
    }

    pub fn setFragmentTexture(
        encoder: *MTLRenderCommandEncoder,
        texture: *MTLTexture,
        index: u64,
    ) void {
        metal_render_encoder_set_fragment_texture(encoder, texture, index);
    }

    pub fn createTexturePipelineState(
        device: *MTLDevice,
        vertex_function: *MTLFunction,
        fragment_function: *MTLFunction,
        pixel_format: MTLPixelFormat,
        sample_count: u8,
    ) !*MTLRenderPipelineState {
        return metal_create_texture_pipeline_state(
            device,
            vertex_function,
            fragment_function,
            @intFromEnum(pixel_format),
            sample_count,
        ) orelse MTLError.PipelineCreationFailed;
    }
    // Create the MSAA color texture on the context (skips if sample_count <= 1).
    pub fn frameContextSetMsaa(
        ctx: *MetalFrameContext,
        sample_count: u8,
        width: u32,
        height: u32,
    ) void {
        metal_frame_context_set_msaa(ctx, sample_count, width, height);
    }
    pub fn setVertexBytes(
        encoder: *MTLRenderCommandEncoder,
        bytes: *const anyopaque,
        length: u64,
        index: u64,
    ) void {
        metal_render_encoder_set_vertex_bytes(encoder, bytes, length, index);
    }

    pub fn setFragmentBytes(
        encoder: *MTLRenderCommandEncoder,
        bytes: *const anyopaque,
        length: u64,
        index: u64,
    ) void {
        metal_render_encoder_set_fragment_bytes(encoder, bytes, length, index);
    }
};
