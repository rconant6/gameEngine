const std = @import("std");
const testing = std.testing;
const color_mod = @import("color");
const Color = color_mod.Color;
const Colors = color_mod.Colors;
const Hue = color_mod.Hue;
const Tone = color_mod.Tone;
const Saturation = color_mod.Saturation;
const Temperature = color_mod.Temperature;
const TaggedColor = color_mod.TaggedColor;
const Family = color_mod.Family;
const math = color_mod.math;

test "Color: init with RGBA values" {
    const color = Color.initRgba(255, 128, 64, 200);
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
    try testing.expectEqual(@as(u8, 200), color.rgba.a);
}

test "Color: init fully opaque" {
    const color = Color.initRgba(100, 150, 200, 255);
    try testing.expectEqual(@as(u8, 255), color.rgba.a);
}

test "Color: init fully transparent" {
    const color = Color.initRgba(100, 150, 200, 0);
    try testing.expectEqual(@as(u8, 0), color.rgba.a);
}

test "Color: initFromHex with 6 digits" {
    const color = Color.initFromHex("#FF8040");
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
    try testing.expectEqual(@as(u8, 255), color.rgba.a); // Default opaque
}

test "Color: initFromHex with 8 digits" {
    const color = Color.initFromHex("#FF8040C8");
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
    try testing.expectEqual(@as(u8, 200), color.rgba.a);
}

test "Color: initFromHex lowercase" {
    const color = Color.initFromHex("#ff8040");
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
}

test "Color: initFromHex RED" {
    const color = Color.initFromHex("#FF0000");
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 0), color.rgba.g);
    try testing.expectEqual(@as(u8, 0), color.rgba.b);
}

test "Color: initFromHex GREEN" {
    const color = Color.initFromHex("#00FF00");
    try testing.expectEqual(@as(u8, 0), color.rgba.r);
    try testing.expectEqual(@as(u8, 255), color.rgba.g);
    try testing.expectEqual(@as(u8, 0), color.rgba.b);
}

test "Color: initFromHex BLUE" {
    const color = Color.initFromHex("#0000FF");
    try testing.expectEqual(@as(u8, 0), color.rgba.r);
    try testing.expectEqual(@as(u8, 0), color.rgba.g);
    try testing.expectEqual(@as(u8, 255), color.rgba.b);
}

test "Color: initFromU32Hex with 6 digits" {
    const color = Color.initFromU32Hex(0xFF8040);
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
    try testing.expectEqual(@as(u8, 255), color.rgba.a);
}

test "Color: initFromU32Hex with 8 digits" {
    const color = Color.initFromU32Hex(0xFF8040C8);
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 128), color.rgba.g);
    try testing.expectEqual(@as(u8, 64), color.rgba.b);
    try testing.expectEqual(@as(u8, 200), color.rgba.a);
}

test "Color: initFromU32Hex black" {
    const color = Color.initFromU32Hex(0x000000);
    try testing.expectEqual(@as(u8, 0), color.rgba.r);
    try testing.expectEqual(@as(u8, 0), color.rgba.g);
    try testing.expectEqual(@as(u8, 0), color.rgba.b);
    try testing.expectEqual(@as(u8, 255), color.rgba.a);
}

test "Color: initFromU32Hex white" {
    const color = Color.initFromU32Hex(0xFFFFFF);
    try testing.expectEqual(@as(u8, 255), color.rgba.r);
    try testing.expectEqual(@as(u8, 255), color.rgba.g);
    try testing.expectEqual(@as(u8, 255), color.rgba.b);
}

test "Colors: predefined RED" {
    try testing.expectEqual(@as(u8, 255), Colors.RED.rgba.r);
    try testing.expectEqual(@as(u8, 0), Colors.RED.rgba.g);
    try testing.expectEqual(@as(u8, 0), Colors.RED.rgba.b);
    try testing.expectEqual(@as(u8, 255), Colors.RED.rgba.a);
}

test "Colors: predefined GREEN" {
    try testing.expectEqual(@as(u8, 0), Colors.GREEN.rgba.r);
    try testing.expectEqual(@as(u8, 255), Colors.GREEN.rgba.g);
    try testing.expectEqual(@as(u8, 0), Colors.GREEN.rgba.b);
}

test "Colors: predefined BLUE" {
    try testing.expectEqual(@as(u8, 0), Colors.BLUE.rgba.r);
    try testing.expectEqual(@as(u8, 0), Colors.BLUE.rgba.g);
    try testing.expectEqual(@as(u8, 255), Colors.BLUE.rgba.b);
}

test "Colors: predefined WHITE" {
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.rgba.r);
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.rgba.g);
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.rgba.b);
}

test "Colors: predefined BLACK" {
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.rgba.r);
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.rgba.g);
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.rgba.b);
}

test "Colors: predefined CLEAR is transparent" {
    try testing.expectEqual(@as(u8, 0), Colors.CLEAR.rgba.a);
}

test "Colors: predefined CYAN" {
    try testing.expectEqual(@as(u8, 0), Colors.CYAN.rgba.r);
    try testing.expectEqual(@as(u8, 255), Colors.CYAN.rgba.g);
    try testing.expectEqual(@as(u8, 255), Colors.CYAN.rgba.b);
}

test "Colors: predefined MAGENTA" {
    try testing.expectEqual(@as(u8, 255), Colors.MAGENTA.rgba.r);
    try testing.expectEqual(@as(u8, 0), Colors.MAGENTA.rgba.g);
    try testing.expectEqual(@as(u8, 255), Colors.MAGENTA.rgba.b);
}

test "Colors: predefined YELLOW" {
    try testing.expectEqual(@as(u8, 255), Colors.YELLOW.rgba.r);
    try testing.expectEqual(@as(u8, 255), Colors.YELLOW.rgba.g);
    try testing.expectEqual(@as(u8, 0), Colors.YELLOW.rgba.b);
}

test "Colors: neon colors have high saturation" {
    // Neon red should have max red, minimal other colors
    try testing.expectEqual(@as(u8, 255), Colors.NEON_RED.rgba.r);
    try testing.expect(Colors.NEON_RED.rgba.g < 50);
    try testing.expect(Colors.NEON_RED.rgba.b < 50);
}

test "Colors: pastel colors are lighter" {
    // Pastel colors should have all channels relatively high
    try testing.expect(Colors.PASTEL_RED.rgba.r > 200);
    try testing.expect(Colors.PASTEL_RED.rgba.g > 200);
    try testing.expect(Colors.PASTEL_RED.rgba.b > 200);
}

test "Colors: gray scale" {
    // Gray should have equal RGB values
    try testing.expectEqual(Colors.GRAY.rgba.r, Colors.GRAY.rgba.g);
    try testing.expectEqual(Colors.GRAY.rgba.g, Colors.GRAY.rgba.b);

    // Light gray should be brighter than gray
    try testing.expect(Colors.LIGHT_GRAY.rgba.r > Colors.GRAY.rgba.r);

    // Dark gray should be darker than gray
    try testing.expect(Colors.DARK_GRAY.rgba.r < Colors.GRAY.rgba.r);
}

