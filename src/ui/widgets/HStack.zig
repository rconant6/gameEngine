const std = @import("std");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
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

pub fn layout(self: *Self, li: LayoutInfo) Size {
    // ── Pass 1: measure fixed children, count spacers ──
    var fixed_width_total: f32 = 0;
    var spacer_count: f32 = 0;
    var max_height: f32 = 0;
    var remaining_width = li.constraints.max_width;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            spacer_count += 1;
        } else {
            // Layout at temporary origin to measure
            const child_size = child.layout(.{
                .constraints = .loose(remaining_width, li.constraints.max_height),
                .pos = .ZERO,
                .font = li.font,
            });
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
    const total_remaining = @max(0, li.constraints.max_width - fixed_width_total);
    const spacer_width = if (spacer_count > 0) total_remaining / spacer_count else 0;

    // ── Pass 2: assign positions left-to-right ──
    var cursor_x = li.pos.x;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            // Spacer gets its flex width, full height
            _ = child.layout(.{
                .constraints = Constraints.tight(spacer_width, max_height),
                .pos = .{ .x = cursor_x, .y = li.pos.y },
                .font = li.font,
            });
            cursor_x += spacer_width;
        } else {
            // Re-layout fixed child at correct position
            const child_info: LayoutInfo = .{
                .constraints = Constraints.loose(
                    child.bounds.width,
                    li.constraints.max_height,
                ),
                .font = li.font,
                .pos = .{ .x = cursor_x, .y = li.pos.y },
            };
            const child_size = child.layout(child_info);
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
            .start => li.pos.y,
            .end => li.pos.y + stack_height - child_height,
            .center => li.pos.y + (stack_height - child_height) / 2,
            .stretch => li.pos.y,
        };
    }

    const total_width = cursor_x - li.pos.x;
    return .{
        .width = total_width,
        .height = max_height,
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    for (self.children) |*child| {
        child.render(.{
            .renderer = ri.renderer,
            .ctx = ri.ctx,
            .font = ri.font,
            .bounds = child.bounds,
        });
    }
}
