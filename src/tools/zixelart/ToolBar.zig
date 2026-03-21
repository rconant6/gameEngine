const std = @import("std");
const rend = @import("renderer");
const Colors = rend.Colors;
const color_gen = rend.Generator;
const ZixelState = @import("ZixelState.zig");
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;

pub fn buildTree(
    arena: std.mem.Allocator,
    raw_state: ?*const anyopaque,
) *WidgetNode {
    const state: *const ZixelState = @ptrCast(@alignCast(raw_state.?)); // TODO: smarter handling
    const tool = state.active_tool;
    return make.panel(
        arena,
        make.vstack(arena, &.{
            make.chicklet(arena, "ck_pencil", .{
                .colors = .{
                    .not_selected = color_gen.darken(Colors.PENCIL_YELLOW, 0.25),
                    .selected = Colors.PENCIL_YELLOW,
                },
                .size = .{ .x = 150, .y = 150 },
                .is_selected = tool == .pencil,
            }),
            make.chicklet(arena, "ck_eraser", .{
                .colors = .{
                    .not_selected = color_gen.darken(Colors.PASTEL_PINK, 0.25),
                    .selected = Colors.TULIP_PINK,
                },
                .size = .{ .x = 150, .y = 150 },
                .is_selected = tool == .erase,
            }),
            make.chicklet(arena, "ck_fill", .{
                .colors = .{
                    .not_selected = color_gen.darken(Colors.OCEAN_SHALLOW, 0.25),
                    .selected = Colors.OCEAN_SHALLOW,
                },
                .size = .{ .x = 150, .y = 150 },
                .is_selected = tool == .fill,
            }),
            make.chicklet(arena, "ck_line", .{
                .colors = .{
                    .not_selected = color_gen.darken(Colors.EMERALD, 0.25),
                    .selected = Colors.EMERALD,
                },
                .size = .{ .x = 150, .y = 150 },
                .is_selected = tool == .line,
            }),
            make.chicklet(arena, "ck_picker", .{
                .colors = .{
                    .not_selected = color_gen.darken(Colors.LAVENDER_FLOWER, 0.25),
                    .selected = Colors.LAVENDER_FLOWER,
                },
                .size = .{ .x = 150, .y = 150 },
                .is_selected = tool == .picker,
            }),
            make.spacer(arena, null),
        }, .{ .spacing = 30 }),
        .{
            .border_color = Colors.CHARCOAL,
            .border_width = 0,
            .padding = ui.EdgeInsets.symmetric(10, 2),
        },
    );
}
