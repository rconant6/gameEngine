const std = @import("std");
const Self = @This();

const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;

const Canvas = @import("Canvas.zig");

canvas: *Canvas,
active_color: Color = Colors.MAGENTA,
