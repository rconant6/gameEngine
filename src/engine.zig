const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const build_options = @import("build_options");
const platform = @import("platform");
pub const KeyCode = platform.KeyCode;
pub const KeyModifiers = platform.KeyModifiers;
pub const MouseButton = platform.MouseButton;
const core = @import("core");
pub const V2 = core.V2;
pub const V2I = core.V2I;
pub const V2U = core.V2U;
pub const ColliderRegistry = core.ColliderRegistry;
pub const ShapeRegisty = core.ShapeRegistry;
pub const ComponentRegistry = core.ComponentRegistry;
pub const Collision = core.Collision;
const renderer = @import("renderer");
pub const Color = renderer.Color;
pub const Colors = renderer.Colors;
pub const Circle = renderer.Circle;
pub const Rectangle = renderer.Rectangle;
pub const Triangle = renderer.Triangle;
pub const Polygon = renderer.Polygon;
pub const Line = renderer.Line;
pub const RenderContext = renderer.RenderContext;
pub const RenderTransform = renderer.Transform;
const assets = @import("asset");
const AssetManager = assets.AssetManager;
pub const FontHandle = assets.FontHandle;
pub const Font = assets.Font;
const ecs = @import("entity");
const World = ecs.World;
pub const Entity = ecs.Entity;
pub const Transform = ecs.Transform;
pub const Velocity = ecs.Velocity;
pub const Sprite = ecs.Sprite;
pub const Text = ecs.Text;
pub const RenderLayer = ecs.RenderLayer;
pub const ColliderShape = ecs.ColliderShape;
pub const Collider = ecs.Collider;
pub const Lifetime = ecs.Lifetime;
pub const ScreenWrap = ecs.ScreenWrap;
pub const ScreenClamp = ecs.ScreenClamp;
pub const Destroy = ecs.Destroy;
pub const Physics = ecs.Physics;
pub const Box = ecs.Box;
pub const Camera = ecs.Camera;
pub const Tag = ecs.Tag;
pub const OnInput = ecs.OnInput;
pub const OnCollision = ecs.OnCollision;
const action = @import("action");
pub const Action = action.Action;
pub const ActionSystem = action.ActionSystem;
pub const InputTrigger = action.InputTrigger;
pub const CollisionTrigger = action.CollisionTrigger;
pub const TriggerContext = action.TriggerContext;
pub const Input = core.Input;
const ErrorLogger = core.error_logger.ErrorLogger;
pub const Severity = core.error_logger.Severity;
pub const Subsystem = core.error_logger.SubSystem;
pub const ErrorEntry = core.error_logger.ErrorEntry;
const Systems = @import("Systems.zig");
const scene = @import("scene");
pub const Instantiator = scene.Instantiator;
pub const SceneManager = scene.SceneManager;
pub const TemplateManager = scene.TemplateManager;
pub const Template = scene.Template;

