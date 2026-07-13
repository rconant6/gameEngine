const std = @import("std");
const math = @import("math.zig");
const Rgba = math.Rgba;
const Hsva = math.Hsva;
const types = @import("types.zig");
const Hue = types.Hue;
const Tone = types.Tone;
const Saturation = types.Saturation;
const Temperature = types.Temperature;

pub const MixSpace = enum {
    srgb, // naive byte lerp
    linear, // correct blends
    oklab, // evenest (use this)
    hsv, // shortest arc_hue
};

/// lin is the 'working form' - every op computes in linear space then rebuilds
/// the rgb / hsv for display round trip.
/// The Color one truth for the Color, ask it to do what you want for your use case
///    - .oklab => matrix and non-linearity
///    - follows the RTR(real time rendering) model
pub const Color = struct {
    // Canonical
    rgba: Rgba,
    // Derived
    hsva: Hsva,
    // Mathy version (where the work happens)
    lin: [4]f32,

    // ---- Rebuild anchors -------------------------------------------------
    // Every constructor and op routes through exactly one of these, so the
    // three views (rgba / hsva / lin) can never drift.

    fn fromRgba(rgba: Rgba) Color {
        return .{
            .rgba = rgba,
            .hsva = math.rgbToHsv(rgba),
            .lin = .{
                srgbToLinear(@as(f32, @floatFromInt(rgba.r)) / 255.0),
                srgbToLinear(@as(f32, @floatFromInt(rgba.g)) / 255.0),
                srgbToLinear(@as(f32, @floatFromInt(rgba.b)) / 255.0),
                @as(f32, @floatFromInt(rgba.a)) / 255.0, // alpha linear by convention
            },
        };
    }
    fn fromHsva(hsva: Hsva) Color {
        return fromRgba(math.hsvToRgb(hsva));
    }
    fn fromLin(lin: [4]f32) Color {
        const rgba = Rgba{
            .r = @intFromFloat(@round(linearToSrgb(std.math.clamp(lin[0], 0, 1)) * 255.0)),
            .g = @intFromFloat(@round(linearToSrgb(std.math.clamp(lin[1], 0, 1)) * 255.0)),
            .b = @intFromFloat(@round(linearToSrgb(std.math.clamp(lin[2], 0, 1)) * 255.0)),
            .a = @intFromFloat(@round(std.math.clamp(lin[3], 0, 1) * 255.0)),
        };
        return .{
            .rgba = rgba,
            .hsva = math.rgbToHsv(rgba),
            .lin = .{ lin[0], lin[1], lin[2], std.math.clamp(lin[3], 0, 1) },
        };
    }

    pub fn toSrgbPacked(self: Color) u32 {
        return self.rgba.pack();
    }

    pub fn toLinearPacked(self: Color) u32 {
        return (Rgba{
            .r = @intFromFloat(@round(std.math.clamp(self.lin[0], 0, 1) * 255.0)),
            .g = @intFromFloat(@round(std.math.clamp(self.lin[1], 0, 1) * 255.0)),
            .b = @intFromFloat(@round(std.math.clamp(self.lin[2], 0, 1) * 255.0)),
            .a = @intFromFloat(@round(std.math.clamp(self.lin[3], 0, 1) * 255.0)),
        }).pack();
    }

    // MARK: Constructore

    pub fn initRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return fromRgba(.{ .r = r, .g = g, .b = b, .a = a });
    }
    pub fn initRgbaF(r: f32, g: f32, b: f32, a: f32) Color {
        return fromRgba(.{
            .r = @intFromFloat(@round(std.math.clamp(r, 0, 1) * 255.0)),
            .g = @intFromFloat(@round(std.math.clamp(g, 0, 1) * 255.0)),
            .b = @intFromFloat(@round(std.math.clamp(b, 0, 1) * 255.0)),
            .a = @intFromFloat(@round(std.math.clamp(a, 0, 1) * 255.0)),
        });
    }
    pub fn initHsva(h: f32, s: f32, v: f32, a: f32) Color {
        return fromHsva(.{ .h = h, .s = s, .v = v, .a = a });
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

    /// Alias kept so every existing call site stays green. Today == toSrgbPacked.
    pub fn pack(self: Color) u32 {
        return self.toSrgbPacked();
    }

    // ---- Opacity / packing (absorbed from tess.zig) ---------------------

    /// Pack with a 0..1 opacity multiplier applied to alpha. Replaces the old
    /// tess.packWithOpacity.
    pub fn withOpacityPacked(self: Color, opacity: f32) u32 {
        if (opacity >= 1.0) return self.toSrgbPacked();
        const a: u8 = @intFromFloat(@round(@as(f32, @floatFromInt(self.rgba.a)) *
            std.math.clamp(opacity, 0, 1)));
        return (Rgba{ .r = self.rgba.r, .g = self.rgba.g, .b = self.rgba.b, .a = a }).pack();
    }

    /// Static packed-space lerp for the gradient hot path. NOT linear-correct —
    /// the deliberate fast path (touches every vertex). Replaces tess.lerpPacked.
    pub fn lerpPackedU32(a: u32, b: u32, t: f32) u32 {
        const ca = Rgba.unpack(a);
        const cb = Rgba.unpack(b);
        const k = std.math.clamp(t, 0, 1);
        return (Rgba{
            .r = lerpByte(ca.r, cb.r, k),
            .g = lerpByte(ca.g, cb.g, k),
            .b = lerpByte(ca.b, cb.b, k),
            .a = lerpByte(ca.a, cb.a, k),
        }).pack();
    }

    // ---- Intent ops (compute in linear, return Color) -------------------

    /// Scale alpha by amount (0 = transparent, 1 = unchanged).
    pub fn fade(self: Color, amount: f32) Color {
        return fromLin(.{ self.lin[0], self.lin[1], self.lin[2], self.lin[3] * amount });
    }
    /// Toward white in linear space.
    pub fn lighten(self: Color, amount: f32) Color {
        const k = std.math.clamp(amount, 0, 1);
        return fromLin(.{
            self.lin[0] + (1.0 - self.lin[0]) * k,
            self.lin[1] + (1.0 - self.lin[1]) * k,
            self.lin[2] + (1.0 - self.lin[2]) * k,
            self.lin[3],
        });
    }
    /// Toward black in linear space.
    pub fn darken(self: Color, amount: f32) Color {
        const k = std.math.clamp(amount, 0, 1);
        return fromLin(.{
            self.lin[0] * (1.0 - k),
            self.lin[1] * (1.0 - k),
            self.lin[2] * (1.0 - k),
            self.lin[3],
        });
    }
    /// Increase saturation. Perceptual knob stays on the HSV cylinder.
    pub fn saturate(self: Color, amount: f32) Color {
        return initHsva(self.hsva.h, std.math.clamp(self.hsva.s + amount, 0, 1), self.hsva.v, self.hsva.a);
    }
    /// Decrease saturation.
    pub fn desaturate(self: Color, amount: f32) Color {
        return initHsva(self.hsva.h, std.math.clamp(self.hsva.s - amount, 0, 1), self.hsva.v, self.hsva.a);
    }

    /// The one mixer. t in 0..1 from self toward other, interpolated in `space`.
    pub fn mix(self: Color, other: Color, t: f32, space: MixSpace) Color {
        const k = std.math.clamp(t, 0, 1);
        switch (space) {
            .hsv => {
                var diff = other.hsva.h - self.hsva.h;
                if (diff > 180) diff -= 360;
                if (diff < -180) diff += 360;
                return initHsva(
                    @mod(self.hsva.h + diff * k, 360),
                    self.hsva.s + (other.hsva.s - self.hsva.s) * k,
                    self.hsva.v + (other.hsva.v - self.hsva.v) * k,
                    self.hsva.a + (other.hsva.a - self.hsva.a) * k,
                );
            },
            .linear => return fromLin(.{
                self.lin[0] + (other.lin[0] - self.lin[0]) * k,
                self.lin[1] + (other.lin[1] - self.lin[1]) * k,
                self.lin[2] + (other.lin[2] - self.lin[2]) * k,
                self.lin[3] + (other.lin[3] - self.lin[3]) * k,
            }),
            .oklab => {
                const la = linearToOklab(.{ self.lin[0], self.lin[1], self.lin[2] });
                const lb = linearToOklab(.{ other.lin[0], other.lin[1], other.lin[2] });
                const mixed = oklabToLinear(.{
                    la[0] + (lb[0] - la[0]) * k,
                    la[1] + (lb[1] - la[1]) * k,
                    la[2] + (lb[2] - la[2]) * k,
                });
                return fromLin(.{
                    mixed[0],
                    mixed[1],
                    mixed[2],
                    self.lin[3] + (other.lin[3] - self.lin[3]) * k,
                });
            },
            .srgb => {
                const rf: f32 = @floatFromInt(self.rgba.r);
                const gf: f32 = @floatFromInt(self.rgba.g);
                const bf: f32 = @floatFromInt(self.rgba.b);
                const af: f32 = @floatFromInt(self.rgba.a);
                return initRgba(
                    @intFromFloat(@round(rf + (@as(f32, @floatFromInt(other.rgba.r)) - rf) * k)),
                    @intFromFloat(@round(gf + (@as(f32, @floatFromInt(other.rgba.g)) - gf) * k)),
                    @intFromFloat(@round(bf + (@as(f32, @floatFromInt(other.rgba.b)) - bf) * k)),
                    @intFromFloat(@round(af + (@as(f32, @floatFromInt(other.rgba.a)) - af) * k)),
                );
            },
        }
    }

    /// Straight-alpha source-over compositing, in linear. `self` over `over`.
    pub fn blend(self: Color, over: Color) Color {
        const sa = self.lin[3];
        const oa = over.lin[3];
        const a_out = sa + oa * (1.0 - sa);
        if (a_out == 0) return fromLin(.{ 0, 0, 0, 0 });
        return fromLin(.{
            (self.lin[0] * sa + over.lin[0] * oa * (1.0 - sa)) / a_out,
            (self.lin[1] * sa + over.lin[1] * oa * (1.0 - sa)) / a_out,
            (self.lin[2] * sa + over.lin[2] * oa * (1.0 - sa)) / a_out,
            a_out,
        });
    }

    /// Componentwise multiply in linear (tint / sprite modulate).
    pub fn modulate(self: Color, other: Color) Color {
        return fromLin(.{
            self.lin[0] * other.lin[0],
            self.lin[1] * other.lin[1],
            self.lin[2] * other.lin[2],
            self.lin[3] * other.lin[3],
        });
    }

    /// Rotate hue by degrees (absorbed from math.hueShift).
    pub fn hueShift(self: Color, degrees: f32) Color {
        return self.withHue(@mod(self.hsva.h + degrees, 360));
    }

    // ---- Harmony (zero-alloc, fixed arrays) -----------------------------

    pub fn complementary(self: Color) Color {
        return self.hueShift(180);
    }
    pub fn triadic(self: Color) [2]Color {
        return .{ self.hueShift(120), self.hueShift(240) };
    }
    pub fn analogous(self: Color) [2]Color {
        return .{ self.hueShift(-30), self.hueShift(30) };
    }
    pub fn splitComplementary(self: Color) [2]Color {
        return .{ self.hueShift(150), self.hueShift(210) };
    }
    pub fn tetradic(self: Color) [3]Color {
        return .{ self.hueShift(90), self.hueShift(180), self.hueShift(270) };
    }

    // ---- Queries / relationships ----------------------------------------

    /// Rec. 709 relative luminance on LINEAR rgb.
    pub fn luminance(self: Color) f32 {
        return 0.2126 * self.lin[0] + 0.7152 * self.lin[1] + 0.0722 * self.lin[2];
    }
    /// WCAG contrast ratio, 1..21.
    pub fn contrastRatio(self: Color, other: Color) f32 {
        const l1 = @max(self.luminance(), other.luminance());
        const l2 = @min(self.luminance(), other.luminance());
        return (l1 + 0.05) / (l2 + 0.05);
    }
    /// Perceptual-ish distance (weighted HSV). Absorbed from math.distance, bug-fixed.
    pub fn distance(self: Color, other: Color) f32 {
        const diff = @abs(self.hsva.h - other.hsva.h);
        const hue_diff = @min(diff, 360 - diff);
        const hue_dist = hue_diff / 180;

        const ds = self.hsva.s - other.hsva.s;
        const dv = self.hsva.v - other.hsva.v;
        const dist_sq =
            (hue_dist * 0.35) * (hue_dist * 0.35) +
            (ds * 0.15) * (ds * 0.15) +
            (dv * 0.50) * (dv * 0.50);

        return @sqrt(dist_sq);
    }

    // ---- With-family (channel replacement) ------------------------------

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

    // ---- Classifier accessors -------------------------------------------

    pub fn hue(c: Color) Hue {
        return Hue.from(c);
    }
    pub fn tone(c: Color) Tone {
        return Tone.from(c);
    }
    pub fn saturation(c: Color) Saturation {
        return Saturation.from(c);
    }
    pub fn temperature(c: Color) Temperature {
        return Temperature.from(c);
    }

    pub fn eql(a: Color, b: Color) bool {
        return @as(u32, @bitCast(a.rgba)) == @as(u32, @bitCast(b.rgba));
    }
    // TODO: format function

    // ---- Private impl ----------------------------------------------------

    /// sRGB-encoded [0,1] -> linear-light [0,1]. IEC 61966-2-1 exact piecewise.
    fn srgbToLinear(c: f32) f32 {
        return if (c <= 0.04045) c / 12.92 else std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
    }
    /// linear-light [0,1] -> sRGB-encoded [0,1]. Exact piecewise inverse.
    fn linearToSrgb(c: f32) f32 {
        return if (c <= 0.0031308) 12.92 * c else 1.055 * std.math.pow(f32, c, 1.0 / 2.4) - 0.055;
    }

    /// Sign-safe cube root (guards NaN if a blend nudges a channel negative).
    fn cbrt(x: f32) f32 {
        return std.math.sign(x) * std.math.pow(f32, @abs(x), 1.0 / 3.0);
    }

    /// linear-light sRGB rgb -> OKLab (L, a, b). Ottosson / CSS Color 4.
    fn linearToOklab(rgb: [3]f32) [3]f32 {
        const r = rgb[0];
        const g = rgb[1];
        const bl = rgb[2];

        const l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl;
        const m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl;
        const s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl;

        const l_ = cbrt(l);
        const m_ = cbrt(m);
        const s_ = cbrt(s);

        return .{
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
        };
    }

    /// OKLab (L, a, b) -> linear-light sRGB rgb. Inverse of linearToOklab.
    fn oklabToLinear(lab: [3]f32) [3]f32 {
        const L = lab[0];
        const a = lab[1];
        const b = lab[2];

        const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
        const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
        const s_ = L - 0.0894841775 * a - 1.2914855480 * b;

        const l = l_ * l_ * l_;
        const m = m_ * m_ * m_;
        const s = s_ * s_ * s_;

        return .{
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        };
    }

    fn lerpByte(a: u8, b: u8, t: f32) u8 {
        const af: f32 = @floatFromInt(a);
        const bf: f32 = @floatFromInt(b);
        return @intFromFloat(@round(af + (bf - af) * t));
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
