const std = @import("std");
const rend = @import("renderer");
const Colors = rend.Colors;
const ZixelState = @import("ZixelState.zig");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const ZixelState = @ptrCast(@alignCast(raw_state.?)); // TODO: smarter handling
    const text_scale: f32 = 24.0;

    const coord_text = std.fmt.bufPrint(
        state.buf[128..192],
        "[{d:3}, {d:3}]",
        .{ state.cursor_x orelse 0, state.cursor_y orelse 0 },
    ) catch "";

    return make.panel(
        arena,
        make.hstack(arena, &.{
            make.label(
                arena,
                std.ascii.upperString(state.buf[0..64], @tagName(state.active_tool)),
                .{ .font_scale = text_scale, .color = Colors.UI_BUTTON_TEXT },
            ),
            make.label(
                arena,
                std.ascii.upperString(state.buf[64..128], state.active_color_name),
                .{ .font_scale = text_scale, .color = state.active_color },
            ),
            make.hspacer(arena, null),
            make.label(
                arena,
                "64x64",
                .{ .font_scale = text_scale, .color = Colors.UI_TEXT_INFO },
            ),
            make.label(
                arena,
                "100%",
                .{ .font_scale = text_scale, .color = Colors.UI_BUTTON_NORMAL },
            ),
            make.hspacer(arena, null),
            make.label(
                arena,
                coord_text,
                .{ .font_scale = text_scale, .color = Colors.UI_BUTTON_TEXT },
            ),
        }, .{ .spacing = 40 }),
        .{
            .border_color = Colors.CHARCOAL,
            .border_width = 0,
            .padding = ui.EdgeInsets.symmetric(10, 10),
        },
    );
}
