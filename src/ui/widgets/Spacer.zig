const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const Colors = rend.Colors;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

min_size: ?f32,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    _ = self;
    _ = origin_x;
    _ = origin_y;

    const size: Size = .{ .width = 0, .height = 0 };

    return size.constrain(constraints);
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    _ = self;
    _ = renderer;
    _ = font;
    _ = bounds;
    _ = ctx;
    return;
}
