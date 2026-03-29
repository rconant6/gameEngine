const Canvas = @import("../Canvas.zig");
const ToolFns = @import("../ToolFns.zig").ToolFns;
const rend = @import("renderer");
const Color = rend.Color;
const RenderContext = rend.RenderContext;
const cmds = @import("../commands.zig");
const PixelChange = cmds.PixelChange;
const ToolCommand = cmds.ToolCommand;

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
    // Skip if this pixel is already in the pending changes for this stroke
    for (canvas.changes.items) |change| {
        if (change.x == x and change.y == y) return;
    }
    // Same as begin otherwise
    begin(canvas, x, y, color);
}

fn commit(canvas: *Canvas) ?ToolCommand {
    if (canvas.changes.items.len == 0) return null;

    const pixels = canvas.allocator.dupe(PixelChange, canvas.changes.items) catch return null;
    canvas.changes.clearRetainingCapacity();

    return ToolCommand{
        .kind = .pencil,
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
