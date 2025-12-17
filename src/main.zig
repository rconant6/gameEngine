const std = @import("std");
const engine = @import("api");
const ecs = @import("entity");
const rend = @import("renderer");
const Shape = rend.Shape;

const logical_width = 800 * 2;
const logical_height = 600 * 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var game = engine.Engine.init(
        gpa.allocator(),
        "My Game",
        logical_width,
        logical_height,
    ) catch |err| {
        std.debug.print("[MAIN] engine failed to initialize: {any}", .{err});
        std.process.exit(2);
    };
    defer game.deinit();

    // MARK: Renderer testing
    const test_circle = game.create(engine.Circle, .{
        game.getCenter(),
        2.0,
        engine.Colors.RED,
        engine.Colors.WHITE,
    });

    const test_line = game.create(engine.Line, .{
        game.getTopLeft(),
        game.getBottomRight(),
        engine.Colors.RED,
    });

    const test_tri = game.create(engine.Triangle, .{
        &[3]engine.V2{
            .{ .x = 0.0, .y = 5.0 },
            .{ .x = -5.0, .y = -5.0 },
            .{ .x = 5.0, .y = -5.0 },
        },
        engine.Colors.BLUE,
        engine.Colors.WHITE,
    });

    const test_rect = game.create(engine.Rectangle, .{
        3,
        2,
        6,
        4,
        engine.Colors.NEON_GREEN,
        engine.Colors.WHITE,
    });

    const points = &[_]engine.V2{
        .{ .x = 0.0, .y = 2.0 },
        .{ .x = 1.7, .y = 1.0 },
        .{ .x = 1.7, .y = -1.0 },
        .{ .x = 0.0, .y = -2.0 },
        .{ .x = -1.7, .y = -1.0 },
        .{ .x = -1.7, .y = 1.0 },
    };
    const purple_poly = game.create(engine.Polygon, .{
        points,
        engine.Colors.NEON_PURPLE,
        engine.Colors.WHITE,
    });

    // MARK: Font Testing
    _ = try game.assets.fonts.setFontPath("assets/fonts");
    const font_handle = try game.assets.fonts.loadFont("Orbitron.ttf");
    const font_handle2 = try game.assets.fonts.loadFont("arcadeFont.ttf");
    std.log.info("Same handle? {}", .{font_handle.id == font_handle2.id});
    const font = game.assets.fonts.getFont(font_handle);

    while (!game.shouldClose()) {
        try game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);
        game.draw(test_line, null);
        game.draw(test_tri, null);
        game.draw(test_rect, null);
        game.draw(purple_poly, null);
        game.draw(test_circle, .{ .offset = .{ .x = 0, .y = -3 } });

        if (font) |f| {
            game.renderer.drawText(
                f,
                "THE QUICK BROWN FOX JUMPED OVER A SLEEPING DOG 1234567890",
                .{ .x = game.getLeftEdge() + 0.1, .y = 8.0 },
                0.65,
                engine.Colors.NEON_ORANGE,
            );
        }
        try game.endFrame();
    }
}
