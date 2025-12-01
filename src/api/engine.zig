const std = @import("std");
const core = @import("core");
const renderer = @import("renderer");
const platform = @import("platform");

const build_options = @import("build_options");

pub const V2 = core.V2;
pub const V2I = core.V2I;

pub const Color = renderer.Color;
pub const Colors = renderer.Colors;

pub const Circle = renderer.Circle;
pub const Rectangle = renderer.Rectangle;
pub const Triangle = renderer.Triangle;
pub const Polygon = renderer.Polygon;
pub const Line = renderer.Line;

pub const Transform = renderer.Transform;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    renderer: renderer.Renderer,
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

        return .{
            .allocator = allocator,
            .renderer = rend,
            .window = window.*,
            .running = true,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
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

    // TODO: more convenience methods
};

// Input (from platform)
pub const Key = platform.Key;
pub const MouseButton = platform.MouseButton;
pub const isKeyDown = platform.isKeyDown;
pub const isMouseButtonDown = platform.isMouseButtonDown;
pub const getMousePosition = platform.getMousePosition;
