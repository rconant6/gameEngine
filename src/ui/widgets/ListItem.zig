const assets = @import("assets");
const Font = assets.Font;
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
pub const ListItemState = struct {
    bits: *u16,

    pub fn isHovered(self: ListItemState) bool {
        return self.bits.* & WidgetState.hovered != 0;
    }
    pub fn isPressed(self: ListItemState) bool {
        return self.bits.* & WidgetState.pressed != 0;
    }
    pub fn setHovered(self: ListItemState, val: bool) void {
        if (val) self.bits.* |= WidgetState.hovered else self.bits.* &= ~WidgetState.hovered;
    }
    pub fn setPressed(self: ListItemState, val: bool) void {
        if (val) self.bits.* |= WidgetState.pressed else self.bits.* &= ~WidgetState.pressed;
    }
};

pub const ListItemColors = struct {
    normal: Color,
    hovered: Color,
    selected: Color,
    text: Color,
    text_selected: Color,
    background: Color = Colors.UI_BUTTON_NORMAL,
};

const Self = @This();

pub const state_kind = .flags;

id: []const u8,
indent: u8,
selected: bool = false,
state: ?*u16 = null,
indent_size: u8 = 16,
text_info: TextBlock,
colors: ListItemColors,

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    if (event.consumed) return;
    const state = ListItemState{ .bits = self.state orelse return };

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
                event.consume();
            }
            state.setHovered(hit);
            state.setPressed(false);
        },
    }
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const bounds = ri.bounds;
    const font = ri.font;
    const ascender: f32 = @floatFromInt(font.ascender);
    const per_em: f32 = @floatFromInt(font.units_per_em);
    const measured = ri.font.measureText(self.text_info.text, self.text_info.font_scale);
    const ascent = (ascender / per_em) * self.text_info.font_scale;
    const text_y = bounds.y + ascent + (bounds.height - measured.y) / 2;
    const Rectangle = rend.ShapeRegistry.getShapeType("Rectangle") orelse
        return;
    const bg_shape = rend.ShapeRegistry.createShapeUnion(
        Rectangle,
        Rectangle.initFromTopLeft(
            .{ .x = bounds.x, .y = bounds.y },
            bounds.width,
            bounds.height,
        ),
    );
    const state = ListItemState{ .bits = self.state orelse {
        log.err(.ui, "Invalid ListItem State {s}", .{self.id});
        return;
    } };
    const bg_color = blk: {
        if (self.selected) break :blk self.colors.selected;
        if (state.isHovered()) break :blk self.colors.hovered;
        break :blk self.colors.normal;
    };
    const text_color = if (self.selected) self.colors.text_selected else self.colors.text;
    const indent_offset: f32 = @as(f32, @floatFromInt(self.indent)) * @as(f32, @floatFromInt(self.indent_size));

    ri.renderer.render(.{
        .shape = bg_shape,
        .style = .{
            .fill = bg_color,
        },
        .space = .screen,
    }, ri.ctx);

    ri.renderer.drawTextScreen(
        font,
        ri.tex,
        self.text_info.text,
        .{ .x = bounds.x + indent_offset, .y = text_y },
        self.text_info.font_scale,
        text_color,
        ri.ctx,
    );
}

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const measured_text = self.text_info.getSize(li.font);
    return .{
        .width = measured_text.width + 16 + self.indent * self.indent_size,
        .height = measured_text.height + 8,
    };
}
