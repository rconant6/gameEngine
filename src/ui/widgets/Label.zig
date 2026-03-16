const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Color = rend.Color;
const assets = @import("assets");
const Font = assets.Font;
const l_out = @import("../layout.zig");
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const Constraints = l_out.Constraints;
const Size = l_out.Size;
const Rect = @import("../Rect.zig");
const TextBlock = @import("../TextBlock.zig");

const Self = @This();

tb: TextBlock,
color: Color,

pub fn layout(self: *Self, li: LayoutInfo) Size {
    const size: Size = self.tb.getSize(li.font);
    return size.constrain(li.constraints);
}

pub fn render(self: *Self, ri: RenderInfo) void {
    const font = ri.font;
    const bounds = ri.bounds;
    const ascender: f32 = @floatFromInt(font.ascender);
    const per_em: f32 = @floatFromInt(font.units_per_em);
    const measured = self.tb.getSize(font);
    const ascent = (ascender / per_em) * self.tb.font_scale;
    const text_y = bounds.y + ascent + (bounds.height - measured.height) / 2;
    ri.renderer.drawTextScreen(
        font,
        self.tb.text,
        .{ .x = bounds.x, .y = text_y },
        self.tb.font_scale,
        self.color,
        ri.ctx,
    );
}
