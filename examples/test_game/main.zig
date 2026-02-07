const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;
const debug = engine.debug;
const DebugCategory = debug.DebugCategory;
const log = engine.log;

const Colors = engine.Colors;

const logical_width = 1920;
const logical_height = 1080;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const game = engine.Engine.init(
        allocator,
        "ECS Demo",
        logical_width,
        logical_height,
    );
    defer game.deinit();

    // leave to make sure it's ok if there are collisions or reimports
    // TODO: these all need to handle errors better or catch at engine level or be fatal
    try game.loadScene("master", "master");
    log.info(.scene, "Loading {s}.scene", .{"master"});
    try game.setActiveScene("master");
    log.info(.scene, "Loading {s}.scene", .{"collision_test"});
    try game.loadScene("collision", "collision_test");
    try game.setActiveScene("collision");

    try game.loadScene("action", "action_test.scene");
    log.info(.scene, "Loading {s}.scene", .{"action_test"});
    try game.setActiveScene("action");

    // Camera test scene - simple scene to test camera controls
    try game.loadScene("camera", "camera_test.scene");
    log.info(.scene, "Loading {s}.scene", .{"camera_test"});
    try game.setActiveScene("camera");

    // UI test scene - tests screen-space HUD elements
    try game.loadScene("ui", "ui_test.scene");
    log.info(.scene, "Loading {s}.scene", .{"ui_test"});
    try game.setActiveScene("ui");

    // NOTE loading all scenes and setting to active to see where/when something breaks
    try game.instantiateActiveScene();
    log.info(.scene, "Instantiated ui_test-scene as the active scene", .{});

    try game.loadTemplates("assets/templates/");

    // ===== CAMERA TRACKING SETUP =====
    // Find the player entity and set camera to track it
    const player_entity = game.findEntityByTag("player");
    if (player_entity) |player| {
        game.enableActiveCameraTracking();
        game.setActiveCameraTrackingTarget(player);

        // Spring-damper settings for smooth, natural camera follow
        // Higher stiffness = stronger pull toward target
        // Higher damping = less overshoot/bounce
        game.setActiveCameraFollowStiffness(30.0, 30.0);
        game.setActiveCameraFollowDamping(15.0, 15.0);
    }
    // ===== END CAMERA TRACKING SETUP =====

    // ===== MANUAL UI ELEMENT TEST =====
    // Create a hardcoded UIElement to test if the rendering pipeline works
    {
        const RectScreen = engine.Rectangle(engine.ScreenPoint);
        const test_ui = game.createEntity();
        game.addComponent(test_ui, engine.UIElement, .{
            .anchor = .TopRight,
            .offset = .{ .x = -100, .y = 100 },
        });
        game.addComponent(test_ui, engine.Sprite, .{
            .geometry = engine.ShapeRegistry.createShapeUnion(
                RectScreen,
                RectScreen{
                    .center = .{ .x = 0, .y = 0 }, // Centered at anchor + offset
                    .half_width = 50,
                    .half_height = 50,
                },
            ),
            .fill_color = Colors.NEON_MAGENTA,
            .stroke_color = Colors.WHITE,
            .stroke_width = 3.0,
            .visible = true,
        });
        game.addComponent(test_ui, engine.Tag, .{ .tags = "test-ui" });
    }
    // ===== END MANUAL UI ELEMENT TEST =====

    // ===== UI TEST SCENE NOTES =====
    // This scene tests screen-space UI elements (HUD) vs world-space rendering:
    //
    // WORLD-SPACE ELEMENTS (move with camera):
    // - Pink circle at origin (0, 0) - world center reference
    // - Red rectangles at N/S (±20 Y) - vertical extent markers
    // - Blue rectangles at E/W (±30 X) - horizontal extent markers
    // - Yellow circles at corners - world bounds visualization
    // - Green circle (player) - WASD to move, camera follows
    // - Gray dots - grid pattern to show culling
    //
    // SCREEN-SPACE ELEMENTS (stay fixed on screen):
    // - Health bar (top-left) - green bar with background
    // - Score display (top-right) - blue background panel
    // - Crosshair (screen center) - red circle
    // - Mini-map (top-right corner) - teal bordered square with player dot
    // - Bottom UI panel - gray panel at bottom of screen
    //
    // CONTROLS:
    //   WASD: Move green player - camera follows with spring-damper smoothing
    //   T: Toggle camera tracking on/off
    //   Arrow Keys: Pan camera manually (only when tracking disabled)
    //   Q/E: Zoom in/out
    //   R: Reset camera to origin
    //   [: Loose camera follow (laggy, floaty)
    //   ]: Tight camera follow (responsive, snappy)
    //
    // WHAT TO TEST:
    //   1. Move camera - HUD elements should STAY FIXED on screen
    //   2. World elements should move when camera pans/zooms
    //   3. UI elements should ignore camera transform completely
    //   4. Test that screen-space coordinates are in pixel units
    // =======================================

    // Debug text for font testing (comment out if not needed)
    // game.debugger.draw.addText(.{
    //     .text = "ABCDEFGHIJKLMNOPQURSTUVWXYZ",
    //     .owns_text = false,
    //     .color = Colors.ORANGE,
    //     .duration = std.math.inf(f32),
    //     .position = .{ .x = -13, .y = -8.0 },
    //     .size = 0.6,
    //     .cat = DebugCategory.single(.custom),
    // });
    // game.debugger.draw.addText(.{
    //     .text = "abcdefghijklmnopqrstuvwxyz",
    //     .owns_text = false,
    //     .color = Colors.ORANGE,
    //     .duration = std.math.inf(f32),
    //     .position = .{ .x = -13, .y = -8.5 },
    //     .size = 0.2,
    //     .cat = DebugCategory.single(.custom),
    // });

    // Create paddle (player-controlled)
    // {
    //     const paddle = game.createEntity();
    //     game.addComponent(paddle, engine.Transform, .{
    //         .position = .{ .x = 0.0, .y = game_height / 2.0 - 20.0 },
    //         .scale = 1.0,
    //         .rotation = 0.0,
    //     });
    //     game.addComponent(paddle, engine.Sprite, .{
    //         .geometry = .{
    //             .Rectangle = .{
    //                 .center = .{ .x = 0.0, .y = 0.0 },
    //                 .half_width = 2.0,
    //                 .half_height = 0.5,
    //             },
    //         },
    //         .fill_color = Colors.WHITE,
    //     });
    //     game.addComponent(paddle, engine.Velocity, .{
    //         .linear = .{ .x = 0.0, .y = 0.0 },
    //         .angular = 0.0,
    //     });
    //     game.addComponent(paddle, engine.Tag, .{
    //         .tags = "paddle",
    //     });

    //     // Paddle input: Arrow keys move, Space spawns missile
    //     const paddle_speed = 15.0; // Adjust this value to tune paddle movement speed
    //     var paddle_input_triggers = [_]engine.InputTrigger{
    //         // Left arrow - move left
    //         .{
    //             .input = .{ .key = KeyCode.Left },
    //             .actions = &[_]engine.Action{
    //                 .{
    //                     .action_type = .{
    //                         .set_velocity = .{
    //                             .target = .self,
    //                             .velocity = .{ .x = -paddle_speed, .y = 0.0 },
    //                         },
    //                     },
    //                     .priority = 0,
    //                 },
    //             },
    //         },
    //         // Right arrow - move right
    //         .{
    //             .input = .{ .key = KeyCode.Right },
    //             .actions = &[_]engine.Action{
    //                 .{
    //                     .action_type = .{
    //                         .set_velocity = .{
    //                             .target = .self,
    //                             .velocity = .{ .x = paddle_speed, .y = 0.0 },
    //                         },
    //                     },
    //                     .priority = 0,
    //                 },
    //             },
    //         },
    //         // Spacebar - spawn missile
    //         .{
    //             .input = .{ .key = KeyCode.Space },
    //             .actions = &[_]engine.Action{
    //                 .{
    //                     .action_type = .{
    //                         .spawn_entity = .{
    //                             .template_name = "missile",
    //                             .offset = .{ .x = 0.0, .y = 0.0 },
    //                         },
    //                     },
    //                     .priority = 0,
    //                 },
    //             },
    //         },
    //     };
    //     game.addComponent(paddle, engine.OnInput, .{
    //         .triggers = &paddle_input_triggers,
    //     });
    // }

    // +++++++ GAME LOOP FOR NOW ++++++++++ //
    var last_time = std.time.milliTimestamp();

    // Camera control settings
    const camera_pan_speed: f32 = 10.0; // units per second
    const zoom_in_factor: f32 = 0.9; // 10% closer each press
    const zoom_out_factor: f32 = 1.1; // 10% farther each press

    // Camera tracking tuning
    var camera_tracking_enabled = true;
    while (!game.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const dt: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);

        // ===== CAMERA TRACKING TOGGLE (T key) =====
        if (game.isPressed(KeyCode.T)) {
            camera_tracking_enabled = !camera_tracking_enabled;
            if (camera_tracking_enabled) {
                game.enableActiveCameraTracking();
            } else {
                game.disableActiveCameraTracking();
            }
        }

        // ===== CAMERA SPRING-DAMPER TUNING ([ and ] keys) =====
        if (game.isPressed(KeyCode.LeftBracket)) {
            // Loose follow - low stiffness, low damping (very laggy)
            game.setActiveCameraFollowStiffness(3.0, 3.0);
            game.setActiveCameraFollowDamping(1.5, 1.5);
        }
        if (game.isPressed(KeyCode.RightBracket)) {
            // Tight follow - high stiffness, high damping (responsive, no overshoot)
            game.setActiveCameraFollowStiffness(20.0, 20.0);
            game.setActiveCameraFollowDamping(10.0, 10.0);
        }

        // ===== CAMERA CONTROLS (Arrow keys for pan, Q/E for zoom, R for reset) =====
        // Only allow manual panning when tracking is disabled
        if (!camera_tracking_enabled) {
            // Arrow key panning
            if (game.isDown(KeyCode.Up)) {
                game.translateActiveCamera(
                    .{ .x = 0, .y = camera_pan_speed * dt },
                );
            }
            if (game.isDown(KeyCode.Down)) {
                game.translateActiveCamera(
                    .{ .x = 0, .y = -camera_pan_speed * dt },
                );
            }
            if (game.isDown(KeyCode.Left)) {
                game.translateActiveCamera(
                    .{ .x = -camera_pan_speed * dt, .y = 0 },
                );
            }
            if (game.isDown(KeyCode.Right)) {
                game.translateActiveCamera(
                    .{ .x = camera_pan_speed * dt, .y = 0 },
                );
            }
        }
        if (game.getMouseScrollDelta()) |scroll_delta| {
            game.zoomActiveCameraSmooth(scroll_delta.y);
        }
        // Q/E zoom
        if (game.isPressed(KeyCode.Q)) {
            game.zoomActiveCameraInc(zoom_in_factor); // Zoom in
        }
        if (game.isPressed(KeyCode.E)) {
            game.zoomActiveCameraInc(zoom_out_factor); // Zoom out
        }

        // R reset camera
        if (game.isPressed(KeyCode.R)) {
            game.setActiveCameraPosition(.{ .x = 0, .y = 0 });
            game.setActiveCameraOrthoSize(20.0);
        }
        // ===== END CAMERA CONTROLS =====

        game.update(dt);

        // Test screen-space text rendering
        const font = game.getFont("__default__") catch unreachable;
        const ctx: engine.RenderContext = .{
            .camera_loc = .{ .x = 0, .y = 0 },
            .height = logical_height,
            .width = logical_width,
            .ortho_size = logical_height / 2,
        };
        game.renderer.drawTextScreen(font, "test screen", .{ .x = 100, .y = 100 }, 30.0, engine.Colors.WHITE, ctx);

        game.endFrame();

        // if (game.hasErrors()) {
        //     const errs = game.getErrors();
        //     for (errs) |err| {
        //         std.debug.print("{s}\n", .{err.message});
        //     }
        // }
        // game.clearErrors();
    }
}
