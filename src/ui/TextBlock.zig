const assets = @import("assets");
const Font = assets.Font;
const lo = @import("layout.zig");
const Size = lo.Size;

const Self = @This();

text: []const u8 = "",
font_scale: f32 = 24.0,
font: ?*const Font = null,
cached_size: ?Size = null,

pub fn getSize(self: *Self, supplied_font: *const Font) Size {
    if (self.font != supplied_font) {
        // reset everything and return the new calc w/ measure
        self.font = supplied_font;
        self.cached_size = self.measure(supplied_font);
        return self.cached_size.?;
    }

    return self.cached_size orelse self.measure(supplied_font);
}

pub fn measure(
    self: *Self,
    font: *const Font,
) Size {
    const raw_result = font.measureText(self.text, self.font_scale);
    self.cached_size = .{ .width = raw_result.x, .height = raw_result.y };
    return self.cached_size orelse .zero;
}
