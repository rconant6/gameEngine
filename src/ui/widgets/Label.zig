const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");

const Self = @This();

text: []const u8,
font: *const Font,
font_scale: f32,
color: Color,

pub fn layout(
    self: *const Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    _ = origin_x;
    _ = origin_y;

    const measured = self.font.measureText(self.text, self.font_scale);
    const size: Size = .{
        .width = measured.width,
        .height = measured.height,
    };

    return size.constrain(constraints);
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    const ascender: f32 = @floatFromInt(font.ascender);
    const per_em: f32 = @floatFromInt(font.units_per_em);
    const measured = font.measureText(self.text, self.font_scale);
    const ascent = (ascender / per_em) * self.font_scale;
    const text_y = bounds.y + ascent + (bounds.height - measured.height) / 2;
    renderer.drawTextScreen(
        font,
        self.text,
        .{ .x = bounds.x, .y = text_y },
        self.font_scale,
        self.color,
        ctx,
    );
}
