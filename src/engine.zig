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
pub const WorldPoint = V2;
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
pub const ActiveCamera = ecs.ActiveCamera;
const action = @import("action");
pub const Action = action.Action;
pub const ActionSystem = action.ActionSystem;
pub const InputTrigger = action.InputTrigger;
pub const CollisionTrigger = action.CollisionTrigger;
pub const TriggerContext = action.TriggerContext;
pub const Input = core.Input;
pub const ErrorLogger = core.error_logger.ErrorLogger;
pub const Severity = core.error_logger.Severity;
pub const Subsystem = core.error_logger.SubSystem;
pub const ErrorEntry = core.error_logger.ErrorEntry;
const Systems = @import("Systems.zig");
const scene = @import("scene");
pub const Instantiator = scene.Instantiator;
pub const SceneManager = scene.SceneManager;
pub const TemplateManager = scene.TemplateManager;
pub const Template = scene.Template;
pub const debug = @import("debug");
pub const Debugger = debug.DebugManager;
pub const DebugCategory = debug.DebugCategory;
const builtin = @import("builtin");
const debug_enabled = builtin.mode == .Debug;

const PerformanceMetrics = struct {
    current_fps: f32 = 0,
    frame_time_ms: f32 = 0,
    frame_count: u64 = 0,

    fps_frame_accum: f32 = 0,
    fps_time_accum: f32 = 0,
    fps_update_interval: f32 = 0.25,

    min_fps: f32 = std.math.inf(f32),
    max_fps: f32 = 0,

    pub fn update(self: *PerformanceMetrics, dt: f32) void {
        self.frame_count += 1;
        self.fps_frame_accum += 1.0;
        self.fps_time_accum += dt;

        if (self.fps_time_accum >= self.fps_update_interval) {
            self.current_fps = self.fps_frame_accum / self.fps_time_accum;
            self.frame_time_ms = (self.fps_time_accum / self.fps_frame_accum) * 1000.0;

            if (self.current_fps < self.min_fps) {
                self.min_fps = self.current_fps;
            }
            if (self.current_fps > self.max_fps) {
                self.max_fps = self.current_fps;
            }

            self.fps_frame_accum = 0.0;
            self.fps_time_accum = 0.0;
        }
    }
};

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

    debugger: Debugger,
    performance_metrics: PerformanceMetrics = .{},
    error_logger: ErrorLogger,

    active_camera_entity: ?Entity = null,

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

        var world = World.init(allocator) catch |err| blk: {
            std.log.err("[ECS] Unable to create a world entity manager: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };
        // Create main camera
        const camera = world.createEntity() catch |err| blk: {
            std.log.err("[ASSETS] Unable to create main_default_camera: {any}", .{err});
            had_error = true;
            break :blk undefined;
        };
        try world.addComponent(camera, ActiveCamera, ActiveCamera{});
        try world.addComponent(camera, Transform, Transform{});
        try world.addComponent(camera, Camera, Camera{
            .ortho_size = 25.0,
            .viewport = .{
                .center = V2.ZERO,
                .half_width = @floatFromInt(scaled_width / 2),
                .half_height = @floatFromInt(scaled_height / 2),
            },
            .priority = 1,
        });

        const asset_manager = AssetManager.init(allocator) catch |err| blk: {
            std.log.err("[ASSETS] Unable to create an asset manager: {any}", .{err});
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
            .debugger = undefined,
            .active_camera_entity = camera,
        };

        engine.instantiator = .init(allocator, &engine.world, &engine.assets);
        engine.template_manager = .init(allocator, &engine.instantiator);
        engine.world.template_manager = &engine.template_manager;

        // Get the default font for debug rendering
        const default_font = try engine.assets.getFontByName("__default__");
        engine.debugger = .init(allocator, &engine.renderer, default_font);

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
        self.debugger.deinit();

        allocator.destroy(self);
    }

    pub fn shouldClose(self: *const Engine) bool {
        return !self.running or self.window.shouldClose();
    }

    pub fn checkInternals(self: *Engine) void {
        if (self.input.isDown(KeyCode.Esc)) {
            self.running = false;
        }
        if (self.input.isPressed(KeyCode.F1)) {
            self.debugger.draw.toggleCategory(.collision);
        }
        if (self.input.isPressed(KeyCode.F2)) {
            self.debugger.draw.toggleCategory(.velocity);
        }
        if (self.input.isPressed(KeyCode.F3)) {
            self.debugger.draw.toggleCategory(.entity_info);
        }
        if (self.input.isPressed(KeyCode.F4)) {
            self.debugger.draw.toggleCategory(.grid);
        }
        if (self.input.isPressed(KeyCode.F5)) {
            self.debugger.draw.toggleCategory(.fps);
        }
        if (self.input.isPressed(KeyCode.F6)) {
            self.debugger.draw.toggleCategory(.custom);
        }
    }

    pub fn update(self: *Engine, dt: f32) void {
        self.performance_metrics.update(dt);
        if (debug_enabled) {
            self.checkInternals();
        }
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
        Systems.renderSystem(self, dt);
        if (debug_enabled) {
            Systems.debugEntityInfoSystem(self);
            var buf: [64]u8 = undefined;
            const fps: f32 = self.performance_metrics.current_fps;
            const color = if (fps > 55) Colors.GREEN else if (fps > 30 and fps < 55) Colors.YELLOW else Colors.RED;
            const fps_text = std.fmt.bufPrint(&buf, "FPS: {d:.1}", .{fps}) catch "FPS: --";
            self.debugger.draw.addText(.{
                .text = self.allocator.dupe(u8, fps_text) catch "",
                .position = .{ .x = 10.0, .y = 9.0 },
                .color = color,
                .size = 0.5,
                .duration = null,
                .cat = DebugCategory.single(.fps),
                .owns_text = true,
            });
        }
    }

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

    // Creating shapes by hand
    pub fn create(self: *Engine, comptime Data: type, args: anytype) Data {
        return @call(.auto, Data.init, .{self.allocator} ++ args) catch |err| {
            std.debug.panic(
                "Engine.create({s}) failed: {}\n memory leaking or to large",
                .{ @typeName(Data), err },
            );
        };
    }

    // MARK: Camera
    pub fn createCamera(
        self: *Engine,
    ) !Entity {
        const camera = try self.world.createEntity();
        try self.world.addComponent(camera, ActiveCamera, ActiveCamera{});
        try self.world.addComponent(camera, Transform, Transform{});
        try self.world.addComponent(camera, Camera, Camera{
            .orthoSize = 10.0,
            .viewport = .{
                .center = V2.ZERO,
                .half_width = @floatFromInt(self.getGameWidth() / 2),
                .half_height = @floatFromInt(self.getGameHeight() / 2),
            },
            .priority = 1,
        });
        return camera;
    }
    pub fn setActiveCamera(self: *Engine, camera: Entity) void {
        self.active_camera_entity = camera;
    }
    pub fn getActiveCamera(self: *const Engine) ?Entity {
        return self.active_camera_entity;
    }
    pub fn getActiveCameraTransform(self: *const Engine) ?*const Transform {
        return self.world.getComponent(self.active_camera_entity.?, Transform);
    }
    pub fn setCameraPosition(self: *Engine, camera: Entity, location: WorldPoint) void {
        Camera.setPosition(self.world, camera, location.x, location.y);
    }
    pub fn setActiveCameraPosition(self: *Engine, location: WorldPoint) void {
        const camera = self.active_camera_entity orelse return;
        Camera.setPosition(&self.world, camera, location.x, location.y);
    }
    pub fn translateCamera(self: *Engine, camera: Entity, dxy: V2) void {
        Camera.translate(&self.world, camera, dxy.x, dxy.y);
    }
    pub fn translateActiveCamera(self: *Engine, dxy: V2) void {
        const camera = self.active_camera_entity orelse return;
        Camera.translate(&self.world, camera, dxy.x, dxy.y);
    }
    pub fn setCameraOrthoSize(self: *Engine, camera: Entity, new_size: f32) void {
        Camera.setOrthoSize(&self.world, camera, new_size);
    }
    pub fn setActiveCameraOrthoSize(self: *Engine, new_size: f32) void {
        const camera = self.active_camera_entity orelse return;
        Camera.setOrthoSize(&self.world, camera, new_size);
    }
    pub fn zoomCameraInc(self: *Engine, camera: Entity, factor: f32) void {
        Camera.zoom(&self.world, camera, factor);
    }
    pub fn zoomActiveCameraInc(self: *Engine, factor: f32) void {
        const camera = self.active_camera_entity orelse return;
        Camera.zoom(&self.world, camera, factor);
    }
    pub fn zoomCameraSmooth(self: *Engine, camera: Entity, delta: f32) void {
        Camera.smoothZoom(&self.world, camera, delta);
    }
    pub fn zoomActiveCameraSmooth(self: *Engine, factor: f32) void {
        const camera = self.active_camera_entity orelse return;
        Camera.smoothZoom(&self.world, camera, factor);
    }
    pub fn getCameraViewBounds(self: *Engine, camera: Entity) Rectangle {
        return Camera.getViewBounds(&self.world, camera);
    }
    pub fn getActiveCameraViewBounds(self: *Engine) Rectangle {
        const camera = self.active_camera_entity orelse return;
        return Camera.getViewBounds(&self.world, camera);
    }

    // MARK: Input
    pub fn isDown(self: *const Engine, input: anytype) bool {
        return self.input.isDown(input);
    }
    pub fn isPressed(self: *const Engine, input: anytype) bool {
        return self.input.isPressed(input);
    }
    pub fn isReleased(self: *const Engine, input: anytype) bool {
        return self.input.isReleased(input);
    }
    pub fn getAxis(self: *const Engine, negative: anytype, positive: anytype) f32 {
        return self.input.getAxis2d(negative, positive);
    }
    pub fn getAxis2d(self: *const Engine, left: anytype, right: anytype, up: anytype, down: anytype) V2 {
        return self.input.getAxis2d(left, right, up, down);
    }
    pub fn getMouseScrollDelta(self: *const Engine) ?V2 {
        const delta = self.input.mouse.scroll_delta;
        return if (delta.x == 0 and delta.y == 0) null else delta;
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
        if (self.scene_manager.scenes.contains(scene_name)) {
            self.logInfo(.scene, "Scene {s} is already loaded", .{scene_name});
            return;
        }

        self.scene_manager.loadScene(scene_name, filename) catch |err| {
            self.logError(
                .scene,
                "Failed to load scene '{s}' from '{s}': {any}",
                .{ scene_name, filename, err },
            );
            return;
        };

        self.logInfo(.scene, "Loaded scene '{s}' from '{s}'", .{ scene_name, filename });
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
        self.scene_manager.setActiveScene(scene_name) catch |err| {
            self.logError(.scene, "Failed to set the active scene: {any}", .{err});
            return {};
        };
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
