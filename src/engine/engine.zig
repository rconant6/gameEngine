const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const build_options = @import("build_options");
const platform = @import("platform");
const Input = platform.Input;
const KeyCode = platform.KeyCode;
const math = @import("math");
const V2 = math.V2;
const renderer = @import("renderer");
const Color = renderer.Color;
const Colors = renderer.Colors;
const assets = @import("assets");
const AssetManager = assets.AssetManager;
const ecs = @import("ecs");
const ActiveCamera = ecs.ActiveCamera;
const Camera = ecs.Camera;
const Collision = ecs.Collision;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const World = ecs.World;
const action = @import("action");
const ActionSystem = action.ActionSystem;
const TriggerContext = action.TriggerContext;
const scene = @import("scene");
const Instantiator = scene.Instantiator;
const SceneManager = scene.SceneManager;
const TemplateManager = scene.TemplateManager;
const debug = @import("debug");
const debug_enabled = debug.debug_enabled;
const DebugCategory = debug.DebugCategory;
const Debugger = debug.DebugManager;
const Systems = @import("systems");

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

    active_camera_entity: Entity,

    // Logical window dimensions (for UIElement / ScreenPoint Rendering)
    window_width: u32,
    window_height: u32,

    pub fn init(
        allocator: Allocator,
        title: []const u8,
        width: u32,
        height: u32,
    ) *Engine {
        Logger.init(allocator) catch |err| fatal("Logger", err);

        platform.init() catch |err| fatal("Platform Layer", err);
        log.info(.engine, "Platform layer initialized", .{});

        const window = platform.createWindow(.{
            .title = title,
            .width = width,
            .height = height,
        }) catch |err| fatal("Window Creation", err);
        log.info(
            .engine,
            "Main window initialized {{width: {d}, height: {d}}}",
            .{ width, height },
        );

        const scale_factor = platform.getWindowScaleFactor(window);
        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);
        const aspect_ratio = f_width / f_height;

        const scaled_width: u32 = @intFromFloat(f_width * scale_factor);
        const scaled_height: u32 = @intFromFloat(f_height * scale_factor);

        const rend = renderer.Renderer.init(
            allocator,
            .{
                .width = scaled_width,
                .height = scaled_height,
                .native_handle = window.handle,
            },
        ) catch |err| fatal("Renderer", err);
        log.info(
            .engine,
            "Renderer initialized: {{scaled width: {d}, scaled height: {d}}}",
            .{ scaled_width, scaled_height },
        );

        var world = World.init(allocator) catch |err| fatal("ECS World", err);
        log.info(.engine, "ECS(world) initialized", .{});

        const camera = world.createEntity() catch |err| fatal("Main Camera Entity", err);
        world.addComponent(camera, ActiveCamera, .{}) catch |err| fatal("ActiveCamera Component", err);
        world.addComponent(camera, Transform, .{}) catch |err| fatal("Transform Component", err);
        world.addComponent(camera, Camera, .{
            .ortho_size = 25.0,
            .viewport = .{
                .center = V2.ZERO,
                .half_width = aspect_ratio,
                .half_height = 1.0,
            },
            .priority = 1,
        }) catch |err| fatal("Camera Component", err);

        const asset_manager = AssetManager.init(allocator) catch |err| fatal("Asset Manager", err);
        log.info(.engine, "ASSET MANAGER initialized", .{});
        const action_system = ActionSystem.init(allocator) catch |err| fatal("Action System", err);
        log.info(.engine, "ACTIONS SYSTEM initialized", .{});

        const engine = allocator.create(Engine) catch |err| fatal("Engine Memory Allocation", err);

        engine.* = Engine{
            .allocator = allocator,
            .input = .init(),
            .assets = asset_manager,
            .renderer = rend,
            .window = window.*,
            .world = world,
            .running = true,
            .action_system = action_system,
            .scene_manager = SceneManager.init(allocator),
            .collision_events = .empty,
            .instantiator = undefined,
            .template_manager = undefined,
            .debugger = undefined,
            .active_camera_entity = camera,
            .window_width = width,
            .window_height = height,
        };

        engine.instantiator = .init(allocator, &engine.world, &engine.assets);
        engine.template_manager = .init(allocator, &engine.instantiator);
        engine.world.template_manager = &engine.template_manager;

        const default_font = engine.assets.getFontByName("__default__") catch |err| fatal("Default Font Loading", err);
        engine.debugger = .init(allocator, &engine.renderer, default_font);

        log.info(.engine, "Engine successfully started", .{});
        return engine;
    }

    pub fn fatal(subsystem: []const u8, err: anyerror) noreturn {
        @branchHint(.cold);
        log.fatal(
            .engine,
            "\n[FATAL] Engine initialization failed in: {s}\nReason: {s}\n",
            .{ subsystem, @errorName(err) },
        );
        std.debug.print(
            "\n[FATAL] Engine initialization failed in: {s}\nReason: {s}\n",
            .{ subsystem, @errorName(err) },
        );
        @panic("Engine Initialization Failure");
    }

    pub fn deinit(self: *Engine) void {
        const allocator = self.allocator;
        self.action_system.deinit();
        self.collision_events.deinit(self.allocator);
        self.scene_manager.deinit();
        self.renderer.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.window.deinit();
        self.instantiator.deinit();
        self.template_manager.deinit();
        self.debugger.deinit();
        log.info(.engine, "All systems shutdown", .{});
        Logger.deinit();
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
            log.info(.debug, "{s} info toggled", .{@tagName(.collision)});
        }
        if (self.input.isPressed(KeyCode.F2)) {
            self.debugger.draw.toggleCategory(.velocity);
            log.info(.debug, "{s} info toggled", .{@tagName(.velocity)});
        }
        if (self.input.isPressed(KeyCode.F3)) {
            self.debugger.draw.toggleCategory(.entity_info);
            log.info(.debug, "{s} info toggled", .{@tagName(.entity_info)});
        }
        if (self.input.isPressed(KeyCode.F4)) {
            self.debugger.draw.toggleCategory(.fps);
            log.info(.debug, "{s} info toggled", .{@tagName(.fps)});
        }
        if (self.input.isPressed(KeyCode.F5)) {
            self.debugger.draw.toggleCategory(.grid);
            log.info(.debug, "{s} info toggled", .{@tagName(.grid)});
        }
        if (self.input.isPressed(KeyCode.F6)) {
            self.debugger.draw.toggleCategory(.custom);
            log.info(.debug, "{s} info toggled", .{@tagName(.custom)});
        }
    }

    pub fn update(self: *Engine, dt: f32) void {
        self.performance_metrics.update(dt);
        if (debug_enabled) {
            self.checkInternals();
        }
        Systems.movementSystem(&self.world, dt, &self.debugger);
        Systems.physicsSystem(&self.world, dt);
        Systems.collisionDetectionSystem(
            &self.world,
            &self.collision_events,
            &self.debugger,
        );

        const context: TriggerContext = .{
            .collision_events = self.collision_events.items,
            .input = &self.input,
            .delta_time = dt,
            .action_queue = &self.action_system.action_queue,
        };
        Systems.actionSystem(&self.world, &self.action_system, context) catch {};
        Systems.cameraTrackingSystem(&self.world, dt);
        Systems.lifetimeSystem(&self.world, dt);
        Systems.renderSystem(
            &self.renderer,
            &self.world,
            &self.assets,
            self.active_camera_entity,
            dt,
            &self.debugger,
            self.window_width,
            self.window_height,
        );
        if (debug_enabled) {
            Systems.debugEntityInfoSystem(&self.world, &self.debugger);
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
            log.err(.renderer, "BeginFrame failed: {any}", .{err});
        };
    }
    pub fn endFrame(self: *Engine) void {
        if (build_options.backend == .cpu) {
            const offset = self.renderer.getDisplayBufferOffset() orelse 0;
            self.window.swapBuffers(offset);
        }
        self.renderer.endFrame() catch |err| {
            log.err(.renderer, "EndFrame failed: {any}", .{err});
        };
    }
    pub fn clear(self: *Engine, color: Color) void {
        self.renderer.setClearColor(color);
        self.renderer.clear();
    }

    // Creating shapes by hand
    // pub fn create(self: *Engine, comptime Data: type, args: anytype) Data {
    //     return @call(.auto, Data.init, .{self.allocator} ++ args) catch |err| {
    //         std.debug.panic(
    //             "Engine.create({s}) failed: {}\n memory leaking or to large",
    //             .{ @typeName(Data), err },
    //         );
    //     };
    // }

    // MARK: Camera methods
    pub const createCamera = @import("EngineCamera.zig").createCamera;
    pub const setActiveCamera = @import("EngineCamera.zig").setActiveCamera;
    pub const getActiveCamera = @import("EngineCamera.zig").getActiveCamera;
    pub const getActiveCameraTransform = @import("EngineCamera.zig").getActiveCameraTransform;
    pub const setCameraPosition = @import("EngineCamera.zig").setCameraPosition;
    pub const setActiveCameraPosition = @import("EngineCamera.zig").setActiveCameraPosition;
    pub const translateCamera = @import("EngineCamera.zig").translateCamera;
    pub const translateActiveCamera = @import("EngineCamera.zig").translateActiveCamera;
    pub const setCameraOrthoSize = @import("EngineCamera.zig").setCameraOrthoSize;
    pub const setActiveCameraOrthoSize = @import("EngineCamera.zig").setActiveCameraOrthoSize;
    pub const zoomCameraInc = @import("EngineCamera.zig").zoomCameraInc;
    pub const zoomActiveCameraInc = @import("EngineCamera.zig").zoomActiveCameraInc;
    pub const zoomCameraSmooth = @import("EngineCamera.zig").zoomCameraSmooth;
    pub const zoomActiveCameraSmooth = @import("EngineCamera.zig").zoomActiveCameraSmooth;
    pub const getCameraViewBounds = @import("EngineCamera.zig").getCameraViewBounds;
    pub const getActiveCameraViewBounds = @import("EngineCamera.zig").getActiveCameraViewBounds;
    pub const setActiveCameraTrackingTarget = @import("EngineCamera.zig").setActiveCameraTrackingTarget;
    pub const enableActiveCameraTracking = @import("EngineCamera.zig").enableActiveCameraTracking;
    pub const disableActiveCameraTracking = @import("EngineCamera.zig").disableActiveCameraTracking;
    pub const setActiveCameraFollowStiffness = @import("EngineCamera.zig").setActiveCameraFollowStiffness;
    pub const setActiveCameraFollowDamping = @import("EngineCamera.zig").setActiveCameraFollowDamping;

    // MARK: Input methods
    pub const isDown = @import("EngineInput.zig").isDown;
    pub const isPressed = @import("EngineInput.zig").isPressed;
    pub const isReleased = @import("EngineInput.zig").isReleased;
    pub const getAxis = @import("EngineInput.zig").getAxis;
    pub const getAxis2d = @import("EngineInput.zig").getAxis2d;
    pub const getMouseScrollDelta = @import("EngineInput.zig").getMouseScrollDelta;

    // MARK: Render methods
    pub const draw = @import("EngineRender.zig").draw;

    // MARK: Bounds methods
    pub const getGameWidth = @import("EngineBounds.zig").getGameWidth;
    pub const getGameHeight = @import("EngineBounds.zig").getGameHeight;
    pub const getTopLeft = @import("EngineBounds.zig").getTopLeft;
    pub const getTopRight = @import("EngineBounds.zig").getTopRight;
    pub const getBottomLeft = @import("EngineBounds.zig").getBottomLeft;
    pub const getBottomRight = @import("EngineBounds.zig").getBottomRight;
    pub const getCenter = @import("EngineBounds.zig").getCenter;
    pub const getLeftEdge = @import("EngineBounds.zig").getLeftEdge;
    pub const getRightEdge = @import("EngineBounds.zig").getRightEdge;
    pub const getTopEdge = @import("EngineBounds.zig").getTopEdge;
    pub const getBottomEdge = @import("EngineBounds.zig").getBottomEdge;
    pub const isInBounds = @import("EngineBounds.zig").isInBounds;
    pub const wrapPosition = @import("EngineBounds.zig").wrapPosition;
    pub const normalizedToGame = @import("EngineBounds.zig").normalizedToGame;
    pub const gameToNormalized = @import("EngineBounds.zig").gameToNormalized;

    // MARK: World/ECS methods
    pub const createEntity = @import("EngineWorld.zig").createEntity;
    pub const destroyEntity = @import("EngineWorld.zig").destroyEntity;
    pub const addComponent = @import("EngineWorld.zig").addComponent;
    pub const findEntityByTag = @import("EngineWorld.zig").findEntityByTag;
    pub const findEntitiesByTag = @import("EngineWorld.zig").findEntitiesByTag;
    pub const findEntitiesByPattern = @import("EngineWorld.zig").findEntitiesByPattern;

    // MARK: Asset methods
    pub const getFont = @import("EngineAssets.zig").getFont;

    // MARK: Collision methods
    pub const clearCollisionEvents = @import("EngineCollision.zig").clearCollisionEvents;
    pub const getCollisionEvents = @import("EngineCollision.zig").getCollisionEvents;

    // MARK: Scene methods
    pub const loadScene = @import("EngineScene.zig").loadScene;
    pub const loadTemplates = @import("EngineScene.zig").loadTemplates;
    pub const setActiveScene = @import("EngineScene.zig").setActiveScene;
    pub const instantiateActiveScene = @import("EngineScene.zig").instantiateActiveScene;
    pub const reloadActiveScene = @import("EngineScene.zig").reloadActiveScene;

    // MARK: Logging methods
    const logger = @import("debug");
    const Logger = logger.Logger;
    pub const log = logger.log;
};
