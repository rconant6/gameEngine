const std = @import("std");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const Colors = @import("renderer").Colors;
const EditorState = @import("EditorState.zig");

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const EditorState = @ptrCast(@alignCast(raw_state));
    _ = state;

    return make.colorRect(arena, Colors.RED, .{
        .border_color = Colors.BLACK,
        .border_width = 2,
    });
}
