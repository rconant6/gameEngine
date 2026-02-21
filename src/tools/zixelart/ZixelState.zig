const std = @import("std");
const Self = @This();

const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;

const Canvas = @import("Canvas.zig");
const Tool = @import("tool.zig").Tool;

canvas: *Canvas,
bg_color: Color = Colors.LIGHT_GRAY,

active_color: Color = Colors.MAGENTA,
active_color_name: []const u8,

active_tool: Tool,

cursor_x: ?usize = null,
cursor_y: ?usize = null,
