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
const Size = l_out.Size;
const Rect = @import("../Rect.zig");

const Axis = l_out.Axis;

const Self = @This();

axis: Axis = .horizontal,
size: f32 = 2,
color: Color = Colors.CHARCOAL,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    return switch (self.axis) {
        .horizontal => .{ .width = li.constraints.max_width, .height = self.size },
        .vertical => .{ .width = self.size, .height = li.constraints.max_height },
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const bounds = ri.bounds;
    const Rectangle = rend.ShapeRegistry.getShapeType("Rectangle") orelse return;
    const rect = switch (self.axis) {
        .horizontal => Rectangle.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            self.size,
        ),
        .vertical => Rectangle.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            self.size,
            bounds.height,
        ),
    };
    ri.renderer.render(.{
        .shape = rend.ShapeRegistry.createShapeUnion(Rectangle, rect),
        .style = .{ .fill = self.color },
        .space = .screen,
    }, ri.ctx);
}
