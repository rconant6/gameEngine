const std = @import("std");
const testing = std.testing;
const Color = @import("color").Color;
const Colors = @import("color").Colors;

test "Color: init with RGBA values" {
    const color = Color.init(255, 128, 64, 200);
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 200), color.a);
}

test "Color: init fully opaque" {
    const color = Color.init(100, 150, 200, 255);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Color: init fully transparent" {
    const color = Color.init(100, 150, 200, 0);
    try testing.expectEqual(@as(u8, 0), color.a);
}

test "Color: initFromHex with 6 digits" {
    const color = Color.initFromHex("#FF8040");
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 255), color.a); // Default opaque
}

test "Color: initFromHex with 8 digits" {
    const color = Color.initFromHex("#FF8040C8");
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 200), color.a);
}

test "Color: initFromHex lowercase" {
    const color = Color.initFromHex("#ff8040");
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
}

test "Color: initFromHex RED" {
    const color = Color.initFromHex("#FF0000");
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 0), color.g);
    try testing.expectEqual(@as(u8, 0), color.b);
}

test "Color: initFromHex GREEN" {
    const color = Color.initFromHex("#00FF00");
    try testing.expectEqual(@as(u8, 0), color.r);
    try testing.expectEqual(@as(u8, 255), color.g);
    try testing.expectEqual(@as(u8, 0), color.b);
}

test "Color: initFromHex BLUE" {
    const color = Color.initFromHex("#0000FF");
    try testing.expectEqual(@as(u8, 0), color.r);
    try testing.expectEqual(@as(u8, 0), color.g);
    try testing.expectEqual(@as(u8, 255), color.b);
}

test "Color: initFromU32Hex with 6 digits" {
    const color = Color.initFromU32Hex(0xFF8040);
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Color: initFromU32Hex with 8 digits" {
    const color = Color.initFromU32Hex(0xFF8040C8);
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 128), color.g);
    try testing.expectEqual(@as(u8, 64), color.b);
    try testing.expectEqual(@as(u8, 200), color.a);
}

test "Color: initFromU32Hex black" {
    const color = Color.initFromU32Hex(0x000000);
    try testing.expectEqual(@as(u8, 0), color.r);
    try testing.expectEqual(@as(u8, 0), color.g);
    try testing.expectEqual(@as(u8, 0), color.b);
    try testing.expectEqual(@as(u8, 255), color.a);
}

test "Color: initFromU32Hex white" {
    const color = Color.initFromU32Hex(0xFFFFFF);
    try testing.expectEqual(@as(u8, 255), color.r);
    try testing.expectEqual(@as(u8, 255), color.g);
    try testing.expectEqual(@as(u8, 255), color.b);
}

test "Colors: predefined RED" {
    try testing.expectEqual(@as(u8, 255), Colors.RED.r);
    try testing.expectEqual(@as(u8, 0), Colors.RED.g);
    try testing.expectEqual(@as(u8, 0), Colors.RED.b);
    try testing.expectEqual(@as(u8, 255), Colors.RED.a);
}

test "Colors: predefined GREEN" {
    try testing.expectEqual(@as(u8, 0), Colors.GREEN.r);
    try testing.expectEqual(@as(u8, 255), Colors.GREEN.g);
    try testing.expectEqual(@as(u8, 0), Colors.GREEN.b);
}

test "Colors: predefined BLUE" {
    try testing.expectEqual(@as(u8, 0), Colors.BLUE.r);
    try testing.expectEqual(@as(u8, 0), Colors.BLUE.g);
    try testing.expectEqual(@as(u8, 255), Colors.BLUE.b);
}

test "Colors: predefined WHITE" {
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.r);
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.g);
    try testing.expectEqual(@as(u8, 255), Colors.WHITE.b);
}

test "Colors: predefined BLACK" {
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.r);
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.g);
    try testing.expectEqual(@as(u8, 0), Colors.BLACK.b);
}

test "Colors: predefined CLEAR is transparent" {
    try testing.expectEqual(@as(u8, 0), Colors.CLEAR.a);
}

test "Colors: predefined CYAN" {
    try testing.expectEqual(@as(u8, 0), Colors.CYAN.r);
    try testing.expectEqual(@as(u8, 255), Colors.CYAN.g);
    try testing.expectEqual(@as(u8, 255), Colors.CYAN.b);
}

test "Colors: predefined MAGENTA" {
    try testing.expectEqual(@as(u8, 255), Colors.MAGENTA.r);
    try testing.expectEqual(@as(u8, 0), Colors.MAGENTA.g);
    try testing.expectEqual(@as(u8, 255), Colors.MAGENTA.b);
}

test "Colors: predefined YELLOW" {
    try testing.expectEqual(@as(u8, 255), Colors.YELLOW.r);
    try testing.expectEqual(@as(u8, 255), Colors.YELLOW.g);
    try testing.expectEqual(@as(u8, 0), Colors.YELLOW.b);
}

test "Colors: neon colors have high saturation" {
    // Neon red should have max red, minimal other colors
    try testing.expectEqual(@as(u8, 255), Colors.NEON_RED.r);
    try testing.expect(Colors.NEON_RED.g < 50);
    try testing.expect(Colors.NEON_RED.b < 50);
}

test "Colors: pastel colors are lighter" {
    // Pastel colors should have all channels relatively high
    try testing.expect(Colors.PASTEL_RED.r > 200);
    try testing.expect(Colors.PASTEL_RED.g > 200);
    try testing.expect(Colors.PASTEL_RED.b > 200);
}

test "Colors: gray scale" {
    // Gray should have equal RGB values
    try testing.expectEqual(Colors.GRAY.r, Colors.GRAY.g);
    try testing.expectEqual(Colors.GRAY.g, Colors.GRAY.b);

    // Light gray should be brighter than gray
    try testing.expect(Colors.LIGHT_GRAY.r > Colors.GRAY.r);

    // Dark gray should be darker than gray
    try testing.expect(Colors.DARK_GRAY.r < Colors.GRAY.r);
}