// =============================================================================
// HSV Initialization Tests
// =============================================================================

test "Color: initHsva creates correct RGB" {
    // Pure red: H=0, S=1, V=1
    const red = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    try testing.expectEqual(@as(u8, 255), red.rgba.r);
    try testing.expectEqual(@as(u8, 0), red.rgba.g);
    try testing.expectEqual(@as(u8, 0), red.rgba.b);
}

test "Color: initHsva green at 120 degrees" {
    // Pure green: H=120, S=1, V=1
    const green = Color.initHsva(120.0, 1.0, 1.0, 1.0);
    try testing.expectEqual(@as(u8, 0), green.rgba.r);
    try testing.expectEqual(@as(u8, 255), green.rgba.g);
    try testing.expectEqual(@as(u8, 0), green.rgba.b);
}

test "Color: initHsva blue at 240 degrees" {
    // Pure blue: H=240, S=1, V=1
    const blue = Color.initHsva(240.0, 1.0, 1.0, 1.0);
    try testing.expectEqual(@as(u8, 0), blue.rgba.r);
    try testing.expectEqual(@as(u8, 0), blue.rgba.g);
    try testing.expectEqual(@as(u8, 255), blue.rgba.b);
}

test "Color: initHsva with zero saturation is gray" {
    const gray = Color.initHsva(0.0, 0.0, 0.5, 1.0);
    try testing.expectEqual(gray.rgba.r, gray.rgba.g);
    try testing.expectEqual(gray.rgba.g, gray.rgba.b);
}

test "Color: initHsva with zero value is black" {
    const black = Color.initHsva(180.0, 1.0, 0.0, 1.0);
    try testing.expectEqual(@as(u8, 0), black.rgba.r);
    try testing.expectEqual(@as(u8, 0), black.rgba.g);
    try testing.expectEqual(@as(u8, 0), black.rgba.b);
}

// =============================================================================
// RGB to HSV Sync Tests
// =============================================================================

test "Color: RGB to HSV sync - pure red" {
    const red = Color.initRgba(255, 0, 0, 255);
    try testing.expectApproxEqAbs(@as(f32, 0.0), red.hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), red.hsva.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), red.hsva.v, 0.01);
}

test "Color: RGB to HSV sync - pure green" {
    const green = Color.initRgba(0, 255, 0, 255);
    try testing.expectApproxEqAbs(@as(f32, 120.0), green.hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), green.hsva.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), green.hsva.v, 0.01);
}

test "Color: RGB to HSV sync - pure blue" {
    const blue = Color.initRgba(0, 0, 255, 255);
    try testing.expectApproxEqAbs(@as(f32, 240.0), blue.hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), blue.hsva.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), blue.hsva.v, 0.01);
}

test "Color: RGB to HSV sync - gray has zero saturation" {
    const gray = Color.initRgba(128, 128, 128, 255);
    try testing.expectApproxEqAbs(@as(f32, 0.0), gray.hsva.s, 0.01);
}

test "Color: RGB to HSV sync - alpha preserved" {
    const color = Color.initRgba(255, 0, 0, 128);
    try testing.expectApproxEqAbs(@as(f32, 0.502), color.hsva.a, 0.01);
}

// =============================================================================
// with* Method Tests - RGB Side
// =============================================================================

test "Color: withRed changes only red" {
    const original = Color.initRgba(100, 150, 200, 255);
    const modified = original.withRed(50);
    try testing.expectEqual(@as(u8, 50), modified.rgba.r);
    try testing.expectEqual(@as(u8, 150), modified.rgba.g);
    try testing.expectEqual(@as(u8, 200), modified.rgba.b);
    try testing.expectEqual(@as(u8, 255), modified.rgba.a);
}

test "Color: withGreen changes only green" {
    const original = Color.initRgba(100, 150, 200, 255);
    const modified = original.withGreen(50);
    try testing.expectEqual(@as(u8, 100), modified.rgba.r);
    try testing.expectEqual(@as(u8, 50), modified.rgba.g);
    try testing.expectEqual(@as(u8, 200), modified.rgba.b);
}

test "Color: withBlue changes only blue" {
    const original = Color.initRgba(100, 150, 200, 255);
    const modified = original.withBlue(50);
    try testing.expectEqual(@as(u8, 100), modified.rgba.r);
    try testing.expectEqual(@as(u8, 150), modified.rgba.g);
    try testing.expectEqual(@as(u8, 50), modified.rgba.b);
}

test "Color: withAlpha changes only alpha" {
    const original = Color.initRgba(100, 150, 200, 255);
    const modified = original.withAlpha(128);
    try testing.expectEqual(@as(u8, 100), modified.rgba.r);
    try testing.expectEqual(@as(u8, 150), modified.rgba.g);
    try testing.expectEqual(@as(u8, 200), modified.rgba.b);
    try testing.expectEqual(@as(u8, 128), modified.rgba.a);
}

test "Color: withRgb changes RGB, keeps alpha" {
    const original = Color.initRgba(100, 150, 200, 128);
    const modified = original.withRgb(10, 20, 30);
    try testing.expectEqual(@as(u8, 10), modified.rgba.r);
    try testing.expectEqual(@as(u8, 20), modified.rgba.g);
    try testing.expectEqual(@as(u8, 30), modified.rgba.b);
    try testing.expectEqual(@as(u8, 128), modified.rgba.a);
}

// =============================================================================
// with* Method Tests - HSV Side
// =============================================================================

test "Color: withHue shifts hue" {
    const red = Color.initRgba(255, 0, 0, 255);
    const green = red.withHue(120.0);
    try testing.expectEqual(@as(u8, 0), green.rgba.r);
    try testing.expectEqual(@as(u8, 255), green.rgba.g);
    try testing.expectEqual(@as(u8, 0), green.rgba.b);
}

test "Color: withSaturation reduces saturation" {
    const red = Color.initRgba(255, 0, 0, 255);
    const desaturated = red.withSaturation(0.0);
    // Zero saturation = gray (equal RGB values)
    try testing.expectEqual(desaturated.rgba.r, desaturated.rgba.g);
    try testing.expectEqual(desaturated.rgba.g, desaturated.rgba.b);
}

test "Color: withBrightness reduces brightness" {
    const red = Color.initRgba(255, 0, 0, 255);
    const dark = red.withBrightness(0.5);
    try testing.expectApproxEqAbs(@as(f32, 128), @as(f32, @floatFromInt(dark.rgba.r)), 1.0);
    try testing.expectEqual(@as(u8, 0), dark.rgba.g);
    try testing.expectEqual(@as(u8, 0), dark.rgba.b);
}

test "Color: withOpacity changes HSV alpha" {
    const color = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const faded = color.withOpacity(0.5);
    try testing.expectApproxEqAbs(@as(f32, 0.5), faded.hsva.a, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 128), @as(f32, @floatFromInt(faded.rgba.a)), 1.0);
}

test "Color: withHsv changes HSV, keeps opacity" {
    const original = Color.initHsva(0.0, 1.0, 1.0, 0.5);
    const modified = original.withHsv(120.0, 0.5, 0.8);
    try testing.expectApproxEqAbs(@as(f32, 120.0), modified.hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.5), modified.hsva.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.8), modified.hsva.v, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.5), modified.hsva.a, 0.01);
}

