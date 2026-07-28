const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("math");
pub const V2 = math.V2;
pub const WorldPoint = math.WorldPoint;
pub const ScreenPoint = math.ScreenPoint;
const shapes_module = @import("shapes");
pub const Shapes = shapes_module;
const registry = @import("registry");
pub const ShapeRegistry = registry.ShapeRegistry;
pub const ShapeData = registry.ShapeData;
pub const triangulation = @import("triangulation");
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
pub const Generator = col.generators;
const batch = @import("batch.zig");
pub const Batch = batch.IndexedBatch;
pub const DrawCall = batch.DrawCall;
const tess = @import("tess.zig");
pub const ClipMap = tess.ClipMap;
pub const LocalXform = tess.LocalXform;
pub const tessellate = tess.tessellate;
const text_module = @import("text.zig");
const Font = text_module.Font;
const rt = @import("render_types.zig");
pub const CoordinateSpace = rt.CoordinateSpace;
pub const PixelFormat = rt.PixelFormat;
pub const DrawStyle = rt.DrawStyle;
pub const Gradient = rt.Gradient;
pub const Renderable = rt.Renderable;
pub const RenderConfig = rt.RendererConfig;
pub const RenderContext = rt.RenderContext;
pub const ScreenAnchor = rt.ScreenAnchor;
pub const Transform = rt.Transform;
pub const getAnchorPos = rt.getAnchorPosition;
const log = @import("debug").log;

const MetalRenderer = if (build_options.backend == .metal)
    @import("./gpu/metal/MetalRenderer.zig")
else
    void;
const VulkanRenderer = if (build_options.backend == .vulkan)
    @import("./gpu/vulkan/vulkan_renderer.zig")
else
    void;
const OpenGLRenderer = if (build_options.backend == .opengl)
    @import("./gpu/opengl/opengl_renderer.zig").OpenGLRenderer
else
    @panic("TODO: OpenGL is not currently a viable renderer backend");

pub const Renderer = struct {
    backend: BackendImpl,
    width: u32,
    height: u32,

    const BackendImpl = switch (build_options.backend) {
        .metal => MetalRenderer,
        .vulkan => VulkanRenderer,
        .opengl => OpenGLRenderer,
    };
    pub const Device = BackendImpl.Device;
    pub const Texture = BackendImpl.Texture;

    pub fn render(self: *Renderer, r: Renderable, ctx: RenderContext) void {
        self.backend.render(r, ctx);
    }

    pub fn init(p_gpa: Allocator, io: std.Io, config: RenderConfig) !Renderer {
        const backend = try BackendImpl.init(p_gpa, io, config);
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
        log.warn(.renderer, "TODO: actually support resizing", .{});
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

    pub fn getDevice(self: *Renderer) *Device {
        return self.backend.device;
    }

    pub fn createTexture(self: *Renderer, width: u32, height: u32, format: PixelFormat) !*Texture {
        return self.backend.createTexture(width, height, format);
    }

    pub fn uploadTextureData(
        self: *Renderer,
        texture: *Texture,
        width: u32,
        height: u32,
        data: [*]const u8,
        bytes_per_row: u32,
    ) void {
        self.backend.uploadTextureData(texture, width, height, data, bytes_per_row);
    }

    pub fn drawTextureQuad(
        self: *Renderer,
        texture: *Texture,
        width: f32,
        height: f32,
        origin: [2]f32,
        transform: ?Transform,
        ctx: RenderContext,
        flip_h: bool,
        flip_v: bool,
        tint: Color,
    ) void {
        self.backend.drawTextureQuad(
            texture,
            width,
            height,
            origin,
            transform,
            ctx,
            flip_h,
            flip_v,
            tint,
        );
    }

    pub fn drawText(
        self: *Renderer,
        font: *const Font,
        tex: *Texture,
        text: []const u8,
        position: WorldPoint,
        scale: f32,
        color: Color,
        ctx: RenderContext,
    ) void {
        text_module.drawText(self, font, tex, text, position, scale, color, ctx);
    }

    pub fn drawTextScreen(
        self: *Renderer,
        font: *const Font,
        tex: *Texture,
        text: []const u8,
        position: ScreenPoint,
        scale: f32,
        color: Color,
        ctx: RenderContext,
    ) void {
        text_module.drawTextScreen(self, font, tex, text, position, scale, color, ctx);
    }
};
