const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Constraints = l_out.Constraints;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");
const log = @import("debug").log;

const Self = @This();

child: *WidgetNode,
background: Color,
border_color: ?Color,
border_width: f32,
padding: EdgeInsets,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const child_constraints = li.constraints.deflate(self.padding);
    const child_origin_x = li.pos.x + self.padding.left;
    const child_origin_y = li.pos.y + self.padding.top;
    const child_size = self.child.layout(.{
        .constraints = child_constraints,
        .pos = .{ .x = child_origin_x, .y = child_origin_y },
        .font = li.font,
    });

    const size: Size = .{
        .width = child_size.width + self.padding.horizontal(),
        .height = child_size.height + self.padding.vertical(),
    };

    return size.constrain(li.constraints);
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        return;
    const bounds = ri.bounds;
    const bg_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            bounds.height,
        ),
    );
    ri.renderer.drawGeometry(
        bg_shape,
        null,
        self.background,
        self.border_color,
        self.border_width,
        ri.ctx,
    );

    self.child.render(.{
        .renderer = ri.renderer,
        .ctx = ri.ctx,
        .font = ri.font,
        .bounds = self.child.bounds,
    });
}
