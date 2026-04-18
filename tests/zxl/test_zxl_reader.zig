const std = @import("std");
const testing = std.testing;
const zxl = @import("zxl");
const ZxlReader = zxl.ZxlReader;
const ZxlImage = zxl.ZxlImage;
const math = @import("math");
const Rgba = math.Rgba;

const test_data = @embedFile("test_2x2.zxl");

// ========================================
// Happy path — header
// ========================================

test "ZxlReader: fromBytes reads header correctly" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    try testing.expectEqual(@as(usize, 1), img.frames.items.len);
    try testing.expectEqual(@as(u8, 5), img.palette.count);
}

// ========================================
// Happy path — palette
// ========================================

test "ZxlReader: palette colors match" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    // Index 0: transparent
    const c0 = img.palette.getColor(0);
    try testing.expectEqual(@as(u8, 0), c0.r);
    try testing.expectEqual(@as(u8, 0), c0.g);
    try testing.expectEqual(@as(u8, 0), c0.b);
    try testing.expectEqual(@as(u8, 0), c0.a);

    // Index 1: red
    const c1 = img.palette.getColor(1);
    try testing.expectEqual(@as(u8, 255), c1.r);
    try testing.expectEqual(@as(u8, 0), c1.g);
    try testing.expectEqual(@as(u8, 0), c1.b);
    try testing.expectEqual(@as(u8, 255), c1.a);

    // Index 2: green
    const c2 = img.palette.getColor(2);
    try testing.expectEqual(@as(u8, 0), c2.r);
    try testing.expectEqual(@as(u8, 255), c2.g);
    try testing.expectEqual(@as(u8, 0), c2.b);
    try testing.expectEqual(@as(u8, 255), c2.a);

    // Index 3: blue
    const c3 = img.palette.getColor(3);
    try testing.expectEqual(@as(u8, 0), c3.r);
    try testing.expectEqual(@as(u8, 0), c3.g);
    try testing.expectEqual(@as(u8, 255), c3.b);
    try testing.expectEqual(@as(u8, 255), c3.a);

    // Index 4: orange
    const c4 = img.palette.getColor(4);
    try testing.expectEqual(@as(u8, 255), c4.r);
    try testing.expectEqual(@as(u8, 165), c4.g);
    try testing.expectEqual(@as(u8, 0), c4.b);
    try testing.expectEqual(@as(u8, 255), c4.a);
}

// ========================================
// Happy path — frame metadata
// ========================================

test "ZxlReader: frame metadata correct" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    const frame = img.getFrame(0).?;
    try testing.expectEqualStrings("test", frame.name);
    try testing.expectEqual(@as(u16, 0), frame.duration_ms);
    try testing.expectEqual(@as(i16, 0), frame.origin_x);
    try testing.expectEqual(@as(i16, 0), frame.origin_y);
    try testing.expectEqual(@as(u16, 2), frame.width);
    try testing.expectEqual(@as(u16, 2), frame.height);
}

// ========================================
// Happy path — pixel data
// ========================================

test "ZxlReader: pixel data matches corners" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    const frame = img.getFrame(0).?;
    // top-left: red (index 1)
    try testing.expectEqual(@as(u8, 1), frame.getPixel(0, 0));
    // top-right: blue (index 3)
    try testing.expectEqual(@as(u8, 3), frame.getPixel(1, 0));
    // bottom-left: green (index 2)
    try testing.expectEqual(@as(u8, 2), frame.getPixel(0, 1));
    // bottom-right: orange (index 4)
    try testing.expectEqual(@as(u8, 4), frame.getPixel(1, 1));
}

// ========================================
// Happy path — RGBA expansion
// ========================================

test "ZxlReader: toRgbaBuffer expands correctly" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    const buf = try img.toRgbaBuffer(0);
    defer testing.allocator.free(buf);

    try testing.expectEqual(@as(usize, 16), buf.len); // 4 pixels * 4 bytes

    // pixel (0,0): red
    try testing.expectEqual(@as(u8, 255), buf[0]);
    try testing.expectEqual(@as(u8, 0), buf[1]);
    try testing.expectEqual(@as(u8, 0), buf[2]);
    try testing.expectEqual(@as(u8, 255), buf[3]);

    // pixel (1,0): blue
    try testing.expectEqual(@as(u8, 0), buf[4]);
    try testing.expectEqual(@as(u8, 0), buf[5]);
    try testing.expectEqual(@as(u8, 255), buf[6]);
    try testing.expectEqual(@as(u8, 255), buf[7]);

    // pixel (0,1): green
    try testing.expectEqual(@as(u8, 0), buf[8]);
    try testing.expectEqual(@as(u8, 255), buf[9]);
    try testing.expectEqual(@as(u8, 0), buf[10]);
    try testing.expectEqual(@as(u8, 255), buf[11]);

    // pixel (1,1): orange
    try testing.expectEqual(@as(u8, 255), buf[12]);
    try testing.expectEqual(@as(u8, 165), buf[13]);
    try testing.expectEqual(@as(u8, 0), buf[14]);
    try testing.expectEqual(@as(u8, 255), buf[15]);
}

// ========================================
// Error cases
// ========================================

test "ZxlReader: invalid magic returns error" {
    var bad = [_]u8{0} ** 16;
    bad[0] = 'N';
    bad[1] = 'O';
    bad[2] = 'P';
    bad[3] = 'E';
    bad[4] = 1; // version

    const result = ZxlReader.fromBytes(testing.allocator, &bad);
    try testing.expectError(error.InvalidMagic, result);
}

test "ZxlReader: truncated data returns UnexpectedEof" {
    const result = ZxlReader.fromBytes(testing.allocator, test_data[0..10]);
    try testing.expectError(error.UnexpectedEof, result);
}

test "ZxlReader: unsupported version returns error" {
    var bad: [test_data.len]u8 = test_data.*;
    bad[4] = 99;

    const result = ZxlReader.fromBytes(testing.allocator, &bad);
    try testing.expectError(error.UnsupportedVersion, result);
}
