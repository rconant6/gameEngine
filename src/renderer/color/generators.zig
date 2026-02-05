const std = @import("std");
const col = @import("Color.zig");
const Color = col.Color;
const types = @import("types.zig");
const TaggedColor = types.TaggedColor;
const Hue = types.Hue;
const Tone = types.Tone;
const Saturation = types.Saturation;
const Temperature = types.Temperature;
const lib = @import("library.zig");
const Library = lib.ColorLibrary;
const math = @import("math.zig");

// =============================================================================
// MARK: Library-Aware Matching
// =============================================================================
// These functions bridge arbitrary colors to the library by finding
// the closest matching TaggedColor within various constraints.

/// Finds the nearest library color across the entire library.
/// Always returns a result (never null). Use Library.findByColor for exact match.
pub fn closest(c: Color) TaggedColor {
    return internalClosest(c, Library.getAllColors()[0..]);
}

/// Finds the nearest library color within the same hue family.
/// Useful for staying within a color family (e.g., "keep me in the reds").
pub fn closestInHue(c: Color) TaggedColor {
    return internalClosest(c, Library.getHue(c.hue()));
}

/// Finds the nearest library color within the same hue AND tone.
/// Useful for finding a specific shade (e.g., "dark reds only").
pub fn closestInHueTone(c: Color) TaggedColor {
    return internalClosest(c, Library.getHueTone(c.hue(), c.tone()));
}

/// Finds the nearest library color within the same tone (any hue).
/// Useful for consistent lighting across different colored objects.
pub fn closestInTone(c: Color) TaggedColor {
    return internalClosest(c, Library.getTone(c.tone()));
}

/// Finds the nearest library color within the same saturation level (any hue/tone).
/// Useful for maintaining consistent vibrancy across a palette.
pub fn closestInSat(c: Color) TaggedColor {
    return internalClosest(c, Library.getSat(c.saturation()));
}

/// Finds the nearest library color with optional constraints.
/// Pass null for any parameter to ignore that constraint.
/// Example: snap(color, .red, null, .vivid) finds closest vivid red.
pub fn snap(c: Color, hue: ?Hue, tone: ?Tone, sat: ?Saturation) TaggedColor {
    // If all constraints are null, just do global closest
    if (hue == null and tone == null and sat == null) {
        return closest(c);
    }

    // Get the most constrained bucket we can
    if (hue) |h| {
        if (tone) |t| {
            if (sat) |s| {
                // All three: use getHueToneSat
                const bucket = Library.getHueToneSat(h, t, s);
                if (bucket.len > 0) return internalClosest(c, bucket);
            }
            // Hue + Tone
            const bucket = Library.getHueTone(h, t);
            if (bucket.len > 0) return internalClosest(c, bucket);
        }
        // Just Hue
        return internalClosest(c, Library.getHue(h));
    }

    if (tone) |t| {
        return internalClosest(c, Library.getTone(t));
    }

    if (sat) |s| {
        return internalClosest(c, Library.getSat(s));
    }

    return closest(c);
}

fn internalClosest(c: Color, list: []const TaggedColor) TaggedColor {
    std.debug.assert(list.len > 0);
    var min: f64 = std.math.inf(f64);
    var best: TaggedColor = list[0];

    for (list) |entry| {
        const dist = math.distance(entry.color, c);
        if (dist < min) {
            min = dist;
            best = entry;
        }
    }

    return best;
}

// =============================================================================
// MARK: Tone Navigation
// =============================================================================
// These functions find library colors that are lighter or darker than
// the input, staying within the same hue family.

/// Returns a library color one tone darker in the same hue.
/// Returns null if already at the deepest tone.
pub fn getShade(c: Color) ?TaggedColor {
    const current_tone = c.tone();
    if (current_tone == .deep) return null;

    const darker_tone: Tone = @enumFromInt(@intFromEnum(current_tone) - 1);
    const bucket = Library.getHueTone(c.hue(), darker_tone);
    if (bucket.len == 0) return null;

    return internalClosest(c, bucket);
}

/// Returns a library color one tone lighter in the same hue.
/// Returns null if already at the highest tone.
pub fn getTint(c: Color) ?TaggedColor {
    const current_tone = c.tone();
    if (current_tone == .high) return null;

    const lighter_tone: Tone = @enumFromInt(@intFromEnum(current_tone) + 1);
    const bucket = Library.getHueTone(c.hue(), lighter_tone);
    if (bucket.len == 0) return null;

    return internalClosest(c, bucket);
}