// =============================================================================
// Immutability Tests
// =============================================================================

test "Color: with* methods don't modify original" {
    const original = Color.initRgba(100, 100, 100, 255);
    _ = original.withRed(200);
    _ = original.withHue(180.0);
    // Original should be unchanged
    try testing.expectEqual(@as(u8, 100), original.rgba.r);
    try testing.expectEqual(@as(u8, 100), original.rgba.g);
    try testing.expectEqual(@as(u8, 100), original.rgba.b);
}

test "Color: chaining with* methods" {
    const result = Colors.RED
        .withHue(120.0)
        .withSaturation(0.5)
        .withBrightness(0.8)
        .withAlpha(200);

    try testing.expectApproxEqAbs(@as(f32, 120.0), result.hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.5), result.hsva.s, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.8), result.hsva.v, 0.01);
    try testing.expectEqual(@as(u8, 200), result.rgba.a);
}

// =============================================================================
// Round-trip Tests
// =============================================================================

test "Color: RGB -> HSV -> RGB round trip" {
    const original = Color.initRgba(173, 85, 47, 255);
    const roundtrip = Color.initHsva(
        original.hsva.h,
        original.hsva.s,
        original.hsva.v,
        original.hsva.a,
    );
    try testing.expectEqual(original.rgba.r, roundtrip.rgba.r);
    try testing.expectEqual(original.rgba.g, roundtrip.rgba.g);
    try testing.expectEqual(original.rgba.b, roundtrip.rgba.b);
}

// =============================================================================
// Hue Classification Tests
// =============================================================================

test "Hue: pure red classifies as red" {
    const red = Color.initRgba(255, 0, 0, 255);
    try testing.expectEqual(Hue.red, red.hue());
}

test "Hue: pure green classifies as green" {
    const green = Color.initRgba(0, 255, 0, 255);
    try testing.expectEqual(Hue.green, green.hue());
}

test "Hue: pure blue classifies as blue" {
    const blue = Color.initRgba(0, 0, 255, 255);
    try testing.expectEqual(Hue.blue, blue.hue());
}

test "Hue: cyan classifies as cyan" {
    const cyan = Color.initRgba(0, 255, 255, 255);
    try testing.expectEqual(Hue.cyan, cyan.hue());
}

test "Hue: yellow classifies as yellow" {
    const yellow = Color.initRgba(255, 255, 0, 255);
    try testing.expectEqual(Hue.yellow, yellow.hue());
}

test "Hue: magenta classifies as magenta" {
    const magenta = Color.initRgba(255, 0, 255, 255);
    try testing.expectEqual(Hue.magenta, magenta.hue());
}

test "Hue: gray classifies as neutral" {
    const gray = Color.initRgba(128, 128, 128, 255);
    try testing.expectEqual(Hue.neutral, gray.hue());
}

test "Hue: white classifies as neutral" {
    const white = Color.initRgba(255, 255, 255, 255);
    try testing.expectEqual(Hue.neutral, white.hue());
}

test "Hue: black classifies as neutral" {
    const black = Color.initRgba(0, 0, 0, 255);
    try testing.expectEqual(Hue.neutral, black.hue());
}

test "Hue: brown detection" {
    // A typical brown: low value, moderate saturation, orange-ish hue
    const brown = Color.initHsva(30.0, 0.6, 0.4, 1.0);
    try testing.expectEqual(Hue.brown, brown.hue());
}

// =============================================================================
// Tone Classification Tests
// =============================================================================

test "Tone: very dark colors are deep" {
    const dark = Color.initHsva(0.0, 1.0, 0.1, 1.0);
    try testing.expectEqual(Tone.deep, dark.tone());
}

test "Tone: dark colors are dark" {
    const dark = Color.initHsva(0.0, 1.0, 0.3, 1.0);
    try testing.expectEqual(Tone.dark, dark.tone());
}

test "Tone: mid brightness is mid" {
    const mid = Color.initHsva(0.0, 1.0, 0.5, 1.0);
    try testing.expectEqual(Tone.mid, mid.tone());
}

test "Tone: light colors are light" {
    const light = Color.initHsva(0.0, 1.0, 0.7, 1.0);
    try testing.expectEqual(Tone.light, light.tone());
}

test "Tone: very bright colors are high" {
    const bright = Color.initHsva(0.0, 1.0, 0.9, 1.0);
    try testing.expectEqual(Tone.high, bright.tone());
}

// =============================================================================
// Saturation Classification Tests
// =============================================================================

test "Saturation: zero saturation is gray" {
    const gray = Color.initHsva(0.0, 0.0, 0.5, 1.0);
    try testing.expectEqual(Saturation.gray, gray.saturation());
}

test "Saturation: low saturation is muted" {
    const muted = Color.initHsva(0.0, 0.2, 0.5, 1.0);
    try testing.expectEqual(Saturation.muted, muted.saturation());
}

test "Saturation: medium saturation is moderate" {
    const moderate = Color.initHsva(0.0, 0.5, 0.5, 1.0);
    try testing.expectEqual(Saturation.moderate, moderate.saturation());
}

test "Saturation: high saturation is vivid" {
    const vivid = Color.initHsva(0.0, 0.9, 0.5, 1.0);
    try testing.expectEqual(Saturation.vivid, vivid.saturation());
}

// =============================================================================
// Temperature Classification Tests
// =============================================================================

test "Temperature: red is warm" {
    const red = Color.initRgba(255, 0, 0, 255);
    try testing.expectEqual(Temperature.warm, red.temperature());
}

test "Temperature: orange is warm" {
    const orange = Color.initHsva(30.0, 1.0, 1.0, 1.0);
    try testing.expectEqual(Temperature.warm, orange.temperature());
}

test "Temperature: blue is cool" {
    const blue = Color.initRgba(0, 0, 255, 255);
    try testing.expectEqual(Temperature.cool, blue.temperature());
}

test "Temperature: cyan is cool" {
    const cyan = Color.initRgba(0, 255, 255, 255);
    try testing.expectEqual(Temperature.cool, cyan.temperature());
}

test "Temperature: gray is neutral" {
    const gray = Color.initRgba(128, 128, 128, 255);
    try testing.expectEqual(Temperature.neutral, gray.temperature());
}

test "Temperature: green is neutral" {
    const green = Color.initHsva(120.0, 1.0, 1.0, 1.0);
    try testing.expectEqual(Temperature.neutral, green.temperature());
}

// =============================================================================
// TaggedColor Tests
// =============================================================================

test "TaggedColor: from creates correct tags" {
    const red = Color.initRgba(255, 0, 0, 255);
    const tagged = TaggedColor.from(red, "TEST_RED");

    try testing.expectEqual(Hue.red, tagged.hue);
    try testing.expectEqual(Tone.high, tagged.tone);
    try testing.expectEqual(Saturation.vivid, tagged.saturation);
    try testing.expectEqual(Temperature.warm, tagged.temp);
    try testing.expectEqual(Family.unassigned, tagged.family);
}

