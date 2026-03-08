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

pub const ButtonState = struct {
    hovered: bool = false,
    pressed: bool = false,
};

pub const ButtonColors = struct {
    normal: Color,
    hovered: Color,
    pressed: Color,
    text: Color,
    background: Color = Colors.UI_BUTTON_NORMAL,
};

const Self = @This();

id: []const u8,
text: []const u8,
font: *const Font,
font_scale: f32,
colors: ButtonColors,
state: ButtonState = .{},
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

    const hit = bounds.contains(.{ .x = event.mouse_x, .y = event.mouse_y });
    switch (event.kind) {
        .mouse_move => {
            self.state.hovered = hit;
        },
        .mouse_down => {
            if (hit) {
                self.state.pressed = true;
                event.consume();
            }
        },
        .mouse_up => {
            if (hit and self.state.pressed) {
                if (self.on_click) |cb| cb();
                event.consume();
            }
            if (hit) {
                self.state.hovered = true;
            }
            self.state.pressed = false;
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
    const bg_color = blk: {
        if (self.state.pressed) break :blk self.colors.pressed;
        if (self.state.hovered) break :blk self.colors.hovered;
        break :blk self.colors.normal;
    };
    // TODO: handle color of bg based on state
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
