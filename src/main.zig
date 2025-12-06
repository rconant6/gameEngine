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
    const points = [_]engine.V2{
        .{ .x = 0.0, .y = 2.0 },
        .{ .x = 1.7, .y = 1.0 },
        .{ .x = 1.7, .y = -1.0 },
        .{ .x = 0.0, .y = -2.0 },
        .{ .x = -1.7, .y = -1.0 },
        .{ .x = -1.7, .y = 1.0 },
    };
    var purple_poly = try engine.Polygon.init(gpa.allocator(), &points); // TODO: update this init w/ wrapper
    errdefer purple_poly.deinit(gpa.allocator());
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
            // Draw 'E' at center
            drawGlyph(&game, f, 'E', 5.0, .{ .x = 0, .y = 5 }, engine.Colors.NEON_BLUE);

            // Draw other letters for testing
            drawGlyph(&game, f, 'A', 3.0, .{ .x = -5, .y = 6 }, engine.Colors.WHITE);
            drawGlyph(&game, f, 'B', 3.0, .{ .x = 5, .y = 6 }, engine.Colors.WHITE);
        }
        try game.endFrame();
    }
}
fn drawGlyph(
    game: *engine.Engine,
    font: *const engine.Font,
    char: u32,
    scale: f32,
    pos: engine.V2,
    color: engine.Color,
) void {
    // Look up glyph
    const glyph_index = font.char_to_glyph.get(char) orelse return;
    const glyph = font.glyph_shapes.get(glyph_index) orelse return;

    // Draw each contour
    var start_idx: usize = 0;
    for (glyph.contour_ends) |end_idx| {
        const contour_points = glyph.points[start_idx .. end_idx + 1];

        // Draw lines connecting points in this contour
        for (contour_points, 0..) |point, i| {
            const next_point = if (i == contour_points.len - 1)
                contour_points[0] // Close the loop
            else
                contour_points[i + 1];

            // Transform from normalized [0,1] to game space
            const p1 = engine.V2{
                .x = point.x * scale + pos.x,
                .y = point.y * scale + pos.y,
            };
            const p2 = engine.V2{
                .x = next_point.x * scale + pos.x,
                .y = next_point.y * scale + pos.y,
            };

            // Draw line
            game.renderer.drawShape(.{ .Line = .{
                .start = p1,
                .end = p2,
                .color = color,
            } }, null);
        }

        start_idx = end_idx + 1;
    }
}
