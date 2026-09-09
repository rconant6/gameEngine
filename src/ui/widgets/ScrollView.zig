const std = @import("std");
const math = std.math;
const Self = @This();
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const WidgetNode = @import("WidgetNode.zig");
const WidgetState = @import("../widgetState.zig").WidgetState;
const evt = @import("../event.zig");
const Event = evt.Event;
const EventKind = evt.EventKind;
const MouseButton = evt.MouseButton;
const Rect = @import("../Rect.zig");

pub const state_kind = .cursor;
/// Pointer events outside this widget's bounds don't reach its children —
/// rows scrolled out of the viewport still have real bounds and would
/// otherwise take clicks through whatever is drawn there.
pub const clips_children = true;

id: []const u8,
child: *WidgetNode,
state: ?*WidgetState = null,
scroll_speed: f32 = 30,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const offset = if (self.state) |s| s.cursor.offset else 0;

    const child_const = Constraints{
        .max_height = math.floatMax(f32),
        .max_width = li.constraints.max_width,
        .min_height = 0,
        .min_width = 0,
    };

    const content = self.child.layout(.{
        .font = li.font,
        .constraints = child_const,
        .pos = .{
            .x = li.pos.x,
            .y = li.pos.y - offset,
        },
    });

    const max_scroll = @max(0, content.height - li.constraints.max_height);
    if (self.state) |s| {
        s.cursor.max_offset = max_scroll;
        s.cursor.offset = @min(offset, max_scroll);
    }

    return .{
        .width = @min(content.width, li.constraints.max_width),
        .height = li.constraints.max_height,
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const view_top = ri.bounds.y;
    const view_bot = ri.bounds.y + ri.bounds.height;

    switch (self.child.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "children")) {
                for (w.children()) |*row| {
                    if (row.bounds.y + row.bounds.height < view_top) continue; // fully above
                    if (row.bounds.y > view_bot) continue; // fully below
                    row.render(.{
                        .renderer = ri.renderer,
                        .ctx = ri.ctx,
                        .font = ri.font,
                        .tex = ri.tex,
                        .bounds = row.bounds,
                    });
                }
            } else {
                // Child is a leaf — nothing to cull per-row, draw it whole.
                self.child.render(.{
                    .renderer = ri.renderer,
                    .ctx = ri.ctx,
                    .font = ri.font,
                    .tex = ri.tex,
                    .bounds = self.child.bounds,
                });
            }
        },
    }
}

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    if (event.kind != .mouse_scroll) return;
    if (!bounds.contains(event.mousePos())) return;

    const state = self.state orelse return;
    // Clamp both ends here — layout positions the child with this offset
    // before it can re-measure, so an unclamped value shows past the end.
    state.cursor.offset = std.math.clamp(
        state.cursor.offset - event.scroll_delta * self.scroll_speed,
        0,
        state.cursor.max_offset,
    );

    event.consume();
}
pub fn children(self: *Self) []WidgetNode {
    return @as(*[1]WidgetNode, self.child);
}
