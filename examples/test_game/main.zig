const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;
const debug = engine.debug;
const DebugCategory = debug.DebugCategory;

const Colors = engine.Colors;

const logical_width = 800 * 2;
const logical_height = 600 * 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const game = try engine.Engine.init(
        allocator,
        "ECS Demo",
        logical_width,
        logical_height,
    );
    defer game.deinit();

    // leave to make sure it's ok if there are collisions or reimports
    // TODO: these all need to handle errors better or catch at engine level or be fatal
    // try game.loadScene("master", "master");
    // try game.setActiveScene("master");

    // try game.loadScene("collision", "collision_test");
    // try game.setActiveScene("collision");

    // try game.loadScene("action", "action_test.scene");
    // try game.setActiveScene("action");

    // Camera test scene - simple scene to test camera controls
    try game.loadScene("camera", "camera_test.scene");
    try game.setActiveScene("camera");

    // NOTE loading all 3 andd setting to active to see where/when something breaks
    try game.instantiateActiveScene();

    try game.loadTemplates("assets/templates/");
    // }
    const game_width = game.getGameWidth();
    const game_height = game.getGameHeight();
    game.logDebug(
        .engine,
        "GameWidth(f32): {d} GameHeight(f32): {d}",
        .{ game_width, game_height },
    );

    // ===== CAMERA TRACKING SETUP =====
    // TODO: Implement findEntityByTag, setActiveCameraTrackingTarget, enableActiveCameraTracking
    // Find the player entity and set camera to track it
    // const player_entity = game.findEntityByTag("player");
    // if (player_entity) |player| {
    //     game.setActiveCameraTrackingTarget(player);
    //     game.enableActiveCameraTracking();
    //
    //     // Start with smooth follow mode (tight tracking)
    //     game.setActiveCameraFollowStiffness(0.25, 0.25);
    // }
    // ===== END CAMERA TRACKING SETUP =====

    // ===== CAMERA TEST SCENE NOTES =====
    // This scene tests camera controls and coordinate systems:
    // - Pink circle at origin (0, 0) - world center reference
    // - Red rectangles at N/S (±20 Y) - vertical extent markers
    // - Blue rectangles at E/W (±30 X) - horizontal extent markers
    // - Yellow circles at corners - world bounds visualization
    // - Green circle (player) - WASD to move, demonstrates object movement vs camera
    // - Gray dots - grid pattern to show culling when camera moves
    //
    // CONTROLS:
    //   Arrow Keys: Pan camera (smooth movement)
    //   Q/E: Zoom in/out
    //   R: Reset camera to origin
    //   WASD: Move green player (separate from camera)
    //
    // WHAT TO TEST:
    //   1. Arrow keys pan camera - world appears to move opposite direction
    //   2. Q zooms in - see less world, entities appear larger
    //   3. E zooms out - see more world, entities appear smaller
    //   4. R resets camera - return to default view
    //   5. WASD moves player - player moves independently of camera
    //   6. Pan camera far from origin - markers should move/disappear correctly
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
    _ = true; // TODO: camera_tracking_enabled will be used when camera tracking is implemented

    while (!game.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const dt: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);

        // ===== CAMERA TRACKING TOGGLE (T key) =====
        // TODO: Implement camera tracking enable/disable functions
        // if (game.isPressed(KeyCode.T)) {
        //     camera_tracking_enabled = !camera_tracking_enabled;
        //     if (camera_tracking_enabled) {
        //         game.enableActiveCameraTracking();
        //     } else {
        //         game.disableActiveCameraTracking();
        //     }
        // }

        // ===== CAMERA STIFFNESS TUNING ([ and ] keys) =====
        // TODO: Implement setActiveCameraFollowStiffness
        // if (game.isPressed(KeyCode.LeftBracket)) {
        //     // Decrease stiffness (more loose/laggy)
        //     game.setActiveCameraFollowStiffness(0.1, 0.1);
        // }
        // if (game.isPressed(KeyCode.RightBracket)) {
        //     // Increase stiffness (more tight/responsive)
        //     game.setActiveCameraFollowStiffness(0.5, 0.5);
        // }

        // ===== CAMERA CONTROLS (Arrow keys for pan, Q/E for zoom, R for reset) =====
        // Only allow manual panning when tracking is disabled
        if (true) { // TODO: Replace with !camera_tracking_enabled when implemented
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
            game.setActiveCameraOrthoSize(10.0);
        }
        // ===== END CAMERA CONTROLS =====

        game.update(dt);

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
