const std = @import("std");
const engine = @import("api");
const ecs = @import("entity");
const rend = @import("renderer");
const Shape = rend.Shape;

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
    purple_poly.fill_color = engine.Colors.NEON_PURPLE;
    purple_poly.outline_color = engine.Colors.WHITE;

    var shapes = try ecs.ComponentStorage(Shape).init(gpa.allocator());
    defer shapes.deinit();

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
        try game.endFrame();
    }
}
