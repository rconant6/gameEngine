const Canvas = @import("../Canvas.zig");
const ToolFns = @import("../ToolFns.zig").ToolFns;
const rend = @import("renderer");
const Color = rend.Color;
const cmds = @import("../commands.zig");
const ToolCommand = cmds.ToolCommand;
const PixelChange = cmds.PixelChange;

const self = @This();

pub fn fns() ToolFns {
    return .{
        .beginFn = begin,
        .updateFn = update,
        .cancelFn = cancel,
        .commitFn = commit,
        .previewFn = preview,
    };
}

fn begin(canvas: *Canvas, x: usize, y: usize, color: Color) void {
    const idx = y * canvas.pixel_count + x;
    const old_color = canvas.pixels[idx].color;
    canvas.pixels[idx].color = color;

    canvas.changes.append(canvas.allocator, PixelChange{
        .x = x,
        .y = y,
        .old_color = old_color,
        .new_color = color,
    }) catch return;
}

fn update(canvas: *Canvas, x: usize, y: usize, color: Color) void {
    if (canvas.changes.items.len == 0) return;
    // Store the starting point
    const start_x = canvas.changes.items[0].x;
    const start_y = canvas.changes.items[0].y;

    // Clear the old line
    for (canvas.changes.items) |change| {
        const idx = change.y * canvas.pixel_count + change.x;
        canvas.pixels[idx].color = change.old_color orelse canvas.blank_color;
    }
    canvas.changes.clearRetainingCapacity();

    // Bresenham from (start_x, start_y) to (x, y)
    const isx: isize = @intCast(start_x);
    const isy: isize = @intCast(start_y);
    const ix: isize = @intCast(x);
    const iy: isize = @intCast(y);

    const delta_x = @as(isize, @intCast(@abs(ix - isx)));
    const delta_y = -@as(isize, @intCast(@abs(iy - isy)));

    const slope_x: isize = if (isx < ix) 1 else -1;
    const slope_y: isize = if (isy < iy) 1 else -1;

    var err: isize = delta_x + delta_y;
    var cx: isize = isx;
    var cy: isize = isy;

    while (true) {
        const ux: usize = @intCast(cx);
        const uy: usize = @intCast(cy);
        const idx = uy * canvas.pixel_count + ux;
        const old_color = canvas.pixels[idx].color;
        canvas.pixels[idx].color = color;

        canvas.changes.append(canvas.allocator, PixelChange{
            .x = ux,
            .y = uy,
            .old_color = old_color,
            .new_color = color,
        }) catch return;

        if (cx == ix and cy == iy) break;
        const e2 = 2 * err;
        if (e2 >= delta_y) {
            err += delta_y;
            cx += slope_x;
        }
        if (e2 <= delta_x) {
            err += delta_x;
            cy += slope_y;
        }
    }
}

fn commit(canvas: *Canvas) ?ToolCommand {
    if (canvas.changes.items.len == 0) return null;

    const pixels = canvas.allocator.dupe(
        PixelChange,
        canvas.changes.items,
    ) catch return null;
    canvas.changes.clearRetainingCapacity();

    return ToolCommand{
        .kind = .line,
        .pixels = pixels,
    };
}

fn preview(canvas: *Canvas, ctx: rend.RenderContext) void {
    _ = canvas;
    _ = ctx;
}

fn cancel(canvas: *Canvas) void {
    canvas.cancel();
    canvas.changes.clearRetainingCapacity();
}