pub const Engine = struct {
    allocator: Allocator,
    input: Input,
    renderer: renderer.Renderer,
    assets: assets.AssetManager,
    window: platform.Window,
    world: ecs.World,
    collision_events: ArrayList(Collision),
    action_system: ActionSystem,
    running: bool,

    scene_manager: SceneManager,
    template_manager: TemplateManager,
    instantiator: Instantiator,

    error_logger: ErrorLogger,

    pub fn init(
        allocator: Allocator,
        title: []const u8,
        width: u32,
        height: u32,
    ) !*Engine {
        var had_error = false;
        platform.init() catch |err| {
            std.log.err("[PLATFORM] Unable to platform layer: {any}", .{err});
            had_error = true;
        };

        const window = platform.createWindow(.{
            .title = title,
            .width = width,
            .height = height,
        }) catch |err| blk: {
            std.log.err("[PLATFORM] Unable to native window: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };

        const scale_factor = platform.getWindowScaleFactor(window);

        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);

        const scaled_width: u32 = @intFromFloat(f_width * scale_factor);
        const scaled_height: u32 = @intFromFloat(f_height * scale_factor);

        const rend = renderer.Renderer.init(
            allocator,
            .{
                .width = scaled_width,
                .height = scaled_height,
                .native_handle = window.handle,
            },
        ) catch |err| blk: {
            std.log.err("[RENDERER] Unable to create rendering backend: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };

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

        const asset_manager = AssetManager.init(allocator) catch |err| blk: {
            std.log.err("[ASSETS] Unable to create an asset manager: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };
        const world = World.init(allocator) catch |err| blk: {
            std.log.err("[ECS] Unable to create a world entity manager: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };
        const input: Input = .init();
        const action_system = ActionSystem.init(allocator) catch |err| blk: {
            std.log.err("[ACTIONS] Unable to create the action system manager: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };

        if (had_error) {
            std.debug.print("FATAL: [ENGINE]Failed to initialize engine!! (see console)\n", .{});
            @panic("Engine Broke");
        }

        const engine = try allocator.create(Engine);
        errdefer allocator.destroy(engine);

        engine.* = Engine{
            .allocator = allocator,
            .input = input,
            .assets = asset_manager,
            .renderer = rend,
            .window = window.*,
            .world = world,
            .running = true,
            .action_system = action_system,
            .scene_manager = SceneManager.init(allocator),
            .error_logger = ErrorLogger.init(allocator),
            .collision_events = .empty,
            .instantiator = undefined,
            .template_manager = undefined,
        };

        engine.instantiator = .init(allocator, &engine.world, &engine.assets);
        engine.template_manager = .init(allocator, &engine.instantiator);

        return engine;
    }

    pub fn deinit(self: *Engine) void {
        self.logInfo(.engine, "Engine shutting down", .{});
        const allocator = self.allocator;
        self.action_system.deinit();
        self.collision_events.deinit(self.allocator);
        self.scene_manager.deinit();
        self.renderer.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.window.deinit();
        self.instantiator.deinit();
        self.error_logger.deinit();
        self.template_manager.deinit();
        allocator.destroy(self);
    }

    pub fn shouldClose(self: *const Engine) bool {
        return !self.running or self.window.shouldClose();
    }

    pub fn update(self: *Engine, dt: f32) void {
        Systems.lifetimeSystem(self, dt);
        Systems.screenWrapSystem(self);
        Systems.screenClampSystem(self);
        Systems.movementSystem(self, dt);
        Systems.physicsSystem(self, dt);
        Systems.collisionDetectionSystem(self);
        const context: TriggerContext = .{
            .collision_events = self.collision_events.items,
            .input = &self.input,
            .delta_time = dt,
            .action_queue = &self.action_system.action_queue,
        };
        self.action_system.update(&self.world, context) catch |err| {
            self.logError(.assets, "Action system failure: {any}", .{err});
        };
        Systems.cleanupSystem(self);
        Systems.renderSystem(self);
    }
    // pub fn render(self: *Engine) void {
    //     Systems.renderSystem(self);
    // }

    pub fn beginFrame(self: *Engine) void {
        platform.clearInputStates();
        _ = platform.pollEvent();
        self.input.keyboard = platform.getKeyboard();
        self.input.mouse = platform.getMouse();
        self.renderer.beginFrame() catch |err| {
            self.logError(.renderer, "Failure in beginFrame(): {any}", .{err});
        };
    }
    pub fn endFrame(self: *Engine) void {
        if (build_options.backend == .cpu) {
            const offset = self.renderer.getDisplayBufferOffset() orelse 0;
            self.window.swapBuffers(offset);
        }
        self.renderer.endFrame() catch |err| {
            self.logError(.renderer, "Failure in endFrame(): {any}", .{err});
        };
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
                .{ @typeName(Data), err },
            );
        };
    }

    // Drawing shapes
    pub fn draw(self: *Engine, shape: anytype, xform: ?RenderTransform) void {
        const T = @TypeOf(shape);
        const shape_union = ShapeRegisty.createShapeUnion(T);
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

    // ECS
    pub fn createEntity(self: *Engine) Entity {
        return self.world.createEntity() catch |err| {
            self.logError(.ecs, "Unable to add to create Entity: {any}", .{err});
        };
    }
    pub fn destroyEntity(self: *Engine, entity: Entity) void {
        self.world.destroyEntity(entity);
    }
    pub fn addComponent(
        self: *Engine,
        entity: Entity,
        comptime T: type,
        value: T,
    ) void {
        self.world.addComponent(entity, T, value) catch |err| {
            self.logError(
                .ecs,
                "Unable to add component to Entity: {d} {any}",
                .{ entity.id, err },
            );
        };
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

    // MARK: Assets
    pub fn getFont(self: *Engine, name: []const u8) !*const Font {
        return self.assets.getFontByName(name) catch |err| {
            self.logError(.assets, "Unable to get Font[{s}] {any}", .{ name, err });
            return err;
        };
    }

    // MARK: Collisions
    pub fn clearCollisionEvents(self: *Engine) void {
        self.collision_events.clearRetainingCapacity();
    }
    pub fn getCollisionEvents(self: *Engine) []const Collision {
        return self.collision_events.items;
    }

    // MARK: Scene/Template Management
    pub fn loadScene(
        self: *Engine,
        scene_name: []const u8,
        filename: []const u8,
    ) !void {
        self.scene_manager.loadScene(scene_name, filename) catch |err| {
            self.logError(
                .scene,
                "Failed to load scene '{s}' from '{s}': {any}",
                .{ scene_name, filename, err },
            );
            return;
        };

        self.logInfo(
            .scene,
            "Loaded scene '{s}' from '{s}'",
            .{ scene_name, filename },
        );
    }
    pub fn loadTemplates(
        self: *Engine,
        dir_path: []const u8,
    ) !void {
        self.template_manager.loadTemplatesFromDirectory(dir_path) catch |err| {
            self.logError(
                .scene,
                "Failed to load template(s) from '{s}': {any}",
                .{ dir_path, err },
            );
            return;
        };

        self.logInfo(
            .scene,
            "Loaded template(s) from '{s}'",
            .{dir_path},
        );
    }

    pub fn setActiveScene(self: *Engine, scene_name: []const u8) !void {
        try self.scene_manager.setActiveScene(scene_name);
    }

    pub fn instantiateActiveScene(self: *Engine) !void {
        const scene_file = self.scene_manager.getActiveScene() orelse return error.NoActiveScene;
        self.instantiator.instantiate(scene_file) catch |err| {
            self.logError(.scene, "Failed to instantiate scene: {any}", .{err});
            return err;
        };
    }

    pub fn reloadActiveScene(self: *Engine) !void {
        self.logInfo(.scene, "Reloading active scene...", .{});

        self.instantiator.clearLastInstantiated(&self.world);

        self.scene_manager.reloadActiveScene() catch |err| {
            self.logError(.scene, "Failed to reload scene: {any}", .{err});
            self.logWarning(.scene, "Keeping previous scene state", .{});

            try self.instantiateActiveScene();
            return;
        };

        try self.instantiateActiveScene();

        self.logInfo(.scene, "Scene reloaded successfully", .{});
    }

    // MARK: Error logging
    pub fn logDebug(
        self: *Engine,
        subsystem: Subsystem,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        self.error_logger.logDebug(subsystem, fmt, args, @src());
    }
    pub fn logInfo(
        self: *Engine,
        subsystem: Subsystem,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        self.error_logger.logInfo(subsystem, fmt, args, @src());
    }
    pub fn logWarning(
        self: *Engine,
        subsystem: Subsystem,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        self.error_logger.logWarning(subsystem, fmt, args, @src());
    }
    pub fn logError(
        self: *Engine,
        subsystem: Subsystem,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        self.error_logger.logError(subsystem, fmt, args, @src());
    }
    pub fn logFatal(
        self: *Engine,
        subsystem: Subsystem,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        self.error_logger.logFatal(subsystem, fmt, args, @src());
    }

    pub fn getErrors(self: *const Engine) []const ErrorEntry {
        return self.error_logger.getErrors();
    }
    pub fn hasErrors(self: *const Engine) bool {
        return self.error_logger.hasErrors();
    }
    pub fn clearErrors(self: *Engine) void {
        self.error_logger.clearErrors();
    }
};
