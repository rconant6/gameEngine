const std = @import("std");
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
const Alignment = @import("../alignment.zig").Alignment;
const WidgetNode = @import("WidgetNode.zig");

const Self = @This();

children: []WidgetNode,
spacing: f32,
cross_axis: Alignment.Horizontal,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    var cursor_y = origin_y;
    var max_width: f32 = 0;
    var remaining_height = constraints.max_height;

    for (self.children, 0..) |*child, i| {
        const child_constraints = Constraints.loose(
            constraints.max_width,
            remaining_height,
        );
        const child_size = child.layout(child_constraints, origin_x, cursor_y);
        max_width = @max(max_width, child_size.width);
        cursor_y += child_size.height;
        remaining_height -= child_size.height;
        if (i < self.children.len - 1) {
            cursor_y += self.spacing;
            remaining_height -= self.spacing;
        }
    }

    const stack_width = max_width;
    for (self.children) |*child| {
        const child_height = child.bounds.height;
        child.bounds.x = switch (self.cross_axis) {
            .start => origin_x,
            .end => origin_x + stack_width - child_height,
            .center => origin_x + (stack_width - child_height) / 2,
            .stretch => origin_x,
        };
    }
    const total_height = cursor_y - origin_y;

    return .{
        .width = max_width,
        .height = total_height,
    };
}
pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    _ = bounds;
    for (self.children) |*child| {
        child.render(renderer, font, ctx);
    }
}
