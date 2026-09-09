const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const TextBlock = @import("../TextBlock.zig");
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Size = l_out.Size;
const evt = @import("../event.zig");
const Event = evt.Event;
const Rect = @import("../Rect.zig");
const WidgetState = @import("../widgetState.zig").WidgetState;
const log = @import("debug").log;

const Self = @This();
pub const state_kind = .flags;

pub const CheckboxColors = struct {
    normal: Color, // box fill
    hovered: Color,
    pressed: Color,
    text: Color, // label + box outline
    check: Color, // the mark
};

/// Ergonomic wrapper around the raw u16 toggle bits owned by UIManager.
/// Zero-cost at runtime — the compiler inlines everything.
pub const CheckboxState = struct {
    bits: *u16,

    pub fn isHovered(self: CheckboxState) bool {
        return self.bits.* & WidgetState.hovered != 0;
    }
    pub fn isPressed(self: CheckboxState) bool {
        return self.bits.* & WidgetState.pressed != 0;
    }
    pub fn setHovered(self: CheckboxState, val: bool) void {
        if (val) self.bits.* |= WidgetState.hovered else self.bits.* &= ~WidgetState.hovered;
    }
    pub fn setPressed(self: CheckboxState, val: bool) void {
        if (val) self.bits.* |= WidgetState.pressed else self.bits.* &= ~WidgetState.pressed;
    }
    pub fn markChanged(self: CheckboxState) void {
        self.bits.* |= WidgetState.changed;
    }
};

id: []const u8,
label: TextBlock,
/// The data's value, passed in by the builder every frame. The widget never
/// flips it — a click sets `changed`, the app flips its own bool.
checked: bool,
colors: CheckboxColors,
state: ?*u16 = null,
box_size: f32 = 16,
gap: f32 = 6,
corner_radius: f32 = 0,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const t = if (self.label.text.len > 0) self.label.getSize(li.font) else Size.zero;
    const gap = if (self.label.text.len > 0) self.gap else 0;
    return .{
        .width = self.box_size + gap + t.width,
        .height = @max(self.box_size, t.height),
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const st = CheckboxState{ .bits = self.state orelse {
        log.err(.ui, "Invalid Checkbox State {s}", .{self.id});
        return;
    } };
    const b = ri.bounds;
    const box = Rect.fromTopLeft(
        b.x,
        b.y + (b.height - self.box_size) / 2,
        self.box_size,
        self.box_size,
    );
    const fill = if (st.isPressed())
        self.colors.pressed
    else if (st.isHovered())
        self.colors.hovered
    else
        self.colors.normal;

    ri.renderer.render(.{
        .shape = box.toShape(self.corner_radius),
        .style = .{ .fill = fill, .stroke = self.colors.text, .stroke_width = 1 },
        .space = .screen,
    }, ri.ctx);

    if (self.checked) {
        // Filled inner square — reads as checked with no new geometry.
        const mark = box.inset(self.box_size * 0.25);
        ri.renderer.render(.{
            .shape = mark.toShape(self.corner_radius * 0.5),
            .style = .{ .fill = self.colors.check },
            .space = .screen,
        }, ri.ctx);
    }

    if (self.label.text.len == 0) return;
    const font = ri.font;
    const ascender: f32 = @floatFromInt(font.ascender);
    const per_em: f32 = @floatFromInt(font.units_per_em);
    const ascent = (ascender / per_em) * self.label.font_scale;
    const measured = font.measureText(self.label.text, self.label.font_scale);
    const text_y = b.y + ascent + (b.height - measured.y) / 2;
    ri.renderer.drawTextScreen(
        font,
        ri.tex,
        self.label.text,
        .{ .x = box.right() + self.gap, .y = text_y },
        self.label.font_scale,
        self.colors.text,
        ri.ctx,
    );
}

/// Bounds cover box + label, so clicking the label toggles too.
pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    const st = CheckboxState{ .bits = self.state orelse return };
    const hit = bounds.contains(event.mousePos());
    switch (event.kind) {
        .mouse_move => st.setHovered(hit),
        .mouse_down => {
            if (hit) {
                st.setPressed(true);
                event.consume();
            }
        },
        .mouse_up => {
            if (hit and st.isPressed()) {
                st.markChanged();
                event.consume();
            }
            st.setPressed(false);
            st.setHovered(hit);
        },
        else => {},
    }
}