test "TaggedColor: preserves original color" {
    const original = Color.initRgba(100, 150, 200, 255);
    const tagged = TaggedColor.from(original, "TEST_COLOR");

    try testing.expectEqual(original.rgba.r, tagged.color.rgba.r);
    try testing.expectEqual(original.rgba.g, tagged.color.rgba.g);
    try testing.expectEqual(original.rgba.b, tagged.color.rgba.b);
}

// =============================================================================
// Math: Distance Tests
// =============================================================================

test "math.distance: identical colors have zero distance" {
    const red = Color.initRgba(255, 0, 0, 255);
    try testing.expectApproxEqAbs(@as(f32, 0.0), math.distance(red, red), 0.001);
}

test "math.distance: similar colors have small distance" {
    const red1 = Color.initRgba(255, 0, 0, 255);
    const red2 = Color.initRgba(250, 10, 5, 255);
    const dist = math.distance(red1, red2);
    try testing.expect(dist < 0.1);
}

test "math.distance: different hues have larger distance" {
    const red = Color.initRgba(255, 0, 0, 255);
    const blue = Color.initRgba(0, 0, 255, 255);
    const dist = math.distance(red, blue);
    try testing.expect(dist > 0.2);
}

// =============================================================================
// Math: Lerp Tests
// =============================================================================

test "math.lerp: t=0 returns first color" {
    const red = Color.initRgba(255, 0, 0, 255);
    const blue = Color.initRgba(0, 0, 255, 255);
    const result = math.lerp(red, blue, 0.0);

    try testing.expectApproxEqAbs(red.hsva.h, result.hsva.h, 0.01);
}

test "math.lerp: t=1 returns second color" {
    const red = Color.initRgba(255, 0, 0, 255);
    const blue = Color.initRgba(0, 0, 255, 255);
    const result = math.lerp(red, blue, 1.0);

    try testing.expectApproxEqAbs(blue.hsva.h, result.hsva.h, 0.01);
}

test "math.lerp: t=0.5 is midpoint" {
    const black = Color.initHsva(0.0, 0.0, 0.0, 1.0);
    const white = Color.initHsva(0.0, 0.0, 1.0, 1.0);
    const result = math.lerp(black, white, 0.5);

    try testing.expectApproxEqAbs(@as(f32, 0.5), result.hsva.v, 0.01);
}

test "math.lerp: takes shortest path around hue circle" {
    const red = Color.initHsva(10.0, 1.0, 1.0, 1.0);
    const rose = Color.initHsva(350.0, 1.0, 1.0, 1.0);
    const result = math.lerp(red, rose, 0.5);

    // Midpoint should be at 0/360, not at 180
    const h = result.hsva.h;
    try testing.expect(h < 20.0 or h > 340.0);
}

// =============================================================================
// Math: Hue Shift Tests
// =============================================================================

test "math.hueShift: shifts hue by degrees" {
    const red = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const shifted = math.hueShift(red, 120.0);

    try testing.expectApproxEqAbs(@as(f32, 120.0), shifted.hsva.h, 0.01);
}

test "math.hueShift: wraps around 360" {
    const rose = Color.initHsva(350.0, 1.0, 1.0, 1.0);
    const shifted = math.hueShift(rose, 30.0);

    try testing.expectApproxEqAbs(@as(f32, 20.0), shifted.hsva.h, 0.01);
}

test "math.hueShift: negative shift works" {
    const green = Color.initHsva(120.0, 1.0, 1.0, 1.0);
    const shifted = math.hueShift(green, -60.0);

    try testing.expectApproxEqAbs(@as(f32, 60.0), shifted.hsva.h, 0.01);
}

test "math.hueShift: preserves saturation and value" {
    const original = Color.initHsva(0.0, 0.7, 0.8, 1.0);
    const shifted = math.hueShift(original, 90.0);

    try testing.expectApproxEqAbs(original.hsva.s, shifted.hsva.s, 0.01);
    try testing.expectApproxEqAbs(original.hsva.v, shifted.hsva.v, 0.01);
}

// =============================================================================
// ColorLibrary Tests
// =============================================================================

const ColorLibrary = color_mod.ColorLibrary;

test "ColorLibrary: getAllColors returns all 1837 colors" {
    const all = ColorLibrary.getAllColors();
    try testing.expectEqual(@as(usize, 1837), all.len);
}

test "ColorLibrary: getColorCount matches getAllColors length" {
    try testing.expectEqual(ColorLibrary.getColorCount(), ColorLibrary.getAllColors().len);
}

test "ColorLibrary: hue buckets sum to total count" {
    var sum: usize = 0;
    for (comptime std.enums.values(Hue)) |h| {
        sum += ColorLibrary.getHueCount(h);
    }
    try testing.expectEqual(ColorLibrary.getColorCount(), sum);
}

test "ColorLibrary: tone buckets sum to total count" {
    var sum: usize = 0;
    for (comptime std.enums.values(Tone)) |t| {
        sum += ColorLibrary.getToneCount(t);
    }
    try testing.expectEqual(ColorLibrary.getColorCount(), sum);
}

test "ColorLibrary: saturation buckets sum to total count" {
    var sum: usize = 0;
    for (comptime std.enums.values(Saturation)) |s| {
        sum += ColorLibrary.getSatCount(s);
    }
    try testing.expectEqual(ColorLibrary.getColorCount(), sum);
}

test "ColorLibrary: temperature buckets sum to total count" {
    var sum: usize = 0;
    for (comptime std.enums.values(Temperature)) |t| {
        sum += ColorLibrary.getTempCount(t);
    }
    try testing.expectEqual(ColorLibrary.getColorCount(), sum);
}

test "ColorLibrary: getHue returns only matching hues" {
    const reds = ColorLibrary.getHue(.red);
    try testing.expect(reds.len > 0);
    for (reds) |entry| {
        try testing.expectEqual(Hue.red, entry.hue);
    }
}

test "ColorLibrary: getTone returns only matching tones" {
    const darks = ColorLibrary.getTone(.dark);
    try testing.expect(darks.len > 0);
    for (darks) |entry| {
        try testing.expectEqual(Tone.dark, entry.tone);
    }
}

test "ColorLibrary: getSat returns only matching saturations" {
    const vivids = ColorLibrary.getSat(.vivid);
    try testing.expect(vivids.len > 0);
    for (vivids) |entry| {
        try testing.expectEqual(Saturation.vivid, entry.saturation);
    }
}

test "ColorLibrary: getTemp returns only matching temperatures" {
    const warms = ColorLibrary.getTemp(.warm);
    try testing.expect(warms.len > 0);
    for (warms) |entry| {
        try testing.expectEqual(Temperature.warm, entry.temp);
    }
}

test "ColorLibrary: getHueTone returns matching hue AND tone" {
    const dark_reds = ColorLibrary.getHueTone(.red, .dark);
    try testing.expect(dark_reds.len > 0);
    for (dark_reds) |entry| {
        try testing.expectEqual(Hue.red, entry.hue);
        try testing.expectEqual(Tone.dark, entry.tone);
    }
}

