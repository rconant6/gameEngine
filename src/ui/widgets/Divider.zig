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

size: f32 = 2,
color: Color = Colors.RED,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    _ = origin_x;
    _ = origin_y;

    const size: Size = .{
        .width = self.size,
        .height = constraints.max_height,
    };

    return size.constrain(constraints);
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    _ = font;
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        return;
    const bg_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            2,
        ),
    );
    renderer.drawGeometry(
        bg_shape,
        null,
        self.color,
        null,
        1,
        ctx,
    );
}
