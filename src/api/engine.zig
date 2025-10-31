const std = @import("std");
const core = @import("core");
const renderer = @import("renderer");
const platform = @import("platform");

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
        const rend = try renderer.Renderer.init(
            allocator,
            .{
                .width = width,
                .height = height,
                .native_handle = window.handle,
            },
        );
        std.log.debug("post window and renderer init", .{});
        const engine: Engine = .{
            .allocator = allocator,
            .renderer = rend,
            .window = window.*,
            .running = true,
        };

        std.log.debug("return struct constructed", .{});

        std.log.debug("returning", .{});
        return engine;
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.window.deinit();
    }

    pub fn shouldClose(self: *const Engine) bool {
        std.log.debug("engine.shouldClose\n", .{});
        return !self.running or self.window.shouldClose();
    }

    pub fn beginFrame(self: *Engine) !void {
        _ = platform.pollEvent();
        try self.renderer.beginFrame();
    }
    pub fn endFrame(self: *Engine) !void {
        try self.renderer.endFrame();
        self.window.swapBuffers();
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
