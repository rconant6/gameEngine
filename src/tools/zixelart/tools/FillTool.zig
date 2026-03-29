const std = @import("std");
const ArrayList = std.ArrayList;
const Canvas = @import("../Canvas.zig");
const ToolFns = @import("../ToolFns.zig").ToolFns;
const rend = @import("renderer");
const Color = rend.Color;
const cmds = @import("../commands.zig");
const ToolCommand = cmds.ToolCommand;
const PixelChange = cmds.PixelChange;
const log = @import("debug").log;

const V2Usize = packed struct {
    x: usize,
    y: usize,
};

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
    const curr_idx = y * canvas.pixel_count + x;
    const target_color = canvas.pixels[curr_idx].color;
    if (target_color.eql(color)) return;

    const gpa = canvas.allocator;

    var stack: ArrayList(V2Usize) =
        ArrayList(V2Usize).initCapacity(gpa, 1024) catch return;
    defer stack.deinit(canvas.allocator);

    stack.append(gpa, .{ .x = x, .y = y }) catch return;
    while (stack.items.len > 0) {
        const curr = stack.pop() orelse break;
        const idx = curr.y * canvas.pixel_count + curr.x;
        const curr_color = canvas.pixels[idx].color;
        if (!curr_color.eql(target_color)) continue;

        canvas.pixels[idx].color = color;
        canvas.changes.append(canvas.allocator, PixelChange{
            .x = curr.x,
            .y = curr.y,
            .old_color = curr_color,
            .new_color = color,
        }) catch return;

        // Push 4 neighbors
        if (curr.x > 0) stack.append(
            gpa,
            .{ .x = curr.x - 1, .y = curr.y },
        ) catch return;
        if (curr.x < canvas.pixel_count - 1) stack.append(
            gpa,
            .{ .x = curr.x + 1, .y = curr.y },
        ) catch return;
        if (curr.y > 0) stack.append(
            gpa,
            .{ .x = curr.x, .y = curr.y - 1 },
        ) catch return;
        if (curr.y < canvas.pixel_count - 1) stack.append(
            gpa,
            .{ .x = curr.x, .y = curr.y + 1 },
        ) catch return;
    }
}

fn update(canvas: *Canvas, x: usize, y: usize, color: Color) void {
    _ = canvas;
    _ = x;
    _ = y;
    _ = color;
}

fn commit(canvas: *Canvas) ?ToolCommand {
    if (canvas.changes.items.len == 0) return null;

    const pixels = canvas.allocator.dupe(
        PixelChange,
        canvas.changes.items,
    ) catch return null;
    canvas.changes.clearRetainingCapacity();

    return ToolCommand{
        .kind = .fill,
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
