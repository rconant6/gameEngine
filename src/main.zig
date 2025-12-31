const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;

const Instantiator = @import("scene/instantiator.zig").Instantiator;
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

    // // Test SceneManager
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
                .component => |c| std.debug.print("  - Component: {s}\n", .{switch (c) {
                    .generic => |g| g.name,
                    .sprite => |s| s.name,
                }}),
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

    // Instantiate entities from the loaded scene
    var instantiator = Instantiator.init(allocator, &game);
    const scene_file = scene_manager.getActiveScene() orelse return error.SceneNotFound;
    try instantiator.instantiate(scene_file);

    // === Validation Tests ===
    std.debug.print("\n=== Scene Instantiation Validation ===\n", .{});

    var transform_count: usize = 0;
    var transform_query = game.world.query(.{engine.TransformComp});
    while (transform_query.next()) |entry| {
        const transform = entry.get(0);
        std.debug.print("  Entity {d} Transform: pos=({d:.2}, {d:.2}), rot={d:.2}, scale={d:.2}\n", .{
            entry.entity.id,
            transform.position.x,
            transform.position.y,
            transform.rotation,
            transform.scale,
        });
        transform_count += 1;
    }
    std.debug.print("✓ Entities with Transform: {d}\n", .{transform_count});

    var velocity_count: usize = 0;
    var velocity_query = game.world.query(.{engine.Velocity});
    while (velocity_query.next()) |entry| {
        const velocity = entry.get(0);
        std.debug.print("  Entity {d} Velocity: linear=({d:.2}, {d:.2}), angular={d:.2}\n", .{
            entry.entity.id,
            velocity.linear.x,
            velocity.linear.y,
            velocity.angular,
        });
        velocity_count += 1;
    }
    std.debug.print("✓ Entities with Velocity: {d}\n", .{velocity_count});

    var text_count: usize = 0;
    var text_query = game.world.query(.{engine.Text});
    while (text_query.next()) |entry| {
        const text = entry.get(0);
        const font = game.assets.getFont(text.font_asset);
        std.debug.print("  Entity {d} Text: \"{s}\", size={d:.2}, font_handle.id={d}, font={}\n", .{
            entry.entity.id,
            text.text,
            text.size,
            text.font_asset.id,
            font != null,
        });
        text_count += 1;
    }
    std.debug.print("✓ Entities with Text: {d}\n", .{text_count});

    var physics_count: usize = 0;
    var physics_query = game.world.query(.{engine.Physics});
    while (physics_query.next()) |entry| {
        const physics = entry.get(0);
        std.debug.print("  Entity {d} Physics: vel=({d:.2}, {d:.2}), mass={d:.2}, friction={d:.2}\n", .{
            entry.entity.id,
            physics.velocity.x,
            physics.velocity.y,
            physics.mass,
            physics.friction,
        });
        physics_count += 1;
    }
    std.debug.print("✓ Entities with Physics: {d}\n", .{physics_count});

    var box_count: usize = 0;
    var box_query = game.world.query(.{engine.Box});
    while (box_query.next()) |entry| {
        const box = entry.get(0);
        std.debug.print("  Entity {d} Box: size=({d:.2}, {d:.2}), filled={}\n", .{
            entry.entity.id,
            box.size.x,
            box.size.y,
            box.filled,
        });
        box_count += 1;
    }
    std.debug.print("✓ Entities with Box: {d}\n", .{box_count});

    var camera_count: usize = 0;
    var camera_query = game.world.query(.{engine.Camera});
    while (camera_query.next()) |entry| {
        const camera = entry.get(0);
        std.debug.print("  Entity {d} Camera: fov={d:.2}, near={d:.2}, far={d:.2}\n", .{
            entry.entity.id,
            camera.fov,
            camera.near,
            camera.far,
        });
        camera_count += 1;
    }
    std.debug.print("✓ Entities with Camera: {d}\n", .{camera_count});

    var lifetime_count: usize = 0;
    var lifetime_query = game.world.query(.{engine.Lifetime});
    while (lifetime_query.next()) |entry| {
        const lifetime = entry.get(0);
        std.debug.print("  Entity {d} Lifetime: remaining={d:.2}s\n", .{
            entry.entity.id,
            lifetime.remaining,
        });
        lifetime_count += 1;
    }
    std.debug.print("✓ Entities with Lifetime: {d}\n", .{lifetime_count});

    std.debug.print("\n=== Expected vs Actual ===\n", .{});
    std.debug.print("Expected ~9 entities (counting nested scenes)\n", .{});
    std.debug.print("Expected 2 Text entities (TitleText, ScoreText)\n", .{});
    std.debug.print("Expected 1 Physics entity (Player)\n", .{});
    std.debug.print("Expected 2 Box entities (Ground, HealthBar)\n", .{});
    std.debug.print("Expected 1 Camera entity\n", .{});
    std.debug.print("Expected 1 Lifetime entity (StaticTriangle)\n", .{});
    std.debug.print("====================================\n\n", .{});

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
