const std = @import("std");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const rend = @import("renderer");
const Colors = rend.Colors;

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    _ = raw_state;

    return make.panel(arena, make.vstack(arena, &.{
        // RGB Sliders
        make.hstack(arena, &.{
            make.label(arena, "R", .{ .font_scale = 20.0, .color = Colors.RED }),
            make.slider(arena, "slider_r", .{ .fill_color = Colors.RED }),
        }, .{ .spacing = 10 }),
        make.hstack(arena, &.{
            make.label(arena, "G", .{ .font_scale = 20.0, .color = Colors.GREEN }),
            make.slider(arena, "slider_g", .{ .fill_color = Colors.GREEN }),
        }, .{ .spacing = 10 }),
        make.hstack(arena, &.{
            make.label(arena, "B", .{ .font_scale = 20.0, .color = Colors.BLUE }),
            make.slider(arena, "slider_b", .{ .fill_color = Colors.BLUE }),
        }, .{ .spacing = 10 }),

        // HSV Sliders
        make.hstack(arena, &.{
            make.label(arena, "H", .{ .font_scale = 20.0, .color = Colors.BLACK }),
            make.slider(arena, "slider_h", .{}),
        }, .{ .spacing = 10 }),
        make.hstack(arena, &.{
            make.label(arena, "S", .{ .font_scale = 20.0, .color = Colors.BLACK }),
            make.slider(arena, "slider_s", .{}),
        }, .{ .spacing = 10 }),
        make.hstack(arena, &.{
            make.label(arena, "V", .{ .font_scale = 20.0, .color = Colors.BLACK }),
            make.slider(arena, "slider_v", .{}),
        }, .{ .spacing = 10 }),
    }, .{ .spacing = 6 }), .{
        .background = Colors.LIGHT_GRAY,
        .padding = ui.EdgeInsets.all(12),
    });
}
