const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;

const loader = @import("scene/loader.zig");
const manager = @import("scene/manager.zig");
const SceneManager = manager.SceneManager;

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

    // Test SceneManager
    var scene_manager = SceneManager.init(allocator);
    defer scene_manager.deinit();

    // Load game.scene into the manager
    try scene_manager.loadScene("main", "game");
    std.debug.print("\n=== SceneManager Test ===\n", .{});
    std.debug.print("Loaded scene 'main' from game.scene\n", .{});

    // Set it as the active scene
    try scene_manager.setActiveScene("main");
    std.debug.print("Set 'main' as active scene\n", .{});

    // Get the active scene and print info
    if (scene_manager.getActiveScene()) |scene| {
        std.debug.print("\n=== Active Scene: {s} ===\n", .{scene.source_file_name});
        std.debug.print("Total declarations: {d}\n", .{scene.decls.len});
        for (scene.decls) |decl| {
            switch (decl) {
                .scene => |s| std.debug.print("  - Scene: {s}\n", .{s.name}),
                .entity => |e| std.debug.print("  - Entity: {s} ({d} components)\n", .{ e.name, e.components.len }),
                .asset => |a| std.debug.print("  - Asset: {s} (type: {s})\n", .{ a.name, @tagName(a.asset_type) }),
                .shape => |sh| std.debug.print("  - Shape: {s}\n", .{sh.name}),
                .component => |c| std.debug.print("  - Component: {s}\n", .{c.name}),
            }
        }
        std.debug.print("===========================\n\n", .{});
    } else {
        std.debug.print("ERROR: No active scene found!\n", .{});
    }

    // Test getting a specific scene
    if (scene_manager.getScene("main")) |scene| {
        std.debug.print("Successfully retrieved scene 'main' by name\n", .{});
        std.debug.print("Scene has {d} declarations\n\n", .{scene.decls.len});
    } else {
        std.debug.print("ERROR: Could not retrieve scene 'main'!\n\n", .{});
    }

    // Setup font
    try game.assets.setFontPath("assets/fonts");
    const font_handle = try game.assets.loadFont("Orbitron.ttf");
    const font = game.assets.fonts.getFont(font_handle);

    // Create bouncing circle (clamps to screen edges)
    const bouncer = try game.createEntity();
    try game.addComponent(bouncer, engine.TransformComp, .{
        .position = .{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .scale = 1.0,
    });
    try game.addComponent(bouncer, engine.Velocity, .{
        .linear = .{ .x = 5.0, .y = 3.0 },
        .angular = 0.0,
    });
    try game.addComponent(bouncer, engine.Sprite, .{
        .shape = .{ .Circle = game.create(engine.Circle, .{
            engine.V2{ .x = 0.0, .y = 0.0 },
            2.0,
            engine.Colors.NEON_GREEN,
            engine.Colors.WHITE,
        }) },
        .color = engine.Colors.NEON_GREEN,
        .visible = true,
    });
    try game.addComponent(bouncer, engine.ScreenClamp, .{});

    // Create wrapping rectangle (wraps around screen)
    const wrapper = try game.createEntity();
    try game.addComponent(wrapper, engine.TransformComp, .{
        .position = .{ .x = -5.0, .y = -5.0 },
        .rotation = 0.0,
        .scale = 1.0,
    });
    try game.addComponent(wrapper, engine.Velocity, .{
        .linear = .{ .x = 2.0, .y = 1.5 },
        .angular = 1.0, // Rotate while moving
    });
    try game.addComponent(wrapper, engine.Sprite, .{
        .shape = .{ .Rectangle = game.create(engine.Rectangle, .{
            0.0,
            0.0,
            3.0,
            2.0,
            engine.Colors.NEON_PURPLE,
            engine.Colors.WHITE,
        }) },
        .color = engine.Colors.NEON_PURPLE,
        .visible = true,
    });
    try game.addComponent(wrapper, engine.ScreenWrap, .{});

    // Create static triangle
    const static_tri = try game.createEntity();
    try game.addComponent(static_tri, engine.TransformComp, .{
        .position = .{ .x = 0.0, .y = 5.0 },
        .rotation = 0.0,
        .scale = 1.0,
    });
    try game.addComponent(static_tri, engine.Sprite, .{
        .shape = .{ .Triangle = game.create(engine.Triangle, .{
            &[3]engine.V2{
                .{ .x = 0.0, .y = 1.0 },
                .{ .x = -1.0, .y = -1.0 },
                .{ .x = 1.0, .y = -1.0 },
            },
            engine.Colors.BLUE,
            engine.Colors.WHITE,
        }) },
        .color = engine.Colors.BLUE,
        .visible = true,
    });
    try game.addComponent(static_tri, engine.Lifetime, .{ .remaining = 2 });

    // Create text entity
    if (font) |_| {
        const text_entity = try game.createEntity();
        try game.addComponent(text_entity, engine.TransformComp, .{
            .position = .{ .x = game.getLeftEdge() + 0.5, .y = game.getTopEdge() - 1.0 },
            .rotation = 0.0,
            .scale = 1.0,
        });
        try game.addComponent(text_entity, engine.Text, .{
            .text = "ECS DEMO - Bouncing & Wrapping",
            .font = font_handle,
            .scale = 0.5,
            .color = engine.Colors.NEON_ORANGE,
        });
    }

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
                .shape = .{ .Circle = game.create(engine.Circle, .{
                    engine.V2{ .x = 0.0, .y = 0.0 },
                    1.0,
                    engine.Colors.NEON_PINK,
                    engine.Colors.WHITE,
                }) },
                .color = engine.Colors.NEON_PINK,
                .visible = true,
            });
            try game.addComponent(test_circle, engine.Lifetime, .{ .remaining = 0.5 });
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
            try game.addComponent(test_tri, engine.Sprite, .{
                .shape = .{ .Triangle = game.create(engine.Triangle, .{
                    &[3]engine.V2{
                        .{ .x = 3.0, .y = 1.0 },
                        .{ .x = 1.0, .y = 1.0 },
                        .{ .x = -1.0, .y = -1.0 },
                    },
                    engine.Colors.BLUE,
                    engine.Colors.WHITE,
                }) },
                .color = engine.Colors.BLUE,
                .visible = true,
            });
            try game.addComponent(test_tri, engine.Lifetime, .{ .remaining = 2 });
        }
        game.update(dt);
        game.render();

        try game.endFrame();
    }
}
