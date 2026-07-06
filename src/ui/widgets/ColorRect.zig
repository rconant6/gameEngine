const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const Colors = rend.Colors;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

color: Color,
border_color: ?Color = null,
border_width: f32 = 0,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    _ = self;
    return .{
        .width = li.constraints.max_width,
        .height = li.constraints.max_height,
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const Rectangle = rend.ShapeRegistry.getShapeType("Rectangle") orelse
        return;
    const bounds = ri.bounds;
    const shape = rend.ShapeRegistry.createShapeUnion(
        Rectangle,
        Rectangle.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            bounds.height,
        ),
    );
    ri.renderer.render(.{
        .shape = shape,
        .style = .{
            .fill = self.color,
            .stroke = self.border_color,
            .stroke_width = self.border_width,
        },
        .space = .screen,
    }, ri.ctx);
}