/// Returns all library colors darker than the input in the same hue.
/// Useful for building shadow ramps. Returns empty slice if at deepest tone.
pub fn getShades(c: Color) []const TaggedColor {
    const current_tone = c.tone();
    if (current_tone == .deep) return &[_]TaggedColor{};

    // Find the start of darker tones in the hue bucket
    const hue_bucket = Library.getHue(c.hue());
    var start: usize = 0;
    var end: usize = 0;
    var found = false;

    for (hue_bucket, 0..) |entry, i| {
        if (@intFromEnum(entry.tone) < @intFromEnum(current_tone)) {
            if (!found) {
                start = i;
                found = true;
            }
            end = i + 1;
        }
    }

    return if (found) hue_bucket[start..end] else &[_]TaggedColor{};
}

/// Returns all library colors lighter than the input in the same hue.
/// Useful for building highlight ramps. Returns empty slice if at highest tone.
pub fn getTints(c: Color) []const TaggedColor {
    const current_tone = c.tone();
    if (current_tone == .high) return &[_]TaggedColor{};

    const hue_bucket = Library.getHue(c.hue());
    var start: usize = 0;
    var end: usize = 0;
    var found = false;

    for (hue_bucket, 0..) |entry, i| {
        if (@intFromEnum(entry.tone) > @intFromEnum(current_tone)) {
            if (!found) {
                start = i;
                found = true;
            }
            end = i + 1;
        }
    }

    return if (found) hue_bucket[start..end] else &[_]TaggedColor{};
}

// =============================================================================
// MARK: Color Harmony (Hue-Based)
// =============================================================================
// Classic color theory schemes. These return computed Colors, not library
// lookups. Chain with closest() to snap results to library colors.

/// Returns the complementary color (180° opposite on the wheel).
/// High contrast pairing.
pub fn complement(c: Color) Color {
    return c.withHue(@mod(c.hsva.h + 180.0, 360.0));
}

/// Returns 3 analogous colors: [base - 30°, base, base + 30°].
/// Natural, harmonious combinations.
pub fn analogous(c: Color) [3]Color {
    return .{
        c.withHue(@mod(c.hsva.h + 330.0, 360.0)), // -30
        c,
        c.withHue(@mod(c.hsva.h + 30.0, 360.0)),
    };
}

/// Returns 3 triadic colors spaced 120° apart: [base, +120°, +240°].
/// Balanced, vibrant combinations.
pub fn triadic(c: Color) [3]Color {
    return .{
        c,
        c.withHue(@mod(c.hsva.h + 120.0, 360.0)),
        c.withHue(@mod(c.hsva.h + 240.0, 360.0)),
    };
}

/// Returns 3 split-complementary colors: [base, +150°, +210°].
/// Contrast without the harshness of direct complement.
pub fn splitComplementary(c: Color) [3]Color {
    return .{
        c,
        c.withHue(@mod(c.hsva.h + 150.0, 360.0)),
        c.withHue(@mod(c.hsva.h + 210.0, 360.0)),
    };
}

/// Returns 4 tetradic colors (rectangle): [base, +90°, +180°, +270°].
/// Rich, diverse palette.
pub fn tetradic(c: Color) [4]Color {
    return .{
        c,
        c.withHue(@mod(c.hsva.h + 90.0, 360.0)),
        c.withHue(@mod(c.hsva.h + 180.0, 360.0)),
        c.withHue(@mod(c.hsva.h + 270.0, 360.0)),
    };
}

/// Returns 4 square colors spaced 90° apart.
/// Same as tetradic for evenly-spaced schemes.
pub fn square(c: Color) [4]Color {
    return tetradic(c);
}

// =============================================================================
// MARK: Variation Functions (S/V Based)
// =============================================================================
// Generate ramps and variations by modifying saturation and value.

/// Generates a gradient between two colors using shortest hue path.
/// Interpolates H, S, V, and A.
pub fn gradient(from: Color, to: Color, comptime steps: usize) [steps]Color {
    var out: [steps]Color = undefined;

    if (steps == 0) return out;
    if (steps == 1) {
        out[0] = from;
        return out;
    }

    const last_index: f32 = @floatFromInt(steps - 1);

    // Calculate shortest path around hue wheel
    var h_diff = to.hsva.h - from.hsva.h;
    if (h_diff > 180.0) h_diff -= 360.0;
    if (h_diff < -180.0) h_diff += 360.0;

    inline for (0..steps) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / last_index;

        out[i] = Color.initHsva(
            @mod(from.hsva.h + (h_diff * t), 360.0),
            from.hsva.s + (to.hsva.s - from.hsva.s) * t,
            from.hsva.v + (to.hsva.v - from.hsva.v) * t,
            from.hsva.a + (to.hsva.a - from.hsva.a) * t,
        );
    }

    return out;
}

/// Generates tints (toward white): same hue, decreasing saturation, max value.
pub fn tints(c: Color, comptime steps: usize) [steps]Color {
    const white = Color.initHsva(c.hsva.h, 0.0, 1.0, c.hsva.a);
    return gradient(c, white, steps);
}