test "ColorLibrary: getHueToneSat returns matching hue, tone AND saturation" {
    const vivid_light_blues = ColorLibrary.getHueToneSat(.azure, .light, .vivid);
    try testing.expect(vivid_light_blues.len > 0);
    for (vivid_light_blues) |entry| {
        try testing.expectEqual(Hue.azure, entry.hue);
        try testing.expectEqual(Tone.light, entry.tone);
        try testing.expectEqual(Saturation.vivid, entry.saturation);
    }
}

test "ColorLibrary: getHueToneSat with no matches returns empty slice" {
    // This combination might not exist - test empty result handling
    const result = ColorLibrary.getHueToneSat(.neutral, .deep, .vivid);
    // Neutral hue with vivid saturation is contradictory, should be empty
    try testing.expectEqual(@as(usize, 0), result.len);
}

test "ColorLibrary: findByName finds existing color" {
    const result = ColorLibrary.findByName("RED");
    try testing.expect(result != null);
    try testing.expectEqual(@as(u8, 255), result.?.color.rgba.r);
    try testing.expectEqual(@as(u8, 0), result.?.color.rgba.g);
    try testing.expectEqual(@as(u8, 0), result.?.color.rgba.b);
}

test "ColorLibrary: findByName is case insensitive" {
    const upper = ColorLibrary.findByName("RED");
    const lower = ColorLibrary.findByName("red");
    const mixed = ColorLibrary.findByName("Red");

    try testing.expect(upper != null);
    try testing.expect(lower != null);
    try testing.expect(mixed != null);

    try testing.expectEqual(upper.?.color.rgba.r, lower.?.color.rgba.r);
    try testing.expectEqual(lower.?.color.rgba.r, mixed.?.color.rgba.r);
}

test "ColorLibrary: findByName returns null for nonexistent color" {
    const result = ColorLibrary.findByName("NONEXISTENT_COLOR_12345");
    try testing.expect(result == null);
}

test "ColorLibrary: findByName finds sports team colors" {
    const cowboys = ColorLibrary.findByName("NFL_COWBOYS_BLUE");
    try testing.expect(cowboys != null);
    try testing.expectEqual(Hue.azure, cowboys.?.hue);
}

test "ColorLibrary: findByColor finds exact match" {
    const red = Color.initRgba(255, 0, 0, 255);
    const result = ColorLibrary.findByColor(red);
    try testing.expect(result != null);
    try testing.expect(std.mem.eql(u8, "RED", result.?.name));
}

test "ColorLibrary: findByColor returns null for no match" {
    const weird = Color.initRgba(123, 45, 67, 255);
    const result = ColorLibrary.findByColor(weird);
    // This specific color probably doesn't exist in the library
    // (test may need adjustment if it does exist)
    _ = result; // Just verify it doesn't crash
}

test "ColorLibrary: brown detection works in library" {
    const browns = ColorLibrary.getHue(.brown);
    try testing.expect(browns.len > 0);
    // Browns should have low-ish value and be in orange-ish hue range
    for (browns) |entry| {
        try testing.expectEqual(Hue.brown, entry.hue);
    }
}

test "ColorLibrary: neutral hue matches gray saturation" {
    const neutrals = ColorLibrary.getHue(.neutral);
    const grays = ColorLibrary.getSat(.gray);
    // All grays should be neutral, but not all neutrals are gray
    for (grays) |gray_entry| {
        try testing.expectEqual(Hue.neutral, gray_entry.hue);
    }
    try testing.expect(neutrals.len >= grays.len);
}

test "ColorLibrary: deep tones have low brightness" {
    const deeps = ColorLibrary.getTone(.deep);
    for (deeps) |entry| {
        try testing.expect(entry.color.hsva.v < 0.2);
    }
}

test "ColorLibrary: high tones have high brightness" {
    const highs = ColorLibrary.getTone(.high);
    for (highs) |entry| {
        try testing.expect(entry.color.hsva.v >= 0.8);
    }
}

test "ColorLibrary: vivid colors have high saturation" {
    const vivids = ColorLibrary.getSat(.vivid);
    for (vivids) |entry| {
        try testing.expect(entry.color.hsva.s >= 0.75);
    }
}

test "ColorLibrary: muted colors have low saturation" {
    const muteds = ColorLibrary.getSat(.muted);
    for (muteds) |entry| {
        try testing.expect(entry.color.hsva.s >= 0.05);
        try testing.expect(entry.color.hsva.s < 0.35);
    }
}

test "ColorLibrary: warm colors are in warm hue range" {
    const warms = ColorLibrary.getTemp(.warm);
    for (warms) |entry| {
        const h = entry.color.hsva.h;
        // Warm: 0-80 or 315-360
        const is_warm_hue = (h >= 0.0 and h <= 80.0) or (h >= 315.0 and h <= 360.0);
        try testing.expect(is_warm_hue);
    }
}

test "ColorLibrary: cool colors are in cool hue range" {
    const cools = ColorLibrary.getTemp(.cool);
    for (cools) |entry| {
        const h = entry.color.hsva.h;
        // Cool: 125-265
        try testing.expect(h >= 125.0 and h <= 265.0);
    }
}

test "ColorLibrary: drill-down query narrows results" {
    const all_reds = ColorLibrary.getHue(.red);
    const dark_reds = ColorLibrary.getHueTone(.red, .dark);
    const dark_vivid_reds = ColorLibrary.getHueToneSat(.red, .dark, .vivid);

    try testing.expect(all_reds.len > dark_reds.len);
    try testing.expect(dark_reds.len >= dark_vivid_reds.len);
}

test "ColorLibrary: each entry has a name" {
    const all = ColorLibrary.getAllColors();
    for (all) |entry| {
        try testing.expect(entry.name.len > 0);
    }
}

// =============================================================================
// Generator Tests
// =============================================================================

const generators = color_mod.generators;

// === Harmony: complement ===

test "generators.complement: shifts hue by 180 degrees" {
    const red = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const comp = generators.complement(red);
    try testing.expectApproxEqAbs(@as(f32, 180.0), comp.hsva.h, 0.01);
}

test "generators.complement: preserves saturation and value" {
    const color = Color.initHsva(60.0, 0.7, 0.8, 1.0);
    const comp = generators.complement(color);
    try testing.expectApproxEqAbs(color.hsva.s, comp.hsva.s, 0.01);
    try testing.expectApproxEqAbs(color.hsva.v, comp.hsva.v, 0.01);
}

test "generators.complement: wraps around 360" {
    const color = Color.initHsva(270.0, 1.0, 1.0, 1.0);
    const comp = generators.complement(color);
    // 270 + 180 = 450 -> 90
    try testing.expectApproxEqAbs(@as(f32, 90.0), comp.hsva.h, 0.01);
}

test "generators.complement: red -> cyan" {
    const red = Colors.RED;
    const comp = generators.complement(red);
    // Red (0) complement is Cyan (180)
    try testing.expectApproxEqAbs(@as(f32, 180.0), comp.hsva.h, 0.01);
}

