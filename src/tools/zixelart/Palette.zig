const std = @import("std");
const Self = @This();
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const make = ui.make;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Library = rend.ColorLibrary;
const ZixelState = @import("ZixelState.zig");
const gen = rend.Generator;
const log = @import("debug").log;

pub const palette_size = 64;
const cols = 8;
const rows = 8;

// BASE palette: 8 hue columns × 8 shades, bright (row 0) to dark (row 7)
// Columns: Red, Orange, Yellow, Green, Cyan, Blue, Purple, Gray
pub const colors = [palette_size]Color{
    // Row 0: Brightest
    Colors.BASE_RED_1,  Colors.BASE_ORANGE_1, Colors.BASE_YELLOW_1, Colors.BASE_GREEN_1,
    Colors.BASE_CYAN_1, Colors.BASE_BLUE_1,   Colors.BASE_PURPLE_1, Colors.BASE_GRAY_1,
    // Row 1
    Colors.BASE_RED_2,  Colors.BASE_ORANGE_2, Colors.BASE_YELLOW_2, Colors.BASE_GREEN_2,
    Colors.BASE_CYAN_2, Colors.BASE_BLUE_2,   Colors.BASE_PURPLE_2, Colors.BASE_GRAY_2,
    // Row 2
    Colors.BASE_RED_3,  Colors.BASE_ORANGE_3, Colors.BASE_YELLOW_3, Colors.BASE_GREEN_3,
    Colors.BASE_CYAN_3, Colors.BASE_BLUE_3,   Colors.BASE_PURPLE_3, Colors.BASE_GRAY_3,
    // Row 3
    Colors.BASE_RED_4,  Colors.BASE_ORANGE_4, Colors.BASE_YELLOW_4, Colors.BASE_GREEN_4,
    Colors.BASE_CYAN_4, Colors.BASE_BLUE_4,   Colors.BASE_PURPLE_4, Colors.BASE_GRAY_4,
    // Row 4
    Colors.BASE_RED_5,  Colors.BASE_ORANGE_5, Colors.BASE_YELLOW_5, Colors.BASE_GREEN_5,
    Colors.BASE_CYAN_5, Colors.BASE_BLUE_5,   Colors.BASE_PURPLE_5, Colors.BASE_GRAY_5,
    // Row 5
    Colors.BASE_RED_6,  Colors.BASE_ORANGE_6, Colors.BASE_YELLOW_6, Colors.BASE_GREEN_6,
    Colors.BASE_CYAN_6, Colors.BASE_BLUE_6,   Colors.BASE_PURPLE_6, Colors.BASE_GRAY_6,
    // Row 6
    Colors.BASE_RED_7,  Colors.BASE_ORANGE_7, Colors.BASE_YELLOW_7, Colors.BASE_GREEN_7,
    Colors.BASE_CYAN_7, Colors.BASE_BLUE_7,   Colors.BASE_PURPLE_7, Colors.BASE_GRAY_7,
    // Row 7: Darkest
    Colors.BASE_RED_8,  Colors.BASE_ORANGE_8, Colors.BASE_YELLOW_8, Colors.BASE_GREEN_8,
    Colors.BASE_CYAN_8, Colors.BASE_BLUE_8,   Colors.BASE_PURPLE_8, Colors.BASE_GRAY_8,
};

pub const color_ids = blk: {
    @setEvalBranchQuota(20000);
    var ids: [palette_size][]const u8 = undefined;
    for (0..palette_size) |i| {
        ids[i] = std.fmt.comptimePrint("pal_{d:0>2}", .{i});
    }
    break :blk ids;
};

const swatch_size = 32;

pub fn buildTree(
    arena: std.mem.Allocator,
    state: *const ZixelState,
) *WidgetNode {
    _ = state;
    const chicklets = arena.alloc(*WidgetNode, palette_size) catch |err| {
        log.fatal(
            .application,
            "Unable to allocate palette chicklets {any}",
            .{err},
        );
        @panic("system memory failure");
    };

    for (0..palette_size) |idx| {
        chicklets[idx] = make.chicklet(arena, color_ids[idx], .{
            .colors = .{
                .selected = colors[idx],
                .not_selected = colors[idx],
            },
            .is_selected = false,
            .size = .{ .x = swatch_size, .y = swatch_size },
        });
    }
    const grid = make.grid(arena, chicklets[0..], .{ .columns = cols, .h_spacing = 2, .v_spacing = 2 });

    return make.panel(arena, grid, .{
        .background = Colors.CHARCOAL,
        .padding = .all(10),
    });
}