/// Generates shades (toward black): same hue, full saturation, decreasing value.
pub fn shades(c: Color, comptime steps: usize) [steps]Color {
    const black = Color.initHsva(c.hsva.h, c.hsva.s, 0.0, c.hsva.a);
    return gradient(c, black, steps);
}

/// Generates tones (toward gray): same hue, decreasing saturation, mid value.
pub fn tones(c: Color, comptime steps: usize) [steps]Color {
    const gray = Color.initHsva(c.hsva.h, 0.0, 0.5, c.hsva.a);
    return gradient(c, gray, steps);
}

/// Generates a monochromatic ramp: same hue, varying saturation and value.
/// Goes from dark/desaturated to bright/saturated.
pub fn monochromatic(c: Color, comptime steps: usize) [steps]Color {
    var out: [steps]Color = undefined;

    if (steps == 0) return out;
    if (steps == 1) {
        out[0] = c;
        return out;
    }

    const last_index: f32 = @floatFromInt(steps - 1);

    inline for (0..steps) |i| {
        const t: f32 = @as(f32, @floatFromInt(i)) / last_index;
        out[i] = Color.initHsva(
            c.hsva.h,
            0.1 + (0.9 * t), // saturation: 0.1 -> 1.0
            0.2 + (0.8 * t), // value: 0.2 -> 1.0
            c.hsva.a,
        );
    }

    return out;
}

// =============================================================================
// MARK: Utility Functions
// =============================================================================

/// Calculates perceived luminance using standard formula.
/// Returns 0.0 (black) to 1.0 (white).
/// Formula: 0.299*R + 0.587*G + 0.114*B
pub fn getLuminance(c: Color) f32 {
    const r: f32 = @as(f32, @floatFromInt(c.rgba.r)) / 255.0;
    const g: f32 = @as(f32, @floatFromInt(c.rgba.g)) / 255.0;
    const b: f32 = @as(f32, @floatFromInt(c.rgba.b)) / 255.0;
    return 0.299 * r + 0.587 * g + 0.114 * b;
}

/// Calculates WCAG contrast ratio between two colors.
/// Returns 1.0 (no contrast) to 21.0 (max contrast, black/white).
/// WCAG AA requires 4.5:1 for normal text, 3:1 for large text.
/// WCAG AAA requires 7:1 for normal text, 4.5:1 for large text.
pub fn getContrastRatio(a: Color, b: Color) f32 {
    const l1 = getLuminance(a);
    const l2 = getLuminance(b);

    const lighter = @max(l1, l2);
    const darker = @min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
}

/// Returns true if the color is in the warm range (reds, oranges, yellows).
/// Warm hues: 0-80° and 315-360°.
pub fn isWarm(c: Color) bool {
    if (c.hsva.s < 0.05) return false; // Grays are neutral
    const h = c.hsva.h;
    return (h >= 0.0 and h <= 80.0) or (h >= 315.0 and h <= 360.0);
}

/// Returns true if the color is in the cool range (greens, blues, purples).
/// Cool hues: 125-265°.
pub fn isCool(c: Color) bool {
    if (c.hsva.s < 0.05) return false; // Grays are neutral
    const h = c.hsva.h;
    return h >= 125.0 and h <= 265.0;
}

/// Inverts a color (RGB inversion: 255 - channel).
pub fn invert(c: Color) Color {
    return Color.initRgba(
        255 - c.rgba.r,
        255 - c.rgba.g,
        255 - c.rgba.b,
        c.rgba.a,
    );
}

/// Desaturates a color by the given amount (0.0 = no change, 1.0 = grayscale).
pub fn desaturate(c: Color, amount: f32) Color {
    const new_s = c.hsva.s * (1.0 - std.math.clamp(amount, 0.0, 1.0));
    return c.withSaturation(new_s);
}

/// Saturates a color by the given amount (0.0 = no change, 1.0 = full saturation).
pub fn saturate(c: Color, amount: f32) Color {
    const new_s = c.hsva.s + (1.0 - c.hsva.s) * std.math.clamp(amount, 0.0, 1.0);
    return c.withSaturation(new_s);
}

/// Lightens a color by the given amount (0.0 = no change, 1.0 = white).
pub fn lighten(c: Color, amount: f32) Color {
    const new_v = c.hsva.v + (1.0 - c.hsva.v) * std.math.clamp(amount, 0.0, 1.0);
    return c.withBrightness(new_v);
}

/// Darkens a color by the given amount (0.0 = no change, 1.0 = black).
pub fn darken(c: Color, amount: f32) Color {
    const new_v = c.hsva.v * (1.0 - std.math.clamp(amount, 0.0, 1.0));
    return c.withBrightness(new_v);
}
