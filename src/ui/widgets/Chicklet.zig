const V2 = @import("math").V2;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const ColorLibrary = rend.ColorLibrary;
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Size = l_out.Size;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Rect = @import("../Rect.zig");
const evt = @import("../event.zig");
const Event = evt.Event;
const TextBlock = @import("../TextBlock.zig");
const WidgetState = @import("../widgetState.zig").WidgetState;
const dbg = @import("debug");
const log = dbg.log;
/// Ergonomic wrapper around the raw u16 toggle bits owned by UIManager.
/// Zero-cost at runtime — the compiler inlines everything.
pub const ChickletState = struct {
    bits: *u16,

    pub fn isHovered(self: ChickletState) bool {
        return self.bits.* & WidgetState.hovered != 0;
    }
    pub fn setHovered(self: ChickletState, val: bool) void {
        if (val) self.bits.* |= WidgetState.hovered else self.bits.* &= ~WidgetState.hovered;
    }
    pub fn isPressed(self: ChickletState) bool {
        return self.bits.* & WidgetState.pressed != 0;
    }
    pub fn setPressed(self: ChickletState, val: bool) void {
        if (val) self.bits.* |= WidgetState.pressed else self.bits.* &= ~WidgetState.pressed;
    }
    pub fn isSelected(self: ChickletState) bool {
        return self.bits.* & WidgetState.selected != 0;
    }
    pub fn setSelected(self: ChickletState, val: bool) void {
        if (val) self.bits.* |= WidgetState.selected else self.bits.* &= ~WidgetState.selected;
    }
};
pub const ChickletColors = struct {
    not_selected: Color = Colors.UI_BUTTON_NORMAL,
    selected: Color = Colors.UI_BUTTON_PRESSED,
};
const Self = @This();

pub const state_kind = .flags;

id: []const u8,
colors: ChickletColors,
state: ?*u16 = null,
size: V2,
selected: bool = false,
on_click: ?*const fn () void = null,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const desired = Size{ .width = self.size.x, .height = self.size.y };
    return desired.constrain(li.constraints);
}

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    if (event.consumed) return;
    const state = ChickletState{ .bits = self.state orelse return };

    const hit = bounds.contains(.{ .x = event.mouse_x, .y = event.mouse_y });
    switch (event.kind) {
        .mouse_move => {
            state.setHovered(hit);
        },
        .mouse_down => {
            if (hit) {
                state.setPressed(true);
                event.consume();
            }
        },
        .mouse_up => {
            if (hit and state.isPressed()) {
                if (self.on_click) |cb| cb();
                event.consume();
            }
            state.setPressed(false);
            state.setHovered(hit);
        },
    }
}
pub fn render(self: *Self, ri: RenderInfo) void {
    const bounds = ri.bounds;
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        return;
    const bg_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            bounds.height,
        ),
    );
    const state = ChickletState{ .bits = self.state orelse {
        log.err(.ui, "Invalid Button State {s}", .{self.id});
        return;
    } };
    const bg_color = if (self.selected) self.colors.selected
        else self.colors.not_selected;

    ri.renderer.drawGeometry(
        bg_shape,
        null,
        bg_color,
        if (state.isHovered() or self.selected) Colors.WHITE else null,
        1,
        ri.ctx,
    );
}
