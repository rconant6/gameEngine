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
columns: u8,
h_spacing: f32,
v_spacing: f32,
cross_axis: ?Alignment.Horizontal = null,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    const cols: usize = @intCast(self.columns);
    const rows = (self.children.len + cols - 1) / cols;
    var max_width: f32 = 0;
    var max_height: f32 = 0;

    // ── Pass 1: measure fixed children, get biggest cell size ──
    for (self.children) |*child| {
        const child_constraints = Constraints.loose(
            constraints.max_width,
            constraints.max_height,
        );
        const child_size = child.layout(child_constraints, 0, 0);
        max_width = @max(max_width, child_size.width);
        max_height = @max(max_height, child_size.height);
    }

    // ── Pass 2: assign positions left-to-right and top-to-bottom ──
    var cursor_y = origin_y;
    for (0..rows) |j| {
        var cursor_x = origin_x;
        for (0..cols) |col| {
            const index = j * cols + col;
            if (index >= self.children.len) break;
            _ = self.children[index].layout(
                .tight(max_width, max_height),
                cursor_x,
                cursor_y,
            );
            cursor_x += max_width + self.h_spacing;
        }
        cursor_y += max_height + self.v_spacing;
    }

    const fcols: f32 = @floatFromInt(cols);
    const frows: f32 = @floatFromInt(rows);

    return .{
        .width = fcols * max_width + (fcols - 1) * self.h_spacing,
        .height = frows * max_height + (frows - 1) * self.v_spacing,
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
