const std = @import("std");
const testing = std.testing;
const Color = @import("color").Color;
const Colors = @import("color").Colors;

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