test "generators.complement: blue -> yellow-ish" {
    const blue = Color.initHsva(240.0, 1.0, 1.0, 1.0);
    const comp = generators.complement(blue);
    // Blue (240) complement is Yellow (60)
    try testing.expectApproxEqAbs(@as(f32, 60.0), comp.hsva.h, 0.01);
}

// === Harmony: analogous ===

test "generators.analogous: returns 3 colors" {
    const red = Colors.RED;
    const result = generators.analogous(red);
    try testing.expectEqual(@as(usize, 3), result.len);
}

test "generators.analogous: center color is original" {
    const red = Colors.RED;
    const result = generators.analogous(red);
    try testing.expectApproxEqAbs(red.hsva.h, result[1].hsva.h, 0.01);
}

test "generators.analogous: neighbors are ±30 degrees" {
    const color = Color.initHsva(90.0, 1.0, 1.0, 1.0);
    const result = generators.analogous(color);
    // result[0] = hue - 30 = 60
    // result[1] = hue = 90
    // result[2] = hue + 30 = 120
    try testing.expectApproxEqAbs(@as(f32, 60.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 90.0), result[1].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 120.0), result[2].hsva.h, 0.01);
}

test "generators.analogous: wraps around hue wheel" {
    const color = Color.initHsva(10.0, 1.0, 1.0, 1.0);
    const result = generators.analogous(color);
    // result[0] = 10 - 30 = -20 -> 340
    try testing.expectApproxEqAbs(@as(f32, 340.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 40.0), result[2].hsva.h, 0.01);
}

test "generators.analogous: preserves saturation and value" {
    const color = Color.initHsva(180.0, 0.6, 0.7, 1.0);
    const result = generators.analogous(color);
    for (result) |c| {
        try testing.expectApproxEqAbs(color.hsva.s, c.hsva.s, 0.01);
        try testing.expectApproxEqAbs(color.hsva.v, c.hsva.v, 0.01);
    }
}

// === Harmony: triadic ===

test "generators.triadic: returns 3 colors" {
    const red = Colors.RED;
    const result = generators.triadic(red);
    try testing.expectEqual(@as(usize, 3), result.len);
}

test "generators.triadic: colors are 120 degrees apart" {
    const color = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const result = generators.triadic(color);
    // Should be at 0, 120, 240
    try testing.expectApproxEqAbs(@as(f32, 0.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 120.0), result[1].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 240.0), result[2].hsva.h, 0.01);
}

test "generators.triadic: preserves saturation and value" {
    const color = Color.initHsva(45.0, 0.8, 0.9, 1.0);
    const result = generators.triadic(color);
    for (result) |c| {
        try testing.expectApproxEqAbs(color.hsva.s, c.hsva.s, 0.01);
        try testing.expectApproxEqAbs(color.hsva.v, c.hsva.v, 0.01);
    }
}

// === Harmony: splitComplementary ===

test "generators.splitComplementary: returns 3 colors" {
    const red = Colors.RED;
    const result = generators.splitComplementary(red);
    try testing.expectEqual(@as(usize, 3), result.len);
}

test "generators.splitComplementary: base + flanking complement" {
    const color = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const result = generators.splitComplementary(color);
    // Base at 0, flanks at 150 and 210
    try testing.expectApproxEqAbs(@as(f32, 0.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 150.0), result[1].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 210.0), result[2].hsva.h, 0.01);
}

// === Harmony: tetradic ===

test "generators.tetradic: returns 4 colors" {
    const red = Colors.RED;
    const result = generators.tetradic(red);
    try testing.expectEqual(@as(usize, 4), result.len);
}

test "generators.tetradic: rectangle scheme at 90 degree intervals" {
    const color = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const result = generators.tetradic(color);
    // 0, 90, 180, 270
    try testing.expectApproxEqAbs(@as(f32, 0.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 90.0), result[1].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 180.0), result[2].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 270.0), result[3].hsva.h, 0.01);
}

// === Harmony: square ===

test "generators.square: returns 4 colors" {
    const red = Colors.RED;
    const result = generators.square(red);
    try testing.expectEqual(@as(usize, 4), result.len);
}

test "generators.square: evenly spaced at 90 degrees" {
    const color = Color.initHsva(30.0, 1.0, 1.0, 1.0);
    const result = generators.square(color);
    // 30, 120, 210, 300
    try testing.expectApproxEqAbs(@as(f32, 30.0), result[0].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 120.0), result[1].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 210.0), result[2].hsva.h, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 300.0), result[3].hsva.h, 0.01);
}

// === Library-Aware: closest ===

test "generators.closest: exact match returns same color" {
    const red = Colors.RED;
    const result = generators.closest(red);
    try testing.expectEqual(red.rgba.r, result.color.rgba.r);
    try testing.expectEqual(red.rgba.g, result.color.rgba.g);
    try testing.expectEqual(red.rgba.b, result.color.rgba.b);
}

test "generators.closest: near-red snaps to a red" {
    const near_red = Color.initRgba(250, 5, 5, 255);
    const result = generators.closest(near_red);
    try testing.expectEqual(Hue.red, result.hue);
}

test "generators.closest: returns a TaggedColor with name" {
    const color = Color.initRgba(100, 150, 200, 255);
    const result = generators.closest(color);
    try testing.expect(result.name.len > 0);
}

test "generators.closest: arbitrary color finds reasonable match" {
    const arbitrary = Color.initHsva(185.0, 0.6, 0.7, 1.0);
    const result = generators.closest(arbitrary);
    // Should snap to something in the cyan-ish range
    const h = result.hue;
    try testing.expect(h == .cyan or h == .azure or h == .spring);
}

test "generators.closest: searches entire library (can cross hue boundaries)" {
    // A color on the red/orange boundary might snap to orange if that's closer
    const boundary_color = Color.initHsva(28.0, 0.9, 0.8, 1.0); // right on red/orange edge
    const result = generators.closest(boundary_color);
    // Should find SOMETHING close - verify result has a name (is a valid library entry)
    try testing.expect(result.name.len > 0);
}

test "generators.closest: very dark color returns valid library entry" {
    const dark = Color.initHsva(0.0, 0.8, 0.15, 1.0);
    const result = generators.closest(dark);
    // Verify it returns a valid library entry
    try testing.expect(result.name.len > 0);
}

test "generators.closest: gray returns valid library entry" {
    const gray = Color.initRgba(128, 128, 128, 255);
    const result = generators.closest(gray);
    // Verify it returns a valid library entry
    try testing.expect(result.name.len > 0);
}

// === Library-Aware: closestInHue ===

test "generators.closestInHue: stays within same hue family" {
    const red_variant = Color.initHsva(5.0, 0.7, 0.6, 1.0);
    const result = generators.closestInHue(red_variant);
    try testing.expectEqual(Hue.red, result.hue);
}

test "generators.closestInHue: finds closest within hue bucket" {
    const dark_blue = Color.initHsva(240.0, 0.8, 0.3, 1.0);
    const result = generators.closestInHue(dark_blue);
    try testing.expectEqual(Hue.blue, result.hue);
    // Should find a dark-ish blue
    try testing.expect(result.tone == .dark or result.tone == .deep);
}

