const std = @import("std");
const engine = @import("api");

const logical_width = 800;
const logical_height = 600;

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
    const test_circle = engine.Circle{
        .origin = game.getCenter(),
        .radius = 2.0,
        .fill_color = engine.Colors.RED,
        .outline_color = engine.Colors.WHITE,
    };

    const test_line = engine.Line{
        .start = game.getTopLeft(),
        .end = game.getBottomRight(),
        .color = engine.Colors.RED,
    };
    const test_tri = engine.Triangle{
        .vertices = [3]engine.V2{
            .{ .x = 0.0, .y = 5.0 },
            .{ .x = -5.0, .y = -5.0 },
            .{ .x = 5.0, .y = -5.0 },
        },
        .fill_color = engine.Colors.BLUE,
        .outline_color = engine.Colors.WHITE,
    };
    const test_rect = engine.Rectangle{
        .center = .{ .x = 0.0, .y = 0.0 },
        .half_width = 3.0,
        .half_height = 2.0,
        .fill_color = engine.Colors.ORANGE,
        .outline_color = engine.Colors.WHITE,
    };
    const points = try gpa.allocator().alloc(engine.V2, 6);
    points[0] = .{ .x = 0.0, .y = 2.0 };
    points[1] = .{ .x = 1.7, .y = 1.0 };
    points[2] = .{ .x = 1.7, .y = -1.0 };
    points[3] = .{ .x = 0.0, .y = -2.0 };
    points[4] = .{ .x = -1.7, .y = -1.0 };
    points[5] = .{ .x = -1.7, .y = 1.0 };
    errdefer gpa.allocator().free(points);
    // TODO: wrapper api update
    var purple_poly = try engine.Polygon.init(gpa.allocator(), points);
    defer purple_poly.deinit();
    purple_poly.fill_color = engine.Colors.NEON_PURPLE;
    purple_poly.outline_color = engine.Colors.WHITE;

    // MARK: Font Testing
    _ = try game.assets.fonts.setFontPath("assets/fonts");
    const font_handle = try game.assets.fonts.loadFont("Orbitron.ttf");
    const font_handle2 = try game.assets.fonts.loadFont("arcadeFont.ttf");
    std.log.info("Same handle? {}", .{font_handle.id == font_handle2.id});
    const font = game.assets.fonts.getFont(font_handle);

    while (!game.shouldClose()) {
        try game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);
        game.renderer.drawShape(.{ .Line = test_line }, null);
        game.renderer.drawShape(.{ .Triangle = test_tri }, null);
        game.renderer.drawShape(.{ .Rectangle = test_rect }, null);
        game.renderer.drawShape(.{ .Polygon = purple_poly }, null);
        game.renderer.drawShape(.{ .Circle = test_circle }, .{
            .offset = .{ .x = 0, .y = -3 },
        });
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
