const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;
const debug = engine.debug;

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
    try game.loadScene("master", "master");
    // try game.setActiveScene("master");

    try game.loadScene("collision", "collision_test");
    // try game.setActiveScene("collision");

    try game.loadScene("action", "action_test.scene");
    try game.setActiveScene("action");

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
    while (!game.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const dt: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);

        // TEST: finally quit!
        // this should be handled by a trigger and update the game state
        if (game.input.isPressed(KeyCode.Esc)) {
            game.running = false;
        }

        // DEBUG TEST: Add some test debug primitives
        // Screen coords are ~26.67 wide x 20 high

        // Test line - diagonal across screen
        try game.debugger.draw.addLine(.{
            .start = .{ .x = 5.0, .y = 5.0 },
            .end = .{ .x = 21.0, .y = 15.0 },
            .color = Colors.RED,
            .duration = null, // one-frame
            .cat = .{ .custom = true },
        });

        // Test circle - center of screen
        try game.debugger.draw.addCircle(.{
            .origin = .{ .x = 13.33, .y = 10.0 },
            .radius = 3.0,
            .color = Colors.GREEN,
            .filled = false,
            .duration = null,
            .cat = .{ .collision = true },
        });

        // Test arrow - pointing right
        try game.debugger.draw.addArrow(.{
            .start = .{ .x = 8.0, .y = 10.0 },
            .end = .{ .x = 18.0, .y = 10.0 },
            .color = Colors.BLUE,
            .head_size = 1.0,
            .duration = null,
            .cat = .{ .velocity = true },
        });

        // Test rectangle - top-left corner
        try game.debugger.draw.addRect(.{
            .min = .{ .x = 2.0, .y = 2.0 },
            .max = .{ .x = 6.0, .y = 5.0 },
            .color = Colors.YELLOW,
            .filled = false,
            .duration = null,
            .cat = .{ .entity_info = true },
        });

        // Test arrow from rectangle center pointing WSW
        try game.debugger.draw.addArrow(.{
            .start = .{ .x = 4.0, .y = 3.5 },
            .end = .{ .x = 1.0, .y = 0.5 },
            .color = Colors.CYAN,
            .head_size = 0.7,
            .duration = null,
            .cat = .{ .velocity = true },
        });

        // Test persistent circle (stays for 2 seconds)
        try game.debugger.draw.addCircle(.{
            .origin = .{ .x = 20.0, .y = 15.0 },
            .radius = 1.5,
            .color = Colors.MAGENTA,
            .filled = true,
            .duration = 2.0,
            .cat = .{ .custom = true },
        });

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
