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

    const player = engine.Circle{
        .origin = .{ .x = 0, .y = 0 },
        .radius = 0.5,
        .fill_color = engine.Colors.RED,
    };

    while (!game.shouldClose()) {
        try game.beginFrame();
        game.clear(engine.Colors.DARK_GRAY);
        game.drawCircle(player);
        try game.endFrame();
    }
}
