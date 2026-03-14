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
    // ── Pass 1: measure fixed children, count spacers ──
    var fixed_height_total: f32 = 0;
    var spacer_count: f32 = 0;
    var max_width: f32 = 0;
    var remaining_height = constraints.max_height;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            spacer_count += 1;
        } else {
            const child_contraints = Constraints.loose(
                constraints.max_width,
                remaining_height,
            );
            // Layout at temporary origin to measure
            const child_size = child.layout(child_contraints, 0, 0);
            fixed_height_total += child_size.height;
            remaining_height -= child_size.height;
            max_width = @max(max_width, child_size.width);
        }

        // Account for spacing between children
        if (i < self.children.len - 1) {
            fixed_height_total += self.spacing;
            remaining_height -= self.spacing;
        }
    }

    // Distribute remaining space to spacers
    const total_remaining = @max(0, constraints.max_height - fixed_height_total);
    const spacer_height = if (spacer_count > 0) total_remaining / spacer_count else 0;

    var cursor_y = origin_y;

    // ── Pass 2: assign positions top-to-bottom ──
    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            // Spacer gets its flex width, full height
            _ = child.layout(.tight(max_width, spacer_height), origin_x, cursor_y);
            cursor_y += spacer_height;
        } else {
            // Re-layout fixed child at correct position
            const child_constraints = Constraints.loose(
                constraints.max_width,
                child.bounds.height,
            );
            const child_size = child.layout(child_constraints, origin_x, cursor_y);
            cursor_y += child_size.height;
        }

        if (i < self.children.len - 1) {
            cursor_y += self.spacing;
        }
    }

    // ── Cross-axis alignment ──
    const stack_width = max_width;
    for (self.children) |*child| {
        const child_width = child.bounds.width;
        child.bounds.x = switch (self.cross_axis) {
            .start => origin_x,
            .end => origin_x + stack_width - child_width,
            .center => origin_x + (stack_width - child_width) / 2,
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
