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
const Rect = @import("../Rect.zig");
const evt = @import("../event.zig");
const Event = evt.Event;
const dbg = @import("debug");
const log = dbg.log;

/// Ergonomic wrapper around the raw u16 toggle bits owned by UIManager.
/// Zero-cost at runtime — the compiler inlines everything.
pub const ButtonState = struct {
    const HOVERED: u16 = 0x1;
    const PRESSED: u16 = 0x2;

    bits: *u16,

    pub fn isHovered(self: ButtonState) bool {
        return self.bits.* & HOVERED != 0;
    }
    pub fn isPressed(self: ButtonState) bool {
        return self.bits.* & PRESSED != 0;
    }
    pub fn setHovered(self: ButtonState, val: bool) void {
        if (val) self.bits.* |= HOVERED else self.bits.* &= ~HOVERED;
    }
    pub fn setPressed(self: ButtonState, val: bool) void {
        if (val) self.bits.* |= PRESSED else self.bits.* &= ~PRESSED;
    }
};

pub const ButtonColors = struct {
    normal: Color,
    hovered: Color,
    pressed: Color,
    text: Color,
    background: Color = Colors.UI_BUTTON_NORMAL,
};

const Self = @This();

pub const state_kind = .flags;

id: []const u8,
text: []const u8,
font: *const Font,
font_scale: f32,
colors: ButtonColors,
state: ?*u16 = null,
on_click: ?*const fn () void = null,

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    _ = constraints;
    _ = origin_x;
    _ = origin_y;
    const measured_text = self.font.measureText(self.text, self.font_scale);
    return .{
        .width = measured_text.width + 16,
        .height = measured_text.height + 8,
    };
}

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    if (event.consumed) return;
    const state = ButtonState{ .bits = self.state orelse return };

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
            state.setHovered(hit);
            state.setPressed(false);
        },
    }
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    const ascender: f32 = @floatFromInt(self.font.ascender);
    const per_em: f32 = @floatFromInt(self.font.units_per_em);
    const measured = self.font.measureText(self.text, self.font_scale);
    const ascent = (ascender / per_em) * self.font_scale;
    const text_y = bounds.y + ascent + (bounds.height - measured.height) / 2;
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
    const state = ButtonState{ .bits = self.state orelse {
        log.err(.ui, "Invalid Button State {s}", .{self.id});
        return;
    } };
    const bg_color = blk: {
        if (state.isPressed()) break :blk self.colors.pressed;
        if (state.isHovered()) break :blk self.colors.hovered;
        break :blk self.colors.normal;
    };
    renderer.drawGeometry(
        bg_shape,
        null,
        bg_color,
        null,
        1,
        ctx,
    );

    renderer.drawTextScreen(
        font,
        self.text,
        .{ .x = bounds.x, .y = text_y },
        self.font_scale,
        self.colors.text,
        ctx,
    );
}
