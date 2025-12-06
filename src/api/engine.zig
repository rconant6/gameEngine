const std = @import("std");
const platform = @import("platform");
const build_options = @import("build_options");

const core = @import("core");
pub const GamePoint = core.GamePoint;
pub const ScreenPoint = core.ScreenPoint;
pub const V2 = core.V2;
pub const V2I = core.V2I;

const renderer = @import("renderer");
pub const Color = renderer.Color;
pub const Colors = renderer.Colors;
pub const Circle = renderer.Circle;
pub const Rectangle = renderer.Rectangle;
pub const Triangle = renderer.Triangle;
pub const Polygon = renderer.Polygon;
pub const Line = renderer.Line;
pub const RenderContext = renderer.RenderContext;
pub const Transform = renderer.Transform;

const assets = @import("asset");
pub const AssetManager = assets.AssetManager;
pub const FontHandle = assets.FontHandle;
pub const Font = assets.Font;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    renderer: renderer.Renderer,
    assets: assets.AssetManager,
    window: platform.Window,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !Engine {
        try platform.init();

        const window = try platform.createWindow(.{
            .title = title,
            .width = width,
            .height = height,
        });

        const scale_factor = platform.getWindowScaleFactor(window);

        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);

        const scaled_width: u32 = @intFromFloat(f_width * scale_factor);
        const scaled_height: u32 = @intFromFloat(f_height * scale_factor);

        std.log.info("Scaled width: {d} Scaled height: {d}", .{ scaled_width, scaled_height });
        const rend = try renderer.Renderer.init(
            allocator,
            .{
                .width = scaled_width,
                .height = scaled_height,
                .native_handle = window.handle,
            },
        );

        if (build_options.backend == .cpu) {
            if (rend.getPixelBufferPtr()) |pixels| {
                const total_bytes: usize = scaled_width * scaled_height * 4 * 3;
                platform.setPixelBuffer(
                    window,
                    pixels[0..total_bytes],
                    scaled_width,
                    scaled_height,
                );
            }
        }

        const asset_manager = try AssetManager.init(allocator);

        return .{
            .allocator = allocator,
            .assets = asset_manager,
            .renderer = rend,
            .window = window.*,
            .running = true,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
        self.assets.deinit();
    }

    pub fn shouldClose(self: *const Engine) bool {
        return !self.running or self.window.shouldClose();
    }

    pub fn beginFrame(self: *Engine) !void {
        _ = platform.pollEvent();
        try self.renderer.beginFrame();
    }
    pub fn endFrame(self: *Engine) !void {
        try self.renderer.endFrame();
        if (build_options.backend == .cpu) {
            const offset = self.renderer.getDisplayBufferOffset() orelse 0;
            self.window.swapBuffers(offset);
        }
    }

    pub fn clear(self: *Engine, color: Color) void {
        self.renderer.setClearColor(color);
        self.renderer.clear();
    }

    pub fn drawCircle(self: *Engine, circle: Circle) void {
        self.renderer.drawShape(.{ .Circle = circle }, null);
    }
    pub fn drawCircleAt(self: *Engine, circle: Circle, x: f32, y: f32) void {
        const transform = Transform{ .offset = .{ .x = x, .y = y } };
        self.renderer.drawShape(.{ .Circle = circle }, transform);
    }
    pub fn drawRectangle(self: *Engine, rect: Rectangle) void {
        self.renderer.drawShape(.{ .Rectangle = rect }, null);
    }

    pub fn getGameBounds(ctx: RenderContext) struct { width: f32, height: f32 } {
        const aspect = @as(f32, @floatFromInt(ctx.width)) / @as(f32, @floatFromInt(ctx.height));
        return .{
            .width = 10.0 * aspect * 2.0, // Full width
            .height = 20.0, // Full height
        };
    }
    // Dimensions
    pub fn getGameWidth(self: *const Engine) f32 {
        const aspect = @as(f32, @floatFromInt(self.renderer.width)) /
            @as(f32, @floatFromInt(self.renderer.height));
        return 20.0 * aspect;
    }
    pub fn getGameHeight(self: *const Engine) f32 {
        _ = self;
        return 20.0;
    }

    // Corners
    pub fn getTopLeft(self: *const Engine) V2 {
        return .{ .x = self.getLeftEdge(), .y = self.getTopEdge() };
    }

    pub fn getTopRight(self: *const Engine) V2 {
        return .{ .x = self.getRightEdge(), .y = self.getTopEdge() };
    }

    pub fn getBottomLeft(self: *const Engine) V2 {
        return .{ .x = self.getLeftEdge(), .y = self.getBottomEdge() };
    }

    pub fn getBottomRight(self: *const Engine) V2 {
        return .{ .x = self.getRightEdge(), .y = self.getBottomEdge() };
    }

    pub fn getCenter(self: *const Engine) V2 {
        _ = self;
        return .{ .x = 0.0, .y = 0.0 };
    }

    // Edges
    pub fn getLeftEdge(self: *const Engine) f32 {
        return -self.getGameWidth() / 2.0;
    }
    pub fn getRightEdge(self: *const Engine) f32 {
        return self.getGameWidth() / 2.0;
    }
    pub fn getTopEdge(self: *const Engine) f32 {
        _ = self;
        return 10.0;
    }
    pub fn getBottomEdge(self: *const Engine) f32 {
        _ = self;
        return -10.0;
    }

    // Bounds checking
    pub fn isInBounds(self: *const Engine, point: V2) bool {
        return point.x >= self.getLeftEdge() and
            point.x <= self.getRightEdge() and
            point.y >= self.getBottomEdge() and
            point.y <= self.getTopEdge();
    }

    // Wrapping
    pub fn wrapPosition(self: *const Engine, point: V2) V2 {
        var wrapped = point;
        const width = self.getGameWidth();
        const left = self.getLeftEdge();
        const right = self.getRightEdge();
        const top = self.getTopEdge();
        const bottom = self.getBottomEdge();

        if (wrapped.x < left) wrapped.x += width;
        if (wrapped.x > right) wrapped.x -= width;

        if (wrapped.y < bottom) wrapped.y += 20.0;
        if (wrapped.y > top) wrapped.y -= 20.0;

        return wrapped;
    }

    // Normalized coords
    pub fn normalizedToGame(self: *const Engine, nx: f32, ny: f32) V2 {
        const hw = self.getGameWidth() / 2.0;
        return .{
            .x = (nx * 2.0 - 1.0) * hw, // [0,1] -> [-hw, hw]
            .y = (ny * 2.0 - 1.0) * 10.0, // [0,1] -> [-10, 10]
        };
    }
    pub fn gameToNormalized(self: *const Engine, point: V2) struct { x: f32, y: f32 } {
        const hw = self.getGameWidth() / 2.0;
        return .{
            .x = (point.x / hw + 1.0) / 2.0, // [-hw, hw] -> [0,1]
            .y = (point.y / 10.0 + 1.0) / 2.0, // [-10, 10] -> [0,1]
        };
    }
};

// Input (from platform)
pub const Key = platform.Key;
pub const MouseButton = platform.MouseButton;
pub const isKeyDown = platform.isKeyDown;
pub const isMouseButtonDown = platform.isMouseButtonDown;
pub const getMousePosition = platform.getMousePosition;