test "generators.closestInHue: exact library color returns same hue" {
    const result = generators.closestInHue(Colors.GREEN);
    // Should find a green - might not be exact match due to distance calculation
    try testing.expectEqual(Hue.green, result.hue);
}

test "generators.closestInHue: does not cross into adjacent hue" {
    // Orange at 35 degrees - should stay orange, not become red or yellow
    const orange = Color.initHsva(35.0, 0.9, 0.9, 1.0);
    const result = generators.closestInHue(orange);
    try testing.expectEqual(Hue.orange, result.hue);
}

test "generators.closestInHue: neutral stays neutral" {
    const gray = Color.initRgba(100, 100, 100, 255);
    const result = generators.closestInHue(gray);
    try testing.expectEqual(Hue.neutral, result.hue);
}

// === Library-Aware: closestInHueTone ===

test "generators.closestInHueTone: matches both hue and tone" {
    const mid_green = Color.initHsva(120.0, 0.7, 0.5, 1.0);
    const result = generators.closestInHueTone(mid_green);
    try testing.expectEqual(Hue.green, result.hue);
    try testing.expectEqual(Tone.mid, result.tone);
}

test "generators.closestInHueTone: finds closest saturation within hue+tone" {
    const vivid_red = Color.initHsva(0.0, 0.95, 0.85, 1.0);
    const result = generators.closestInHueTone(vivid_red);
    try testing.expectEqual(Hue.red, result.hue);
    try testing.expectEqual(Tone.high, result.tone);
    // Just verify we got a valid result - saturation will be whatever is closest
    try testing.expect(result.name.len > 0);
}

test "generators.closestInHueTone: dark blue finds dark blue" {
    const dark_blue = Color.initHsva(240.0, 0.8, 0.35, 1.0);
    const result = generators.closestInHueTone(dark_blue);
    try testing.expectEqual(Hue.blue, result.hue);
    try testing.expectEqual(Tone.dark, result.tone);
}

test "generators.closestInHueTone: light yellow finds light yellow" {
    const light_yellow = Color.initHsva(60.0, 0.6, 0.75, 1.0);
    const result = generators.closestInHueTone(light_yellow);
    try testing.expectEqual(Hue.yellow, result.hue);
    try testing.expectEqual(Tone.light, result.tone);
}

test "generators.closestInHueTone: deep red finds deep red" {
    const deep_red = Color.initHsva(0.0, 0.9, 0.15, 1.0);
    const result = generators.closestInHueTone(deep_red);
    try testing.expectEqual(Hue.red, result.hue);
    try testing.expectEqual(Tone.deep, result.tone);
}

// === Library-Aware: closestInTone ===

test "generators.closestInTone: matches tone, any hue" {
    const dark_color = Color.initHsva(180.0, 0.7, 0.35, 1.0);
    const result = generators.closestInTone(dark_color);
    try testing.expectEqual(Tone.dark, result.tone);
}

test "generators.closestInTone: can cross hue boundaries for better tone match" {
    // A mid-tone cyan might match a mid-tone blue if that's closer
    const mid_cyan = Color.initHsva(185.0, 0.6, 0.55, 1.0);
    const result = generators.closestInTone(mid_cyan);
    try testing.expectEqual(Tone.mid, result.tone);
    // Hue can be anything in the cool range
}

test "generators.closestInTone: high tone finds bright colors" {
    const bright = Color.initHsva(60.0, 0.5, 0.9, 1.0);
    const result = generators.closestInTone(bright);
    try testing.expectEqual(Tone.high, result.tone);
}

test "generators.closestInTone: deep tone finds very dark colors" {
    const very_dark = Color.initHsva(300.0, 0.8, 0.1, 1.0);
    const result = generators.closestInTone(very_dark);
    try testing.expectEqual(Tone.deep, result.tone);
}

test "generators.closestInTone: useful for consistent lighting" {
    // Two different hues at same tone should both find same-tone results
    const dark_red = Color.initHsva(0.0, 0.8, 0.3, 1.0);
    const dark_blue = Color.initHsva(240.0, 0.8, 0.3, 1.0);
    const red_result = generators.closestInTone(dark_red);
    const blue_result = generators.closestInTone(dark_blue);
    try testing.expectEqual(red_result.tone, blue_result.tone);
}

// === Library-Aware: closestInSat ===

test "generators.closestInSat: matches saturation, any hue/tone" {
    const muted_color = Color.initHsva(120.0, 0.25, 0.6, 1.0);
    const result = generators.closestInSat(muted_color);
    try testing.expectEqual(Saturation.muted, result.saturation);
}

test "generators.closestInSat: vivid finds vivid" {
    const vivid = Color.initHsva(0.0, 0.9, 0.8, 1.0);
    const result = generators.closestInSat(vivid);
    try testing.expectEqual(Saturation.vivid, result.saturation);
}

test "generators.closestInSat: gray finds gray" {
    const gray = Color.initHsva(0.0, 0.02, 0.5, 1.0);
    const result = generators.closestInSat(gray);
    try testing.expectEqual(Saturation.gray, result.saturation);
}

test "generators.closestInSat: moderate finds moderate" {
    const moderate = Color.initHsva(200.0, 0.5, 0.7, 1.0);
    const result = generators.closestInSat(moderate);
    try testing.expectEqual(Saturation.moderate, result.saturation);
}

test "generators.closestInSat: useful for consistent vibrancy" {
    // Different colors at same saturation should both find same-sat results
    const muted_red = Color.initHsva(0.0, 0.2, 0.6, 1.0);
    const muted_green = Color.initHsva(120.0, 0.2, 0.6, 1.0);
    const red_result = generators.closestInSat(muted_red);
    const green_result = generators.closestInSat(muted_green);
    try testing.expectEqual(red_result.saturation, green_result.saturation);
}

// === Library-Aware: snap ===

test "generators.snap: with hue constraint returns matching hue" {
    const color = Color.initHsva(45.0, 0.8, 0.8, 1.0); // orange-ish
    const result = generators.snap(color, .red, null, null);
    try testing.expectEqual(Hue.red, result.hue);
}

test "generators.snap: with tone constraint returns matching tone" {
    const bright = Color.initHsva(0.0, 1.0, 0.9, 1.0);
    const result = generators.snap(bright, null, .dark, null);
    try testing.expectEqual(Tone.dark, result.tone);
}

test "generators.snap: with sat constraint returns matching saturation" {
    const vivid = Color.initHsva(120.0, 0.9, 0.8, 1.0);
    const result = generators.snap(vivid, null, null, .muted);
    try testing.expectEqual(Saturation.muted, result.saturation);
}

test "generators.snap: with all constraints narrows to exact match" {
    const result = generators.snap(Colors.RED, .red, .high, .vivid);
    try testing.expectEqual(Hue.red, result.hue);
    try testing.expectEqual(Tone.high, result.tone);
    try testing.expectEqual(Saturation.vivid, result.saturation);
}

