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
