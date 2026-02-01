const std = @import("std");

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