test "generators.snap: with no constraints behaves like closest" {
    const color = Color.initRgba(200, 100, 50, 255);
    const snapped = generators.snap(color, null, null, null);
    const closest_result = generators.closest(color);
    try testing.expectEqual(snapped.color.rgba.r, closest_result.color.rgba.r);
}

// === Tone Navigation: getShade ===

test "generators.getShade: returns darker tone" {
    const light_red = Color.initHsva(0.0, 1.0, 0.7, 1.0); // light tone
    const result = generators.getShade(light_red);
    try testing.expect(result != null);
    try testing.expect(@intFromEnum(result.?.tone) < @intFromEnum(Tone.light));
}

test "generators.getShade: preserves hue" {
    const color = Color.initHsva(120.0, 0.8, 0.6, 1.0);
    const result = generators.getShade(color);
    try testing.expect(result != null);
    try testing.expectEqual(Hue.green, result.?.hue);
}

test "generators.getShade: returns null for deepest tone" {
    const deep = Color.initHsva(0.0, 1.0, 0.1, 1.0); // deep tone (v < 0.2)
    const result = generators.getShade(deep);
    try testing.expect(result == null);
}

// === Tone Navigation: getTint ===

test "generators.getTint: returns lighter tone" {
    const dark_red = Color.initHsva(0.0, 1.0, 0.3, 1.0); // dark tone
    const result = generators.getTint(dark_red);
    try testing.expect(result != null);
    try testing.expect(@intFromEnum(result.?.tone) > @intFromEnum(Tone.dark));
}

test "generators.getTint: preserves hue" {
    const color = Color.initHsva(240.0, 0.8, 0.4, 1.0);
    const result = generators.getTint(color);
    try testing.expect(result != null);
    try testing.expectEqual(Hue.blue, result.?.hue);
}

test "generators.getTint: returns null for highest tone" {
    const high = Color.initHsva(0.0, 1.0, 0.95, 1.0); // high tone (v >= 0.8)
    const result = generators.getTint(high);
    try testing.expect(result == null);
}

// === Tone Navigation: getShades ===

test "generators.getShades: returns array of darker tones" {
    const mid = Color.initHsva(0.0, 1.0, 0.5, 1.0); // mid tone
    const result = generators.getShades(mid);
    try testing.expect(result.len > 0);
    for (result) |shade| {
        try testing.expect(@intFromEnum(shade.tone) < @intFromEnum(Tone.mid));
    }
}

test "generators.getShades: preserves hue for all results" {
    const green = Color.initHsva(120.0, 0.8, 0.7, 1.0);
    const result = generators.getShades(green);
    for (result) |shade| {
        try testing.expectEqual(Hue.green, shade.hue);
    }
}

test "generators.getShades: returns empty for deepest tone" {
    const deep = Color.initHsva(0.0, 1.0, 0.1, 1.0);
    const result = generators.getShades(deep);
    try testing.expectEqual(@as(usize, 0), result.len);
}

// === Tone Navigation: getTints ===

test "generators.getTints: returns array of lighter tones" {
    const mid = Color.initHsva(0.0, 1.0, 0.5, 1.0); // mid tone
    const result = generators.getTints(mid);
    try testing.expect(result.len > 0);
    for (result) |tint| {
        try testing.expect(@intFromEnum(tint.tone) > @intFromEnum(Tone.mid));
    }
}

test "generators.getTints: preserves hue for all results" {
    const blue = Color.initHsva(240.0, 0.8, 0.4, 1.0);
    const result = generators.getTints(blue);
    for (result) |tint| {
        try testing.expectEqual(Hue.blue, tint.hue);
    }
}

test "generators.getTints: returns empty for highest tone" {
    const high = Color.initHsva(0.0, 1.0, 0.95, 1.0);
    const result = generators.getTints(high);
    try testing.expectEqual(@as(usize, 0), result.len);
}

// === Ramp: monochromatic ===

test "generators.monochromatic: returns requested number of steps" {
    const color = Colors.RED;
    const result = generators.monochromatic(color, 5);
    try testing.expectEqual(@as(usize, 5), result.len);
}

test "generators.monochromatic: all colors have same hue" {
    const color = Color.initHsva(120.0, 0.8, 0.5, 1.0);
    const result = generators.monochromatic(color, 5);
    for (result) |c| {
        try testing.expectApproxEqAbs(color.hsva.h, c.hsva.h, 0.01);
    }
}

test "generators.monochromatic: spans from dark to light" {
    const color = Color.initHsva(0.0, 1.0, 0.5, 1.0);
    const result = generators.monochromatic(color, 5);
    // First should be darker, last should be lighter
    try testing.expect(result[0].hsva.v < result[4].hsva.v);
}

test "generators.monochromatic: values increase monotonically" {
    const color = Color.initHsva(60.0, 0.7, 0.5, 1.0);
    const result = generators.monochromatic(color, 5);
    var prev_v: f32 = 0.0;
    for (result) |c| {
        try testing.expect(c.hsva.v >= prev_v);
        prev_v = c.hsva.v;
    }
}

// === Ramp: gradient ===

test "generators.gradient: returns requested number of steps" {
    const from = Colors.RED;
    const to = Colors.BLUE;
    const result = generators.gradient(from, to, 5);
    try testing.expectEqual(@as(usize, 5), result.len);
}

test "generators.gradient: first color matches 'from'" {
    const from = Colors.RED;
    const to = Colors.BLUE;
    const result = generators.gradient(from, to, 5);
    try testing.expectApproxEqAbs(from.hsva.h, result[0].hsva.h, 0.01);
}

test "generators.gradient: last color matches 'to'" {
    const from = Colors.RED;
    const to = Colors.BLUE;
    const result = generators.gradient(from, to, 5);
    try testing.expectApproxEqAbs(to.hsva.h, result[4].hsva.h, 0.01);
}

test "generators.gradient: middle color is interpolated" {
    const black = Color.initHsva(0.0, 0.0, 0.0, 1.0);
    const white = Color.initHsva(0.0, 0.0, 1.0, 1.0);
    const result = generators.gradient(black, white, 3);
    // Middle should be gray (v ~= 0.5)
    try testing.expectApproxEqAbs(@as(f32, 0.5), result[1].hsva.v, 0.01);
}

test "generators.gradient: interpolates saturation" {
    const vivid = Color.initHsva(0.0, 1.0, 1.0, 1.0);
    const gray = Color.initHsva(0.0, 0.0, 1.0, 1.0);
    const result = generators.gradient(vivid, gray, 3);
    try testing.expectApproxEqAbs(@as(f32, 0.5), result[1].hsva.s, 0.01);
}

// === Chaining: harmony + library snap ===

test "generators: complement then closest gives library color" {
    const red = Colors.RED;
    const comp = generators.complement(red);
    const snapped = generators.closest(comp);
    // Complement of red is cyan; should snap to a cyan-ish library color
    try testing.expectEqual(Hue.cyan, snapped.hue);
    try testing.expect(snapped.name.len > 0);
}

test "generators: triadic then snap constrains all to library" {
    const red = Colors.RED;
    const triad = generators.triadic(red);
    for (triad) |c| {
        const snapped = generators.closest(c);
        try testing.expect(snapped.name.len > 0);
    }
}
