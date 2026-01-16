const Self = @This();
const core = @import("core");
const WorldPoint = core.WorldPoint;
const Box = @import("Components.zig").Box;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Rect = rend.Shapes.Rectangle;

position: WorldPoint,
ortho_size: f32, // vertical half_height in WORLDSPACE
viewport: Rect,
priority: i32,
rotation: f32 = 0,
background: ?Color = Colors.CLEAR,
