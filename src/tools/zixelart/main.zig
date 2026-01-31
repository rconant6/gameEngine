const std = @import("std");
const rend = @import("renderer");
const ShapeData = rend.ShapeData;
const Color = rend.Color;
const Colors = rend.Colors;
const plat = @import("platform");
const App = @import("app").App;

const logical_width = 1024;
const logical_height = 768;

const canvas_width = 32;
const canvas_height = 32;
const pixelsize: usize = logical_height / canvas_height;
const offset_x = (logical_width - logical_height) / 2;
var even = true;
var canvas: [canvas_width][canvas_height]ShapeData = undefined;
var canvas_colors: [canvas_width][canvas_height]Color = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.init(allocator, .{
        .title = "ZIXELART",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const kb = plat.getKeyboard();

    // Build canvas grid
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        @panic("Wrong shape type");

    var i: usize = 0;
    var j: usize = 0;

    while (i < canvas_width) : (i += 1) {
        while (j < canvas_height) : (j += 1) {
            const loc_x = i * pixelsize + offset_x + pixelsize / 2;
            const loc_y = j * pixelsize + pixelsize / 2;
            canvas[i][j] = rend.ShapeRegistry.createShapeUnion(
                ScreenRect,
                ScreenRect.initSquare(
                    .{ .x = @intCast(loc_x), .y = @intCast(loc_y) },
                    @floatFromInt(pixelsize),
                ),
            );
            canvas_colors[i][j] = if (even) Colors.RED else Colors.BLACK;
            even = !even;
        }
        even = !even;
        j = 0;
    }

    const ctx: rend.RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    while (app.isRunning()) {
        try app.beginFrame();

        app.renderer.setClearColor(Colors.DARK_GRAY);
        app.renderer.clear();

        if (kb.isPressed(.Esc)) break;

        for (canvas[0..], 0..) |row, x| {
            for (row, 0..) |sq, y| {
                app.renderer.drawGeometry(
                    sq,
                    null,
                    canvas_colors[x][y],
                    null,
                    1.0,
                    ctx,
                );
            }
        }

        try app.endFrame();
    }
}
