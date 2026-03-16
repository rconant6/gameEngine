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

const Self = @This();

children: []WidgetNode,
spacing: f32,
cross_axis: Alignment.Horizontal,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    // ── Pass 1: measure fixed children, count spacers ──
    var fixed_height_total: f32 = 0;
    var spacer_count: f32 = 0;
    var max_width: f32 = 0;
    var remaining_height = li.constraints.max_height;

    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            spacer_count += 1;
        } else {
            // Layout at temporary origin to measure
            const child_size = child.layout(.{
                .constraints = .loose(
                    li.constraints.max_width,
                    remaining_height,
                ),
                .pos = .ZERO,
                .font = li.font,
            });

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
    const total_remaining = @max(0, li.constraints.max_height - fixed_height_total);
    const spacer_height = if (spacer_count > 0) total_remaining / spacer_count else 0;

    var cursor_y = li.pos.y;

    // ── Pass 2: assign positions top-to-bottom ──
    for (self.children, 0..) |*child, i| {
        if (child.widget == .Spacer) {
            // Spacer gets its flex width, full height
            _ = child.layout(.{
                .constraints = .tight(max_width, spacer_height),
                .pos = .{ .x = li.pos.x, .y = cursor_y },
                .font = li.font,
            });
            cursor_y += spacer_height;
        } else {
            // Re-layout fixed child at correct position
            const child_size = child.layout(.{
                .constraints = .loose(
                    li.constraints.max_width,
                    child.bounds.height,
                ),
                .pos = .{ .x = li.pos.x, .y = cursor_y },
                .font = li.font,
            });

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
            .start => li.pos.x,
            .end => li.pos.x + stack_width - child_width,
            .center => li.pos.x + (stack_width - child_width) / 2,
            .stretch => li.pos.x,
        };
    }

    const total_height = cursor_y - li.pos.y;
    return .{
        .width = max_width,
        .height = total_height,
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
