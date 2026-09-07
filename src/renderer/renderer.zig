const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("math");
pub const V2 = math.V2;
pub const WorldPoint = math.WorldPoint;
pub const ScreenPoint = math.ScreenPoint;
const build_options = @import("build_options");

// MARK: Vocabulary re-exports
// These types LIVE in `visual` now — description, not execution. Re-exported
// here so every existing `rend.Color` / `rend.Shapes` / `rend.Renderable` call
// site keeps compiling. Consumers migrate to @import("visual") opportunistically.
const visual = @import("visual");
pub const Color = visual.Color;
pub const Colors = visual.Colors;
pub const ColorLibrary = visual.ColorLibrary;
pub const Hue = visual.Hue;
pub const Temperature = visual.Temperature;
pub const Saturation = visual.Saturation;
pub const Tone = visual.Tone;
pub const Family = visual.Family;
pub const TaggedColor = visual.TaggedColor;
pub const Generator = visual.Generator;
pub const Shapes = visual.Shapes;
pub const triangulation = visual.triangulation;
pub const ShapeData = visual.ShapeData;
pub const ShapeRegistry = visual.ShapeRegistry;
pub const CoordinateSpace = visual.CoordinateSpace;
pub const PixelFormat = visual.PixelFormat;
pub const DrawStyle = visual.DrawStyle;
pub const Gradient = visual.Gradient;
pub const Renderable = visual.Renderable;
pub const ScreenAnchor = visual.ScreenAnchor;
pub const Transform = visual.Transform;
pub const getAnchorPos = visual.getAnchorPos;

const batch = @import("batch.zig");
pub const Batch = batch.IndexedBatch;
pub const DrawCall = batch.DrawCall;
const tess = @import("tess.zig");
pub const ClipMap = tess.ClipMap;
pub const LocalXform = tess.LocalXform;
pub const tessellate = tess.tessellate;
const text_module = @import("text.zig");
const Font = text_module.Font;
const ctxm = @import("context.zig");
pub const RenderConfig = ctxm.RendererConfig;
pub const RenderContext = ctxm.RenderContext;
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

    /// ctx: any struct with `width: u32`, `height: u32`, `camera_loc: V2`,
    /// `ortho_size: f32`. That shape IS the contract — no shared type required.
    /// `RenderContext` in context.zig is one struct that satisfies it; an app is
    /// free to pass its own with extra fields. Applies to every draw* below.
    pub fn render(self: *Renderer, r: Renderable, ctx: anytype) void {
        self.backend.render(r, ctx);
    }

    pub fn init(persistent: Allocator, io: std.Io, config: RenderConfig) !Renderer {
        const backend = try BackendImpl.init(persistent, io, config);
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
        ctx: anytype,
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
        ctx: anytype,
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
        ctx: anytype,
    ) void {
        text_module.drawTextScreen(self, font, tex, text, position, scale, color, ctx);
    }
};
