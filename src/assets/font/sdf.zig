const std = @import("std");
const Allocator = std.mem.Allocator;
const font_data = @import("font_data.zig");
const FilteredGlyph = font_data.FilteredGlyph;
const math = @import("math");
const V2 = math.V2;

pub const Target = struct {
    pixels: []u8,
    stride: u16, // atlas width
    gx: usize, // glyph's column
    gy: usize, // glyph's row
};

pub const Size = struct { w: u16, h: u16 };

// Coverage-only: 255 inside the outline, 0 outside, written straight into `t`.
// No allocation. TODO: full signed-distance transform (8ssedt)
pub fn rasterInto(
    t: Target,
    glyph: *const FilteredGlyph,
    cell_px: u16,
    pad: u16,
) Size {
    const w: u16 = cell_px + 2 * pad;
    const h: u16 = cell_px + 2 * pad;
    const scale: f32 = @floatFromInt(cell_px);

    rasterizeCoverage(glyph, scale, pad, w, h, t);
    return .{ .w = w, .h = h };
}

// Y-UP throughout: no flip. atlas row 0 == em y=0 (baseline); rows increase upward
// with the glyph. The ONLY y-flip in the whole text path is the screen ClipMap.
fn toPixel(p: V2, scale: f32, pad: u16) V2 {
    const fpad: f32 = @floatFromInt(pad);
    return .{
        .x = p.x * scale + fpad,
        .y = p.y * scale + fpad,
    };
}

// Scanline even-odd fill (255 inside), written into t's rect.
fn rasterizeCoverage(
    glyph: *const FilteredGlyph,
    scale: f32,
    pad: u16,
    w: u16,
    h: u16,
    t: Target,
) void {
    var crosses: [64]f32 = undefined; // crossings per scanline

    var y: u16 = 0;
    while (y < h) : (y += 1) {
        const cy: f32 = @as(f32, @floatFromInt(y)) + 0.5;
        var n: usize = 0;

        var start: usize = 0;
        for (glyph.contour_ends) |end| {
            const pts = glyph.points[start .. end + 1];
            var i: usize = 0;
            while (i < pts.len) : (i += 1) {
                const a = toPixel(pts[i], scale, pad);
                const b = toPixel(pts[(i + 1) % pts.len], scale, pad);

                if ((a.y <= cy) != (b.y <= cy)) {
                    const t_cross = (cy - a.y) / (b.y - a.y);
                    if (n < crosses.len) {
                        crosses[n] = a.x + t_cross * (b.x - a.x);
                        n += 1;
                    }
                }
            }
            start = end + 1;
        }
        std.sort.pdq(f32, crosses[0..n], {}, lessThan);

        // fill spans between crossing pairs, mapped into the atlas rect
        const row_base = (t.gy + y) * t.stride + t.gx;
        var k: usize = 0;
        while (k + 1 < n) : (k += 2) {
            const x0: i32 = @intFromFloat(@ceil(crosses[k] - 0.5));
            const x1: i32 = @intFromFloat(@floor(crosses[k + 1] - 0.5));
            var x = @max(x0, 0);
            const xe = @min(x1, @as(i32, w) - 1);
            while (x <= xe) : (x += 1) {
                t.pixels[row_base + @as(usize, @intCast(x))] = 255;
            }
        }
    }
}

fn lessThan(_: void, a: f32, b: f32) bool {
    return a < b;
}
