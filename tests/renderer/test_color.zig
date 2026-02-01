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
