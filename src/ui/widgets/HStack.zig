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
const WidgetData = @import("widget_registry.zig").WidgetData;

const Self = @This();

children: []WidgetNode,
spacing: f32,
cross_axis: Alignment.Vertical,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    // ── Pass 1: measure fixed children, count spacers ──
    var fixed_width_total: f32 = 0;
    var spacer_count: f32 = 0;
    var max_height: f32 = 0;
    var remaining_width = constraints.max_width;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            spacer_count += 1;
        } else {
            const child_constraints = Constraints.loose(
                remaining_width,
                constraints.max_height,
            );
            // Layout at temporary origin to measure
            const child_size = child.layout(child_constraints, 0, 0);
            fixed_width_total += child_size.width;
            remaining_width -= child_size.width;
            max_height = @max(max_height, child_size.height);
        }

        // Account for spacing between children
        if (i < self.children.len - 1) {
            fixed_width_total += self.spacing;
            remaining_width -= self.spacing;
        }
    }

    // Distribute remaining space to spacers
    const total_remaining = @max(0, constraints.max_width - fixed_width_total);
    const spacer_width = if (spacer_count > 0) total_remaining / spacer_count else 0;

    // ── Pass 2: assign positions left-to-right ──
    var cursor_x = origin_x;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            // Spacer gets its flex width, full height
            _ = child.layout(Constraints.tight(spacer_width, max_height), cursor_x, origin_y);
            cursor_x += spacer_width;
        } else {
            // Re-layout fixed child at correct position
            const child_constraints = Constraints.loose(
                child.bounds.width,
                constraints.max_height,
            );
            const child_size = child.layout(child_constraints, cursor_x, origin_y);
            cursor_x += child_size.width;
        }

        if (i < self.children.len - 1) {
            cursor_x += self.spacing;
        }
    }

    // ── Cross-axis alignment ──
    const stack_height = max_height;
    for (self.children) |*child| {
        const child_height = child.bounds.height;
        child.bounds.y = switch (self.cross_axis) {
            .start => origin_y,
            .end => origin_y + stack_height - child_height,
            .center => origin_y + (stack_height - child_height) / 2,
            .stretch => origin_y,
        };
    }

    const total_width = cursor_x - origin_x;
    return .{
        .width = total_width,
        .height = max_height,
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
