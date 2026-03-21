const std = @import("std");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const Colors = @import("renderer").Colors;
const ZixelState = @import("ZixelState.zig");

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const ZixelState = @alignCast(@ptrCast(raw_state));

    return make.colorRect(arena, state.active_color, .{
        .border_color = Colors.BLACK,
        .border_width = 2,
    });
}
