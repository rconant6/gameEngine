const Self = @This();
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const EdgeInsets = l_out.EdgeInsets;
const Size = l_out.Size;
const WidgetNode = @import("WidgetNode.zig");
const WidgetState = @import("widgetState.zig").WidgetState;
const evt = @import("event.zig");
const Event = evt.Event;
const EventKind = evt.EventKind;
const MouseButton = evt.MouseButton;
const Rect = @import("../Rect.zig");

pub const state_kind = .cursor;

id: []const u8,
child: *WidgetNode,
state: ?WidgetState = null, // .cursor, offset = scrollpx
scroll_speed: f32 = 30,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    _ = self;
    _ = li;
    @panic("not implemented");
}
pub fn render(self: *Self, ri: RenderInfo) Size {
    _ = self;
    _ = ri;
    @panic("not implemented");
}
pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    _ = self;
    _ = event;
    _ = bounds;
    @panic("not implemented");
}
pub fn children(self: *Self) []WidgetNode {
    return @as(*[1]WidgetNode, self.child);
}
