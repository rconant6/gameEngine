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

    var game = try engine.Engine.init(
        allocator,
        "ECS Demo",
        logical_width,
        logical_height,
    );
    defer game.deinit();
    // try game.loadScene("master", "master");
    // Load and instantiate the collision test scene
    try game.loadScene("collision", "collision_test");
    try game.setActiveScene("collision");
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
        game.clearCollisionEvents();
        const collisions = game.getCollisionEvents();
        if (collisions.len > 0) {
            game.logInfo(.engine, "Game had {d} collisions", .{collisions.len});
            for (collisions) |collision| {
                game.logDebug(
                    .engine,
                    "Entity1: {d}, Entity2: {d}",
                    .{ collision.entity_a.id, collision.entity_b.id },
                );
            }
        }
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
        if (game.hasErrors()) {
            const errs = game.getErrors();
            for (errs) |err| {
                std.debug.print("{s}\n", .{err.message});
            }
        }
        game.clearErrors();
    }
}
