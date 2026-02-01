const std = @import("std");
const math = @import("math.zig");
const Rgba = math.Rgba;
const Hsva = math.Hsva;

/// Color with synchronized RGBA and HSVA representations.
/// Both are always in sync - READ from either freely.
///
/// ## Creating Colors
/// - `Color.initRgba(r, g, b, a)` - from RGB bytes
/// - `Color.initHsva(h, s, v, a)` - from HSV floats
/// - `Color.initFromHex("#FF8040")` - from hex string
///
/// ## Modifying Colors (returns new Color)
/// RGB space (u8 values, 0-255):
/// - `withRed(r)`, `withGreen(g)`, `withBlue(b)`
/// - `withAlpha(a)`
/// - `withRgb(r, g, b)` - keeps alpha
///
/// HSV space (f32 values):
/// - `withHue(h)` - 0-360
/// - `withSaturation(s)` - 0-1
/// - `withBrightness(v)` - 0-1
/// - `withOpacity(o)` - 0-1
/// - `withHsv(h, s, v)` - keeps opacity
///
/// ## Reading Values
/// - `color.rgba.r`, `.g`, `.b`, `.a` - direct field access
/// - `color.hsva.h`, `.s`, `.v`, `.a` - direct field access
///
/// ⚠️ Don't mutate fields directly - use with* methods to keep sync.
pub const Color = struct {
    rgba: Rgba,
    hsva: Hsva,

    pub fn initRgba(r: u8, g: u8, b: u8, a: u8) Color {
        const rgba = Rgba{ .r = r, .g = g, .b = b, .a = a };
        const hsva = math.rgbToHsv(rgba);

        return .{
            .rgba = rgba,
            .hsva = hsva,
        };
    }
    pub fn initHsva(h: f32, s: f32, v: f32, a: f32) Color {
        const hsva = Hsva{ .h = h, .s = s, .v = v, .a = a };
        const rgba = math.hsvToRgb(hsva);

        return .{
            .rgba = rgba,
            .hsva = hsva,
        };
    }
    pub fn initFromHex(comptime str: []const u8) Color {
        const len = str.len;
        if ((len != 7 and len != 9) or str[0] != '#')
            @compileError("Invalid hex color format: expected #RRGGBB or #RRGGBBAA\n");

        return Color.initRgba(
            parseHexPair(str[1], str[2]),
            parseHexPair(str[3], str[4]),
            parseHexPair(str[5], str[6]),
            if (len == 9) parseHexPair(str[7], str[8]) else 255,
        );
    }
    pub fn initFromU32Hex(hex: u32) Color {
        if (hex > 0xFFFFFF) {
            // 8-digit: 0xRRGGBBAA
            return Color.initRgba(
                @truncate(hex >> 24),
                @truncate(hex >> 16),
                @truncate(hex >> 8),
                @truncate(hex),
            );
        } else {
            // 6-digit: 0xRRGGBB
            return Color.initRgba(
                @truncate(hex >> 16),
                @truncate(hex >> 8),
                @truncate(hex),
                255, // Default Opaque
            );
        }
    }

    pub fn withRgb(c: Color, r: u8, g: u8, b: u8) Color {
        return Color.initRgba(r, g, b, c.rgba.a);
    }
    pub fn withRed(c: Color, r: u8) Color {
        return Color.initRgba(r, c.rgba.g, c.rgba.b, c.rgba.a);
    }
    pub fn withGreen(c: Color, g: u8) Color {
        return Color.initRgba(c.rgba.r, g, c.rgba.b, c.rgba.a);
    }
    pub fn withBlue(c: Color, b: u8) Color {
        return Color.initRgba(c.rgba.r, c.rgba.g, b, c.rgba.a);
    }
    pub fn withAlpha(c: Color, a: u8) Color {
        return Color.initRgba(c.rgba.r, c.rgba.g, c.rgba.b, a);
    }
    pub fn withHsv(c: Color, h: f32, s: f32, v: f32) Color {
        return Color.initHsva(h, s, v, c.hsva.a);
    }
    pub fn withHue(c: Color, h: f32) Color {
        return Color.initHsva(h, c.hsva.s, c.hsva.v, c.hsva.a);
    }
    pub fn withSaturation(c: Color, s: f32) Color {
        return Color.initHsva(c.hsva.h, s, c.hsva.v, c.hsva.a);
    }
    pub fn withBrightness(c: Color, v: f32) Color {
        return Color.initHsva(c.hsva.h, c.hsva.s, v, c.hsva.a);
    }
    pub fn withOpacity(c: Color, a: f32) Color {
        return Color.initHsva(c.hsva.h, c.hsva.s, c.hsva.v, a);
    }

    fn hexCharToInt(comptime c: u8) u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => @compileError("Invalid hex character"),
        };
    }

    fn parseHexPair(comptime c1: u8, comptime c2: u8) u8 {
        return hexCharToInt(c1) * 16 + hexCharToInt(c2);
    }
};
