const std = @import("std");
const math = @import("math");
pub const V2 = math.V2;
pub const WorldPoint = math.WorldPoint;
pub const ScreenPoint = math.ScreenPoint;
const shapes_module = @import("shapes.zig");
pub const Shapes = shapes_module;
const registry = @import("registry");
pub const ShapeRegistry = registry.ShapeRegistry;
pub const ShapeData = registry.ShapeData;
pub const CoordinateSpace = registry.CoordinateSpace;
pub const triangulation = @import("triangulation.zig");
const build_options = @import("build_options");
const col = @import("color.zig");
pub const Color = col.Color;
pub const Colors = col.Colors;
pub const ColorLibrary = col.ColorLibrary;
pub const Hue = col.Hue;
pub const Temperature = col.Temperature;
pub const Saturation = col.Saturation;
pub const Tone = col.Tone;
pub const Family = col.Family;
pub const TaggedColor = col.TaggedColor;

const utils = @import("geometry_utils.zig");
pub const Transform = utils.Transform;
pub const ScreenAnchor = utils.ScreenAnchor;
pub const scalePt = utils.scalePt;
pub const rotatePt = utils.rotatePt;
pub const movePt = utils.movePt;
pub const worldToScreenInt = utils.worldToScreenInt;
pub const worldToScreen = utils.worldToScreen;
pub const screenToGame = utils.screenToGame;
pub const screenToClip = utils.screenToClip;
pub const toClip = utils.toClip;
pub const getAnchorPos = utils.getAnchorPosition;
pub const RenderContext = @import("RenderContext.zig");
const text_module = @import("text.zig");
const Font = text_module.Font;
const debug = @import("debug");
const log = debug.log;

// CPU renderer is currently disabled - code kept for reference
// const CpuRenderer = if (build_options.backend == .cpu)
//     @import("./cpu/CpuRenderer.zig");
const MetalRenderer = if (build_options.backend == .metal)
    @import("./gpu/metal/MetalRenderer.zig")
else
    void;
const VulkanRenderer = if (build_options.backend == .vulkan)
    @import("./gpu/vulcan/vulcan_renderer.zig").VulkanRenderer
else
    void;
const OpenGLRenderer = if (build_options.backend == .opengl)
    @import("./gpu/opengl/opengl_renderer.zig").OpenGLRenderer
else
    unreachable;

pub const RendererConfig = struct {
    width: u32,
    height: u32,

    native_handle: ?*anyopaque = null,
    enable_validation: bool = false,
    vsync: bool = true,
};

pub const Renderer = struct {
    backend: BackendImpl,
    width: u32,
    height: u32,

    const BackendImpl = switch (build_options.backend) {
        // .cpu => CpuRenderer, // CPU renderer disabled
        .cpu => unreachable, // Should be caught by build.zig
        .metal => MetalRenderer,
        .vulkan => VulkanRenderer,
        .opengl => OpenGLRenderer,
    };

    pub fn init(allocator: std.mem.Allocator, config: RendererConfig) !Renderer {
        const backend = try BackendImpl.init(allocator, config);
        return .{
            .backend = backend,
            .width = config.width,
            .height = config.height,
        };
    }
    pub fn deinit(self: *Renderer) void {
        log.info(.renderer, "Renderer shutting down...", .{});
        self.backend.deinit();
    }

    pub fn resize(self: *Renderer, width: u32, height: u32) !void {
        self.width = width;
        self.height = height;
        try self.backend.resize(width, height);
    }

    pub fn beginFrame(self: *Renderer) !void {
        try self.backend.beginFrame();
    }
    pub fn endFrame(self: *Renderer) !void {
        try self.backend.endFrame();
    }

    pub fn clear(self: *Renderer) void {
        self.backend.clear();
    }
    pub fn setClearColor(self: *Renderer, color: Color) void {
        self.backend.setClearColor(color);
    }

    pub fn drawGeometry(
        self: *Renderer,
        shape_data: ShapeData,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) void {
        self.backend.drawShape(
            shape_data,
            transform,
            fill_color,
            stroke_color,
            stroke_width,
            ctx,
        );
    }
    pub fn drawText(
        self: *Renderer,
        font: *const Font,
        text: []const u8,
        position: WorldPoint,
        scale: f32,
        color: Color,
        ctx: RenderContext,
    ) void {
        text_module.drawText(self, font, text, position, scale, color, ctx);
    }

    // TODO: All of these need to return errors/nil if called for the wrong backend
    pub fn getPixelBufferPtr(self: *const Renderer) ?[*]const u8 {
        if (build_options.backend == .cpu) {
            const buffer = self.backend.getRawFrameBuffer();
            return @ptrCast(buffer.ptr);
        }
        return null;
    }
    pub fn getRawFrameBuffer(self: *const Renderer) ?[]const Color {
        if (build_options.backend == .cpu) {
            return self.backend.getRawFrameBuffer();
        }
        return null;
    }
    pub fn getDisplayBufferOffset(self: *const Renderer) ?u32 {
        if (build_options.backend == .cpu) {
            return self.backend.getDisplayBufferOffset();
        }
        return null;
    }
};
