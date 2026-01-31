const std = @import("std");
const rend = @import("renderer");
const ShapeData = rend.ShapeData;
const Color = rend.Color;
const Colors = rend.Colors;
const plat = @import("platform");
const App = @import("app").App;
const Canvas = @import("Canvas.zig");
const PixelCell = Canvas.PixelCell;
const debug = @import("debug");
const log = debug.log;
const ZixelState = @import("ZixelState.zig");

const logical_width = 1024;
const logical_height = 768;
const canvas_width = 64;
const canvas_height = 64;
const pixelsize: usize = logical_height / canvas_height;
const offset_x = (logical_width - logical_height) / 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.init(allocator, .{
        .title = "Zixel Art",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const kb = plat.getKeyboard();
    const mouse = plat.getMouse();

    // Build canvas grid
    const canvas = Canvas.init(allocator, logical_width, logical_height, 64) catch |err| {
        log.err(
            .application,
            "Unable to create Canvas of {d}x{d}: {any}",
            .{ canvas_width, canvas_height, err },
        );
        @panic("Cannot create a canvas");
    };
    log.info(.application, "Created canvas of {d}x{d}", .{ 64, 64 });
    defer canvas.deinit();

    const state: ZixelState = .{
        .canvas = canvas,
        .active_color = Colors.WHITE,
    };

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
        if (kb.isPressed(.C)) canvas.clear();
        if (mouse.buttons.isPressed(.Left)) {
            const screen_x: usize = @intFromFloat(mouse.position.x);
            const raw_y: usize = @intFromFloat(mouse.position.y);
            const screen_y: usize = logical_height - 1 - raw_y;

            if (screenToCanvas(state.canvas, screen_x, screen_y)) |pos| {
                canvas.setPixel(pos.x, pos.y, state.active_color);
            } else {
                log.debug(.application, "Clicked outside canvas: {d}, {d}", .{ screen_x, screen_y });
            }
        }

        for (state.canvas.pixels) |cell| {
            app.renderer.drawGeometry(
                cell.shape,
                null,
                cell.color,
                Colors.BLACK,
                1.0,
                ctx,
            );
        }
        try app.endFrame();
    }
}

pub fn screenToCanvas(self: *const Canvas, screen_x: usize, screen_y: usize) ?struct { x: usize, y: usize } {
    if (screen_x < self.x_offset) return null;
    const adjusted_x = screen_x - self.x_offset;

    const canvas_x = adjusted_x / self.pixel_size;
    const canvas_y = screen_y / self.pixel_size;

    if (canvas_x >= self.pixel_count or canvas_y >= self.pixel_count) return null;

    return .{ .x = canvas_x, .y = canvas_y };
}
