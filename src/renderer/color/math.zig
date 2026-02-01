const std = @import("std");
const Color = @import("Color.zig").Color;

pub const Rgba = struct {
    r: u8, // 0-255
    g: u8, // 0-255
    b: u8, // 0-255
    a: u8, // 0-255
};
pub const Hsva = struct {
    h: f32, // 0-360
    s: f32, // 0-1
    v: f32, // 0-1
    a: f32, // 0-1
};

pub fn rgbToHsv(rgba: Rgba) Hsva {
    const r = @as(f32, @floatFromInt(rgba.r)) / 255.0;
    const g = @as(f32, @floatFromInt(rgba.g)) / 255.0;
    const b = @as(f32, @floatFromInt(rgba.b)) / 255.0;

    const max = @max(r, @max(g, b));
    const min = @min(r, @min(g, b));
    const d = max - min;

    var h: f32 = 0;
    if (d > 0) {
        if (max == r) h = (g - b) / d + (if (g < b) @as(f32, 6) else 0);
        if (max == g) h = (b - r) / d + 2;
        if (max == b) h = (r - g) / d + 4;
        h /= 6;
    }

    return .{
        .h = h * 360.0,
        .s = if (max == 0) 0 else (d / max),
        .v = max,
        .a = @as(f32, @floatFromInt(rgba.a)) / 255.0,
    };
}

pub fn hsvToRgb(hsv: Hsva) Rgba {
    const h = @mod(hsv.h, 360.0) / 60.0;
    const s = hsv.s;
    const v = hsv.v;

    const i = @as(i32, @intFromFloat(@floor(h)));
    const f = h - @as(f32, @floatFromInt(i));

    const p = v * (1.0 - s);
    const q = v * (1.0 - s * f);
    const t = v * (1.0 - s * (1.0 - f));

    const res = switch (i) {
        0 => [3]f32{ v, t, p },
        1 => [3]f32{ q, v, p },
        2 => [3]f32{ p, v, t },
        3 => [3]f32{ p, q, v },
        4 => [3]f32{ t, p, v },
        else => [3]f32{ v, p, q },
    };

    return .{
        .r = @intFromFloat(@round(res[0] * 255.0)),
        .g = @intFromFloat(@round(res[1] * 255.0)),
        .b = @intFromFloat(@round(res[2] * 255.0)),
        .a = @intFromFloat(@round(hsv.a * 255.0)),
    };
}

pub fn distance(a: Color, b: Color) f32 {
    const diff = @abs(a.hsva.h - b.hsva.h);
    const hue_diff = @min(diff, 360 - diff);
    const hue_dist = hue_diff / 180;

    const dist_sq =
        (hue_dist * 0.35) * (hue_dist * 0.35) +
        ((a.hsva.s - b.hsva.s) * 0.15) * ((a.hsva.s - a.hsva.s) * 0.15) +
        ((a.hsva.v - a.hsva.v) * 0.50) * ((a.hsva.v - a.hsva.v) * 0.50);

    return @sqrt(dist_sq);
}
pub fn lerp(a: Color, b: Color, t: f32) Color {
    const h1 = a.hsva.h;
    const h2 = b.hsva.h;

    // Find shortest path around the circle
    var diff = h2 - h1;
    if (diff > 180) diff = diff - 360;
    if (diff < -180) diff = diff + 360;

    const h = @mod((h1 + diff * t), 360);
    const s = a.hsva.s + (b.hsva.s - a.hsva.s) * t;
    const v = a.hsva.v + (b.hsva.v - a.hsva.v) * t;

    return Color.initHsva(h, s, v, a.hsva.a);
}
pub fn hueShift(c: Color, degrees: f32) Color {
    const h = @mod(c.hsva.h + degrees, 360);
    return c.withHue(h);
}
