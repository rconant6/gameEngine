const std = @import("std");
const Color = @import("Color.zig").Color;

pub const Hue = enum { // h from hsv
    red,
    orange,
    yellow,
    chartreuse,
    green,
    spring,
    cyan,
    azure,
    blue,
    violet,
    magenta,
    rose,
    brown,
    neutral,

    pub fn from(c: Color) Hue {
        const h = c.hsva.h;
        const s = c.hsva.s;
        const v = c.hsva.v;

        if (s < 0.05) return .neutral;

        if (h >= 10.0 and h <= 50.0 and v < 0.6 and s < 0.7) {
            return .brown;
        }

        const normalized_h = @mod(h + 15.0, 360.0);
        const index = @as(u8, @intFromFloat(normalized_h / 30.0));

        return @enumFromInt(@min(index, 11));
    }
};

pub const Tone = enum { // v from hsv
    deep,
    dark,
    mid,
    light,
    high,

    pub fn from(c: Color) Tone {
        const v = c.hsva.v;

        return if (v < 0.2)
            .deep
        else if (v < 0.4)
            .dark
        else if (v < 0.6)
            .mid
        else if (v < 0.8)
            .light
        else
            .high;
    }
};

pub const Saturation = enum { // s from hsv
    gray,
    muted,
    moderate,
    vivid,

    pub fn from(c: Color) Saturation {
        const s = c.hsva.s;
        return if (s < 0.05)
            .gray
        else if (s < 0.35)
            .muted
        else if (s < 0.75)
            .moderate
        else
            .vivid;
    }
};

pub const Temperature = enum { // what??? there is only 3
    cool,
    neutral,
    warm,

    pub fn from(c: Color) Temperature {
        if (c.hsva.s < 0.05) return .neutral;
        const h = c.hsva.h;
        if ((h >= 0.0 and h <= 80.0) or (h >= 315.0 and h <= 360.0)) {
            return .warm;
        } else if (h >= 125.0 and h <= 265.0) {
            return .cool;
        } else {
            return .neutral;
        }
    }
};

pub const Family = enum {
    category,
    subcategory,
    family,
    unassigned,
};

pub const TaggedColor = struct {
    color: Color,
    hue: Hue,
    tone: Tone,
    saturation: Saturation,
    temp: Temperature,
    family: Family,

    pub fn from(c: Color) TaggedColor {
        return .{
            .color = c,
            .hue = Hue.from(c),
            .tone = Tone.from(c),
            .saturation = Saturation.from(c),
            .temp = Temperature.from(c),
            .family = .unassigned,
        };
    }
};
