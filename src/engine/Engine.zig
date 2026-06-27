const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const build_options = @import("build_options");
const App = @import("app").App;
const platform = @import("platform");
const Input = platform.Input;
const KeyCode = platform.KeyCode;
const math = @import("math");
const V2 = math.V2;
const Memory = math.GameMemory;
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
const EngineServices = action.EngineServices;
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
const gsm = @import("game_state");
const GameStateManager = gsm.GameStateManager;
const SimulateOpts = gsm.SimulateOpts;
const TransitionResult = gsm.TransitionResult;
pub const StateDescriptor = gsm.StateDescriptor;
const EngineActionBridge = @import("EngineActionBridge.zig");
const EngineTransition = @import("EngineTransition.zig");

const PerformanceMetrics = struct {
    current_fps: f32 = 0,
    frame_time_ms: f32 = 0,
    frame_count: u64 = 0,

    fps_frame_accum: f32 = 0,
    fps_time_accum: f32 = 0,
    fps_update_interval: f32 = 0.25,

    min_fps: f32 = std.math.inf(f32),
    max_fps: f32 = 0,

    pub fn perfUpdate(self: *PerformanceMetrics, dt: f32) void {
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
    app: *App,
    mem: *Memory,
    io: std.Io,
    input: Input,
    assets: assets.AssetManager,
    world: ecs.World,
    collision_events: []const Collision,
    action_system: ActionSystem,
    services: EngineServices,
    active_systems: SimulateOpts,
    running: bool,

    state_manager: GameStateManager,
    frame_transition: ?TransitionResult = null,
    overlay_batches: ArrayList([]Entity),
    scene_manager: SceneManager,
    template_manager: TemplateManager,
    instantiator: Instantiator,

    debugger: Debugger,
    performance_metrics: PerformanceMetrics = .{},

    active_camera_entity: Entity,

    pub fn init(app: *App) *Engine {
        const mem = app.mem;
        const io = app.io;
        const width = app.logical_width;
        const height = app.logical_height;
        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);
        const aspect_ratio = f_width / f_height;

        var world = World.init(mem.persistent) catch |e| fatal(
            "ECS World",
            e,
        );
        log.info(.engine, "ECS(world) initialized", .{});

        const camera = world.createEntity() catch |e| fatal(
            "Main Camera Entity",
            e,
        );
        world.addComponent(camera, ActiveCamera, .{}) catch |e| fatal(
            "ActiveCamera Component",
            e,
        );
        world.addComponent(camera, Transform, .{}) catch |e| fatal(
            "Transform Component",
            e,
        );
        world.addComponent(camera, Camera, .{
            .ortho_size = 25.0,
            .viewport = .{
                .center = V2.ZERO,
                .half_width = aspect_ratio,
                .half_height = 1.0,
            },
            .priority = 1,
        }) catch |e| fatal("Camera Component", e);

        // Renderer pointer is re-seated to &engine.renderer after engine.* is assigned below.
        // Pass undefined here — TextureManager never dereferences the renderer pointer until first
        // texture upload, which happens after init is complete.
        const asset_manager = AssetManager.init(app.mem, io, undefined) catch |e| fatal(
            "Asset Manager",
            e,
        );
        log.info(.engine, "ASSET MANAGER initialized", .{});
        const action_system = ActionSystem.init(app.mem) catch |e| fatal(
            "Action System",
            e,
        );
        log.info(.engine, "ACTIONS SYSTEM initialized", .{});

        const engine = mem.persistent.create(Engine) catch |e| fatal(
            "Engine Memory Allocation",
            e,
        );

        engine.* = Engine{
            .app = app,
            .mem = app.mem,
            .io = io,
            .input = .init(),
            .assets = asset_manager,
            .world = world,
            .running = true,
            .active_systems = .{},
            .action_system = action_system,
            .scene_manager = SceneManager.init(mem.persistent, io),
            .collision_events = &.{},
            .instantiator = undefined,
            .template_manager = undefined,
            .debugger = undefined,
            .active_camera_entity = camera,
            .state_manager = GameStateManager.init(app.mem),
            .services = EngineServices{
                .ctx = undefined,
                .vtable = &EngineActionBridge.services_vtable,
            },
            .overlay_batches = .empty,
        };

        // Re-seat pointers to the stable heap address now that engine.* is assigned.
        engine.services.ctx = engine; // engine is already *Engine
        engine.action_system.services = &engine.services;
        engine.assets.textures.renderer = &engine.app.renderer;
        engine.instantiator = .init(
            mem.persistent,
            &engine.world,
            &engine.assets,
        );
        // late-bind the instantiator's action decode dependencies
        engine.instantiator.actions = &engine.action_system.registry;
        engine.instantiator.game = mem.game;
        engine.template_manager = .init(mem.persistent, io, &engine.instantiator);
        engine.world.template_manager = &engine.template_manager;

        const default_font = engine.assets.getFont("__default__") orelse fatal(
            "Default Font Loading",
            error.FontNotFound,
        );
        engine.debugger = .init(
            mem.frame,
            mem.persistent,
            &engine.app.renderer,
            default_font,
        );

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
        const mem = self.mem;
        for (self.overlay_batches.items) |batch| {
            self.mem.persistent.free(batch);
        }
        self.overlay_batches.deinit(self.mem.persistent);
        self.state_manager.deinit();
        self.action_system.deinit();
        self.scene_manager.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.instantiator.deinit();
        self.template_manager.deinit();
        self.debugger.deinit();
        log.info(.engine, "All systems shutdown", .{});
        mem.persistent.destroy(self);
    }

    pub fn shouldClose(self: *const Engine) bool {
        return !self.running or !self.app.isRunning();
    }

    pub fn checkInternals(self: *Engine) void {
        if (self.input.isDown(KeyCode.Esc)) {
            self.running = false;
        }
        if (self.input.isPressed(KeyCode.F1)) {
            self.debugger.toggleCategory(.collision);
            log.info(.debug, "{s} info toggled", .{@tagName(.collision)});
        }
        if (self.input.isPressed(KeyCode.F2)) {
            self.debugger.toggleCategory(.velocity);
            log.info(.debug, "{s} info toggled", .{@tagName(.velocity)});
        }
        if (self.input.isPressed(KeyCode.F3)) {
            self.debugger.toggleCategory(.entity_info);
            log.info(.debug, "{s} info toggled", .{@tagName(.entity_info)});
        }
        if (self.input.isPressed(KeyCode.F4)) {
            self.debugger.toggleCategory(.fps);
            log.info(.debug, "{s} info toggled", .{@tagName(.fps)});
        }
        if (self.input.isPressed(KeyCode.F5)) {
            self.debugger.toggleCategory(.grid);
            log.info(.debug, "{s} info toggled", .{@tagName(.grid)});
        }
        if (self.input.isPressed(KeyCode.F6)) {
            self.debugger.toggleCategory(.custom);
            log.info(.debug, "{s} info toggled", .{@tagName(.custom)});
        }
    }

    // NOTE: helper for doing system updates that can be configured base on what is needed
    fn simulate(self: *Engine, dt: f32, opts: SimulateOpts) void {
        self.performance_metrics.perfUpdate(dt);
        if (debug_enabled) {
            self.checkInternals();
        }

        // Hot reload: poll file mtimes once per second (~60 frames at 60fps)
        if (self.performance_metrics.frame_count % 60 == 0) {
            self.assets.checkForChanges() catch |err| {
                log.warn(.assets, "Hot reload check failed: {}", .{err});
            };
        }

        self.collision_events = &.{};
        if (opts.movement) Systems.movementSystem(&self.world, dt, &self.debugger);
        if (opts.physics) Systems.physicsSystem(&self.world, dt);
        if (opts.collision) {
            self.collision_events = Systems.collisionDetectionSystem(
                &self.world,
                self.mem.frame,
                &self.debugger,
            );
        }

        if (opts.actions) {
            const context: TriggerContext = .{
                .collision_events = self.collision_events,
                .input = &self.input,
                .delta_time = dt,
                .action_queue = &self.action_system.action_queue,
            };
            Systems.actionSystem(&self.world, &self.action_system, context) catch {};
        }
        if (opts.camera) Systems.cameraTrackingSystem(&self.world, dt);
        if (opts.lifetime) Systems.lifetimeSystem(&self.world, dt, self.mem.frame);
        if (opts.state_text) Systems.stateTextSystem(&self.world, &self.state_manager);
    }

    // NOTE: helper for just rendering the current frame and state
    fn render(self: *Engine, dt: f32) void {
        const maybe_ctx = Systems.renderSystem(
            &self.app.renderer,
            &self.world,
            &self.assets,
            self.active_camera_entity,
            dt,
            self.app.logical_width,
            self.app.logical_height,
        );
        if (maybe_ctx) |ctx| {
            if (debug_enabled) {
                Systems.debugEntityInfoSystem(
                    &self.world,
                    self.mem.frame,
                    &self.debugger,
                );
                var buf: [64]u8 = undefined;
                const fps: f32 = self.performance_metrics.current_fps;
                const color = if (fps > 55) Colors.GREEN else if (fps > 30 and fps < 55) Colors.YELLOW else Colors.RED;
                const fps_text = std.fmt.bufPrint(
                    &buf,
                    "FPS: {d:.1}",
                    .{fps},
                ) catch "FPS: --";
                self.debugger.draw.addText(.{
                    .text = self.mem.frameDupe(u8, fps_text) catch "",
                    .position = .{ .x = 10.0, .y = 9.0 },
                    .color = color,
                    .size = 0.5,
                    .cat = DebugCategory.single(.fps),
                });
            }
            self.debugger.run(dt, ctx);
        }
    }

    pub fn update(self: *Engine, dt: f32) void {
        self.simulate(dt, self.active_systems);
        self.render(dt);
    }

    pub fn beginFrame(self: *Engine) void {
        self.app.beginFrame() catch |err| {
            log.err(.engine, "BeginFrame failed: {any}", .{err});
        };
        self.collision_events = &.{};
        self.debugger.beginFrame();
        self.input.keyboard = platform.getKeyboard();
        self.input.mouse = platform.getMouse();
        self.frame_transition = null;
        if (self.state_manager.resolvePending()) |result| {
            EngineTransition.applyStateTransition(self, result);
            self.frame_transition = result;
        }
    }
    pub fn endFrame(self: *Engine) void {
        self.app.endFrame() catch |err| {
            log.err(.engine, "EndFrame failed: {any}", .{err});
        };
    }

    pub fn clear(self: *Engine, color: Color) void {
        self.app.renderer.setClearColor(color);
        self.app.renderer.clear();
    }

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

    // MARK: Game State Management
    pub const declareStates = @import("EngineState.zig").declareStates;
    pub const declareChildren = @import("EngineState.zig").declareChildren;
    pub const transitionTo = @import("EngineState.zig").transitionTo;
    pub const pushState = @import("EngineState.zig").pushState;
    pub const popState = @import("EngineState.zig").popState;
    pub const advanceState = @import("EngineState.zig").advanceState;
    pub const retreatState = @import("EngineState.zig").retreatState;
    pub const descendState = @import("EngineState.zig").descendState;
    pub const ascendState = @import("EngineState.zig").ascendState;
    pub const restartState = @import("EngineState.zig").restartState;
    pub const restartGame = @import("EngineState.zig").restartGame;
    pub const state = @import("EngineState.zig").state;
    pub const getCurrentStateName = @import("EngineState.zig").getCurrentStateName;
    pub const setStateVar = @import("EngineState.zig").setStateVar;
    pub const getStateVar = @import("EngineState.zig").getStateVar;
    pub const stateEntered = @import("EngineState.zig").stateEntered;
    pub const stateExited = @import("EngineState.zig").stateExited;
};
