const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;

const logical_width = 800 * 2;
const logical_height = 600 * 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game = try engine.Engine.init(
        allocator,
        "ECS Demo",
        logical_width,
        logical_height,
    );
    defer game.deinit();

    // Load and instantiate the main scene
    try game.loadScene("main", "game");
    try game.setActiveScene("main");
    try game.instantiateActiveScene();

    std.debug.print("\n=== GameDimensions ===\n", .{});
    const game_width = game.getGameWidth();
    const game_height = game.getGameHeight();
    std.debug.print("GameWidth(f32): {d} GameHeight(f32): {d}\n", .{ game_width, game_height });

    var last_time = std.time.milliTimestamp();
    while (!game.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const dt: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        try game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);

        // TEST: Click to spawn
        if (game.input.wasJustPressed(engine.MouseButton.Left)) {
            std.log.debug("[MAIN] left mouse was clicked", .{});
            const test_circle = try game.createEntity();
            try game.addComponent(test_circle, engine.TransformComp, .{
                .position = .{ .x = 0.0, .y = 0.0 }, // TODO: Use mouse position
                .rotation = 0.0,
                .scale = 1.0,
            });
            try game.addComponent(test_circle, engine.Sprite, .{
                .geometry = .{
                    .circle = .{ .origin = .{ .x = 0.0, .y = 0.0 }, .radius = 1.0 },
                },
                .fill_color = engine.Colors.NEON_PINK,
                .stroke_color = engine.Colors.WHITE,
                .stroke_width = 1.0,
                .visible = true,
            });
            try game.addComponent(test_circle, engine.Lifetime, .{ .remaining = 0.5 });
        }
        // TEST: hot reloading
        if (game.input.wasJustPressed(KeyCode.F5)) {
            try game.reloadActiveScene();
        }
        // TEST: finally quit!
        if (game.input.isPressed(KeyCode.Esc)) {
            game.running = false;
        }
        // TEST: spawn an entity
        if (game.input.wasJustPressed(KeyCode.Space)) {
            // TODO: lets just let the game add enties simply
            const test_tri = try game.createEntity();
            try game.addComponent(test_tri, engine.TransformComp, .{
                .position = .{ .x = 0.0, .y = 5.0 },
                .rotation = 0.0,
                .scale = 1.0,
            });
            const test_tri_verts = [3]engine.V2{
                .{ .x = 3.0, .y = 1.0 },
                .{ .x = 1.0, .y = 1.0 },
                .{ .x = -1.0, .y = -1.0 },
            };
            try game.addComponent(test_tri, engine.Sprite, .{
                .geometry = .{ .triangle = try engine.Triangle.init(allocator, &test_tri_verts) },
                .fill_color = engine.Colors.BLUE,
                .stroke_color = engine.Colors.WHITE,
                .stroke_width = 1.0,
                .visible = true,
            });
            try game.addComponent(test_tri, engine.Lifetime, .{ .remaining = 2 });
        }
        game.update(dt);
        game.render();

        try game.endFrame();
    }
}
// Find the GameScene declaration and instantiate it

// // Setup font
// try game.assets.setFontPath("assets/fonts");
// const font_handle = try game.assets.loadFont("Orbitron.ttf");
// const font = game.assets.fonts.getFont(font_handle);

// // Create bouncing circle (clamps to screen edges)
// const bouncer = try game.createEntity();
// try game.addComponent(bouncer, engine.TransformComp, .{
//     .position = .{ .x = 0.0, .y = 0.0 },
//     .rotation = 0.0,
//     .scale = 1.0,
// });
// try game.addComponent(bouncer, engine.Velocity, .{
//     .linear = .{ .x = 5.0, .y = 3.0 },
//     .angular = 0.0,
// });
// try game.addComponent(bouncer, engine.Sprite, .{
//     .geometry = .{ .circle = .{ .origin = .{ .x = 0.0, .y = 0.0 }, .radius = 2.0 } },
//     .fill_color = engine.Colors.NEON_GREEN,
//     .stroke_color = engine.Colors.WHITE,
//     .stroke_width = 1.0,
//     .visible = true,
// });
// try game.addComponent(bouncer, engine.ScreenClamp, .{});

// // Create wrapping rectangle (wraps around screen)
// const wrapper = try game.createEntity();
// try game.addComponent(wrapper, engine.TransformComp, .{
//     .position = .{ .x = -5.0, .y = -5.0 },
//     .rotation = 0.0,
//     .scale = 1.0,
// });
// try game.addComponent(wrapper, engine.Velocity, .{
//     .linear = .{ .x = 2.0, .y = 1.5 },
//     .angular = 1.0, // Rotate while moving
// });
// try game.addComponent(wrapper, engine.Sprite, .{
//     .geometry = .{ .rectangle = .{ .center = .{ .x = 0.0, .y = 0.0 }, .half_width = 1.5, .half_height = 1.0 } },
//     .fill_color = engine.Colors.NEON_PURPLE,
//     .stroke_color = engine.Colors.WHITE,
//     .stroke_width = 1.0,
//     .visible = true,
// });
// try game.addComponent(wrapper, engine.ScreenWrap, .{});

// // Create static triangle
// const static_tri = try game.createEntity();
// try game.addComponent(static_tri, engine.TransformComp, .{
//     .position = .{ .x = 0.0, .y = 5.0 },
//     .rotation = 0.0,
//     .scale = 1.0,
// });
// const tri_verts = [3]engine.V2{
//     .{ .x = 0.0, .y = 1.0 },
//     .{ .x = -1.0, .y = -1.0 },
//     .{ .x = 1.0, .y = -1.0 },
// };
// try game.addComponent(static_tri, engine.Sprite, .{
//     .geometry = .{ .triangle = try engine.Triangle.init(allocator, &tri_verts) },
//     .fill_color = engine.Colors.BLUE,
//     .stroke_color = engine.Colors.WHITE,
//     .stroke_width = 1.0,
//     .visible = true,
// });
// try game.addComponent(static_tri, engine.Lifetime, .{ .remaining = 2 });

// // Create text entity
// if (font) |_| {
//     const text_entity = try game.createEntity();
//     try game.addComponent(text_entity, engine.TransformComp, .{
//         .position = .{ .x = game.getLeftEdge() + 0.5, .y = game.getTopEdge() - 1.0 },
//         .rotation = 0.0,
//         .scale = 1.0,
//     });
//     try game.addComponent(text_entity, engine.Text, .{
//         .text = "ECS DEMO - Bouncing & Wrapping",
//         .font = font_handle,
//         .scale = 0.5,
//         .color = engine.Colors.NEON_ORANGE,
//     });
// }
