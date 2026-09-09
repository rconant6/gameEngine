const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const l_out = @import("../layout.zig");
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Size = l_out.Size;
const evt = @import("../event.zig");
const Event = evt.Event;
const Rect = @import("../Rect.zig");
const WidgetState = @import("../widgetState.zig").WidgetState;
const TextState = WidgetState.TextState;
const log = @import("debug").log;

const Self = @This();
pub const state_kind = .text;

pub const TextInputColors = struct {
    normal: Color, // field fill
    hovered: Color,
    focused: Color, // outline while editing
    text: Color,
    caret: Color,
};

id: []const u8,
/// The data's current text. Shown, and re-seeded into the edit buffer,
/// whenever the field is NOT focused — which also makes Esc a free cancel.
value: []const u8,
colors: TextInputColors,
width: f32 = 160, // fixed — inputs don't size to their content
font_scale: f32 = 16,
padding: f32 = 4,
corner_radius: f32 = 0,
state: ?*TextState = null,

fn isFocused(st: *const TextState) bool {
    return st.flags & WidgetState.focused != 0;
}

pub fn layout(self: *Self, li: LayoutInfo) Size {
    if (self.state) |st| {
        if (!isFocused(st)) st.set(self.value);
    }
    // Fixed probe: an empty field must not collapse to zero height.
    const line_h = li.font.measureText("Ag", self.font_scale).y;
    return .{
        .width = @min(self.width, li.constraints.max_width),
        .height = line_h + 2 * self.padding,
    };
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const st = self.state orelse {
        log.err(.ui, "Invalid TextInput State {s}", .{self.id});
        return;
    };
    const b = ri.bounds;
    const foc = isFocused(st);
    const fill = if (st.flags & WidgetState.hovered != 0) self.colors.hovered else self.colors.normal;

    ri.renderer.render(.{
        .shape = b.toShape(self.corner_radius),
        .style = .{
            .fill = fill,
            .stroke = if (foc) self.colors.focused else null,
            .stroke_width = 1.5,
        },
        .space = .screen,
    }, ri.ctx);

    const font = ri.font;
    const ascender: f32 = @floatFromInt(font.ascender);
    const per_em: f32 = @floatFromInt(font.units_per_em);
    const ascent = (ascender / per_em) * self.font_scale;
    const line_h = font.measureText("Ag", self.font_scale).y;
    const text_y = b.y + ascent + (b.height - line_h) / 2;
    const text_x = b.x + self.padding;

    if (st.len > 0) {
        ri.renderer.drawTextScreen(
            font,
            ri.tex,
            st.slice(),
            .{ .x = text_x, .y = text_y },
            self.font_scale,
            self.colors.text,
            ri.ctx,
        );
    }

    if (foc) {
        const cx = text_x + font.measureText(st.buf[0..st.caret], self.font_scale).x;
        const caret = Rect.fromTopLeft(cx, b.y + self.padding, 1.5, b.height - 2 * self.padding);
        ri.renderer.render(.{
            .shape = caret.toShape(0),
            .style = .{ .fill = self.colors.caret },
            .space = .screen,
        }, ri.ctx);
    }
}

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    const st = self.state orelse return;
    const hit = bounds.contains(event.mousePos());
    switch (event.kind) {
        .mouse_move => {
            if (hit) st.flags |= WidgetState.hovered else st.flags &= ~WidgetState.hovered;
        },
        .mouse_down => {
            // No else-branch: UIManager.blurAll already unfocused everything.
            if (hit) {
                st.flags |= WidgetState.focused;
                st.caret = st.len;
                event.consume();
            }
        },
        .key_down => {
            if (!isFocused(st)) return;
            switch (event.key orelse return) {
                .backspace => st.backspace(),
                .delete => st.delete(),
                .left => st.moveLeft(),
                .right => st.moveRight(),
                .enter => {
                    st.flags &= ~WidgetState.focused;
                    st.flags |= WidgetState.changed;
                },
                // No `changed` → next layout re-seeds from `value` = revert.
                .escape => st.flags &= ~WidgetState.focused,
                .tab => return, // unconsumed; no focus traversal in v1
            }
            event.consume();
        },
        .text_input => {
            if (!isFocused(st)) return;
            st.insert(event.char orelse return);
            event.consume();
        },
        else => {},
    }
}
