const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

child: *WidgetNode,
background: Color,
border_color: ?Color,
border_width: f32,
padding: EdgeInsets,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    const child_constraints = constraints.deflate(self.padding);
    const child_origin_x = origin_x + self.padding.left;
    const child_origin_y = origin_y + self.padding.top;
    const child_size = self.child.layout(child_constraints, child_origin_x, child_origin_y);

    const size: Size = .{
        .width = child_size.width + self.padding.horizontal(),
        .height = child_size.height + self.padding.vertical(),
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
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        return;
    const bg_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            bounds.height,
        ),
    );
    renderer.drawGeometry(
        bg_shape,
        null,
        self.background,
        self.border_color,
        self.border_width,
        ctx,
    );

    self.child.render(renderer, font, ctx);
}
