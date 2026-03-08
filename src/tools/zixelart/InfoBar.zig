const std = @import("std");
const rend = @import("renderer");
const Colors = rend.Colors;
const Color = rend.Color;
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const assets = @import("assets");
const Font = assets.Font;
const ZixelState = @import("ZixelState.zig");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const widgets = ui.Widgets;
const Label = widgets.Label;
const HStack = widgets.HStack;
const Panel = widgets.Panel;

pub fn buildTree(
    arena: std.mem.Allocator,
    font: *const Font,
    state: *const ZixelState,
    buf: *[256]u8,
) !*WidgetNode {
    const text_scale: f32 = 24.0;

    // Build label nodes: tool, color name, canvas size, zoom, cursor coords
    var labels = try arena.alloc(WidgetNode, 5);

    labels[0] = .{
        .widget = .{ .Label = .{
            .text = std.ascii.upperString(buf[0..64], @tagName(state.active_tool)),
            .font = font,
            .font_scale = text_scale,
            .color = Colors.UI_BUTTON_TEXT,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    labels[1] = .{
        .widget = .{ .Label = .{
            .text = std.ascii.lowerString(buf[64..128], state.active_color_name),
            .font = font,
            .font_scale = text_scale,
            .color = Colors.UI_BUTTON_TEXT,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    labels[2] = .{
        .widget = .{ .Label = .{
            .text = "64x64",
            .font = font,
            .font_scale = text_scale,
            .color = Colors.UI_TEXT_INFO,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    labels[3] = .{
        .widget = .{ .Label = .{
            .text = "100%",
            .font = font,
            .font_scale = text_scale,
            .color = Colors.UI_BUTTON_NORMAL,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    const coord_text = std.fmt.bufPrint(
        buf[128..192],
        "[{d:3}, {d:3}]",
        .{ state.cursor_x orelse 0, state.cursor_y orelse 0 },
    ) catch "";
    labels[4] = .{
        .widget = .{ .Label = .{
            .text = coord_text,
            .font = font,
            .font_scale = text_scale,
            .color = Colors.UI_BUTTON_TEXT,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    // HStack: arrange labels horizontally
    const hstack = try arena.create(WidgetNode);
    hstack.* = .{
        .widget = .{ .HStack = .{
            .children = labels,
            .spacing = 30,
            .cross_axis = .center,
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    // Panel: charcoal background wrapping the hstack
    const panel = try arena.create(WidgetNode);
    panel.* = .{
        .widget = .{ .Panel = .{
            .child = hstack,
            .background = Colors.CHARCOAL,
            .border_color = null,
            .border_width = 0,
            .padding = ui.EdgeInsets.symmetric(10, 0),
        } },
        .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
    };

    return panel;
}
