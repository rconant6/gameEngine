const std = @import("std");
const build_options = @import("build_options");

const platform = @import("platform");
pub const KeyCode = platform.KeyCode;
pub const KeyModifiers = platform.KeyModifiers;
pub const MouseButton = platform.MouseButton;

const core = @import("core");
pub const Point = core.V2;
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
pub const Shape = renderer.Shape;
pub const Transform = renderer.Transform;

const assets = @import("asset");
pub const AssetManager = assets.AssetManager;
pub const FontHandle = assets.FontHandle;
pub const Font = assets.Font;

const ecs = @import("entity");
pub const World = ecs.World;
pub const Entity = ecs.Entity;
pub const Query = ecs.Query;
pub const ComponentStorage = ecs.ComponentStorage;
pub const TransformComp = ecs.Transform;
pub const Velocity = ecs.Velocity;
pub const Sprite = ecs.Sprite;
pub const Text = ecs.Text;
pub const RenderLayer = ecs.RenderLayer;
pub const CircleCollider = ecs.CircleCollider;
pub const RectCollider = ecs.RectCollider;
pub const Lifetime = ecs.Lifetime;
pub const ScreenWrap = ecs.ScreenWrap;
pub const ScreenClamp = ecs.ScreenClamp;

const Input = @import("Input.zig");

const Systems = @import("Systems.zig");

// const scene_format = @import("scene_format");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    input: Input,
    renderer: renderer.Renderer,
    assets: assets.AssetManager,
    window: platform.Window,
    world: ecs.World,
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
        const world = try World.init(allocator);
        const input: Input = .init();

        return .{
            .allocator = allocator,
            .input = input,
            .assets = asset_manager,
            .renderer = rend,
            .window = window.*,
            .world = world,
            .running = true,
        };
    }
    pub fn deinit(self: *Engine) void {
        std.log.info("[ENGINE] is shutting down...deinit()", .{});
        self.renderer.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.window.deinit();
    }

    pub fn shouldClose(self: *const Engine) bool {
        return !self.running or self.window.shouldClose();
    }

    pub fn update(self: *Engine, dt: f32) void {
        Systems.lifetimeSystem(self, dt);
        Systems.screenWrapSystem(self);
        Systems.screenClampSystem(self);
        Systems.movementSystem(self, dt);

        Systems.cleanupSystem(self);
    }
    pub fn render(self: *Engine) void {
        Systems.renderSystem(self);
    }

    pub fn beginFrame(self: *Engine) !void {
        platform.clearInputStates();
        _ = platform.pollEvent();
        self.input.keyboard = platform.getKeyboard();
        self.input.mouse = platform.getMouse();
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

    // Creating shapes
    pub fn create(self: *Engine, comptime Data: type, args: anytype) Data {
        return @call(.auto, Data.init, .{self.allocator} ++ args) catch |err| {
            std.debug.panic(
                "Engine.create({s}) failed: {}\n memory leaking or to large",
                .{ @typeName(Shape), err },
            );
        };
    }

    // Drawing shapes
    pub fn draw(self: *Engine, shape: anytype, xform: ?Transform) void {
        const T = @TypeOf(shape);
        const shape_union = switch (T) {
            Polygon => Shape{ .Polygon = shape },
            Rectangle => Shape{ .Rectangle = shape },
            Circle => Shape{ .Circle = shape },
            Triangle => Shape{ .Triangle = shape },
            Line => Shape{ .Line = shape },
            else => @compileError("Unsupported shape type: " ++ @typeName(T)),
        };
        self.renderer.drawShape(shape_union, xform);
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

    // ECS
    pub fn createEntity(self: *Engine) !Entity {
        return self.world.createEntity();
    }
    pub fn destroyEntity(self: *Engine, entity: Entity) void {
        self.world.destroyEntity(entity);
    }
    pub fn addComponent(self: *Engine, entity: Entity, comptime T: type, value: T) !void {
        try self.world.addComponent(entity, T, value);
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
