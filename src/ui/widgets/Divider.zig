const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const Colors = rend.Colors;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

size: f32 = 2,
color: Color = Colors.RED,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const size: Size = .{
        .width = self.size,
        .height = li.constraints.max_height,
    };

    return size.constrain(li.constraints);
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const bounds = ri.bounds;
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
    ri.renderer.drawGeometry(
        bg_shape,
        null,
        self.color,
        null,
        1,
        ri.ctx,
    );
}
