const std = @import("std");
const core = @import("core");
pub const GamePoint = core.GamePoint;
pub const ScreenPoint = core.ScreenPoint;
const build_options = @import("build_options");
const col = @import("color.zig");
pub const Color = col.Color;
pub const Colors = col.Colors;
const shape = @import("shapes.zig");
pub const Circle = shape.Circle;
pub const Ellipse = shape.Ellipse;
pub const Line = shape.Line;
pub const Polygon = shape.Polygon;
pub const Rectangle = shape.Rectangle;
pub const ShapeData = shape.ShapeData;
pub const Triangle = shape.Triangle;
pub const FrameBuffer = @import("cpu/frameBuffer.zig").FrameBuffer;
const utils = @import("geometry_utils.zig");
pub const Transform = utils.Transform;
pub const scalePt = utils.scalePt;
pub const rotatePt = utils.rotatePt;
pub const movePt = utils.movePt;
pub const gameToScreen = utils.gameToScreen;
pub const screenToGame = utils.screenToGame;
pub const screenToClip = utils.screenToClip;
pub const toClip = utils.toClip;
pub const RenderContext = @import("RenderContext.zig");

const CpuRenderer = if (build_options.backend == .cpu)
    @import("./cpu/CpuRenderer.zig");
const MetalRenderer = if (build_options.backend == .metal)
    @import("./gpu/metal/metal_renderer.zig").MetalRenderer
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

// pub const ShapeData = union(enum) {
//     Circle: Circle,
//     Ellipse: Ellipse,
//     Line: Line,
//     Rectangle: Rectangle,
//     Triangle: Triangle,
//     Polygon: Polygon,
// };

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
        .cpu => CpuRenderer,
        .metal => MetalRenderer,
        .vulkan => VulkanRenderer,
        .opengl => OpenGLRenderer,
    };

    pub fn init(allocator: std.mem.Allocator, config: RendererConfig) !Renderer {
        const backend = try BackendImpl.init(allocator, config.width, config.height);
        return .{
            .backend = backend,
            .width = config.width,
            .height = config.height,
        };
    }
    pub fn deinit(self: *Renderer) void {
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

    pub fn drawShape(self: *Renderer, shape_data: ShapeData, transform: ?Transform) void {
        self.backend.drawShape(shape_data, transform);
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
