const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;

const Colors = engine.Colors;

const logical_width = 800 * 2;
const logical_height = 600 * 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = engine.Engine.init(
        allocator,
        "ECS Demo",
        logical_width,
        logical_height,
    );
    defer game.deinit();
    // // leave to make sure it's ok if there are collisions or reimports
    // TODO: these all need to handle errors better or catch at engine level or be fatal
    {
        try game.loadScene("master", "master");
        // // Load and instantiate the collision test scene
        try game.loadScene("collision", "collision_test");
        try game.setActiveScene("collision");
        try game.instantiateActiveScene();
    }
    const game_width = game.getGameWidth();
    const game_height = game.getGameHeight();
    game.logDebug(
        .engine,
        "GameWidth(f32): {d} GameHeight(f32): {d}",
        .{ game_width, game_height },
    );

    // Create paddle (player-controlled)
    const paddle = game.createEntity();
    game.addComponent(paddle, engine.Transform, .{
        .position = .{ .x = 0.0, .y = game_height / 2.0 - 20.0 },
        .scale = 1.0,
        .rotation = 0.0,
    });
    game.addComponent(paddle, engine.Sprite, .{
        .geometry = .{
            .rectangle = .{
                .center = .{ .x = 0.0, .y = 0.0 },
                .half_width = 2.0,
                .half_height = 0.5,
            },
        },
        .fill_color = Colors.WHITE,
    });
    game.addComponent(paddle, engine.Velocity, .{
        .linear = .{ .x = 0.0, .y = 0.0 },
        .angular = 0.0,
    });
    game.addComponent(paddle, engine.Tag, .{
        .names = &[_][]const u8{"paddle"},
    });

    // Paddle input: Arrow keys move, Space spawns missile
    const paddle_speed = 15.0; // Adjust this value to tune paddle movement speed
    const paddle_input_triggers = [_]engine.InputTrigger{
        // Left arrow - move left
        .{
            .input = .{ .key = KeyCode.Left },
            .actions = &[_]engine.Action{
                .{
                    .action_type = .{
                        .set_velocity = .{
                            .target = .self,
                            .velocity = .{ .x = -paddle_speed, .y = 0.0 },
                        },
                    },
                    .priority = 0,
                },
            },
        },
        // Right arrow - move right
        .{
            .input = .{ .key = KeyCode.Right },
            .actions = &[_]engine.Action{
                .{
                    .action_type = .{
                        .set_velocity = .{
                            .target = .self,
                            .velocity = .{ .x = paddle_speed, .y = 0.0 },
                        },
                    },
                    .priority = 0,
                },
            },
        },
        // Spacebar - spawn missile
        .{
            .input = .{ .key = KeyCode.Space },
            .actions = &[_]engine.Action{
                .{
                    .action_type = .{
                        .spawn_entity = .{
                            .template_name = "missile",
                            .offset = .{ .x = 0.0, .y = -30.0 },
                        },
                    },
                    .priority = 0,
                },
            },
        },
    };
    game.addComponent(paddle, engine.OnInput, .{
        .triggers = &paddle_input_triggers,
    });

    game.logDebug(
        .engine,
        "Made paddle: {d}, added Transform/Tag/Trigger",
        .{paddle.id},
    );

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

        game.update(dt);
        game.endFrame();

        if (game.hasErrors()) {
            const errs = game.getErrors();
            for (errs) |err| {
                std.debug.print("{s}\n", .{err.message});
            }
        }
        game.clearErrors();
    }
}
// // TEST: Click to spawn
// if (game.input.wasJustPressed(engine.MouseButton.Left)) {
//     const test_circle = try game.createEntity();
//     try game.addComponent(test_circle, engine.TransformComp, .{
//         .position = .{ .x = 0.0, .y = 0.0 }, // TODO: Use mouse position
//         .rotation = 0.0,
//         .scale = 1.0,
//     });
//     try game.addComponent(test_circle, engine.Sprite, .{
//         .geometry = .{
//             .circle = .{ .origin = .{ .x = 0.0, .y = 0.0 }, .radius = 1.0 },
//         },
//         .fill_color = engine.Colors.NEON_PINK,
//         .stroke_color = engine.Colors.WHITE,
//         .stroke_width = 1.0,
//         .visible = true,
//     });
//     try game.addComponent(test_circle, engine.Lifetime, .{ .remaining = 0.5 });
// }
// // TEST: hot reloading
// if (game.input.wasJustPressed(KeyCode.F5)) {
//     try game.reloadActiveScene();
// }
// // TEST: spawn an entity
// if (game.input.wasJustPressed(KeyCode.Space)) {
//     // TODO: lets just let the game add enties simply
//     const test_tri = try game.createEntity();
//     try game.addComponent(test_tri, engine.TransformComp, .{
//         .position = .{ .x = 0.0, .y = 5.0 },
//         .rotation = 0.0,
//         .scale = 1.0,
//     });
//     const test_tri_verts = [3]engine.V2{
//         .{ .x = 3.0, .y = 1.0 },
//         .{ .x = 1.0, .y = 1.0 },
//         .{ .x = -1.0, .y = -1.0 },
//     };
//     try game.addComponent(test_tri, engine.Sprite, .{
//         .geometry = .{ .triangle = try engine.Triangle.init(allocator, &test_tri_verts) },
//         .fill_color = engine.Colors.BLUE,
//         .stroke_color = engine.Colors.WHITE,
//         .stroke_width = 1.0,
//         .visible = true,
//     });
//     try game.addComponent(test_tri, engine.Lifetime, .{ .remaining = 2 });
// }
