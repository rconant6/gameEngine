const Canvas = @import("../Canvas.zig");
const ToolFns = @import("../ToolFns.zig").ToolFns;
const rend = @import("renderer");
const Color = rend.Color;
const cmds = @import("../commands.zig");
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
    _ = canvas;
    _ = x;
    _ = y;
    _ = color;
}

fn update(canvas: *Canvas, x: usize, y: usize, color: Color) void {
    _ = canvas;
    _ = x;
    _ = y;
    _ = color;
}

fn commit(canvas: *Canvas) ?ToolCommand {
    _ = canvas;
    return null;
}

fn preview(canvas: *Canvas, ctx: rend.RenderContext) void {
    _ = canvas;
    _ = ctx;
}

fn cancel(canvas: *Canvas) void {
    _ = canvas;
}
