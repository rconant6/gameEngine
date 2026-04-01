const std = @import("std");
const testing = std.testing;
const zxl = @import("zxl");
const ZxlImage = zxl.ZxlImage;
const ZxlWriter = zxl.ZxlWriter;
const ZxlReader = zxl.ZxlReader;
const math = @import("math");
const Rgba = math.Rgba;

const test_data = @embedFile("test_2x2.zxl");

// Helper: build a 2x2 image with 3 palette colors + transparent
fn buildTestImage() !ZxlImage {
    var img = try ZxlImage.init(testing.allocator, "test");
    _ = img.palette.addColor(.{ .r = 255, .g = 0, .b = 0, .a = 255 }); // 1: red
    _ = img.palette.addColor(.{ .r = 0, .g = 255, .b = 0, .a = 255 }); // 2: green
    _ = img.palette.addColor(.{ .r = 0, .g = 0, .b = 255, .a = 255 }); // 3: blue
    try img.addFrame("f1", 2, 2, &[_]u8{ 1, 3, 2, 0 }, 100, 4, -2);
    return img;
}

// ========================================
// Header
// ========================================

test "ZxlWriter: toBytes produces valid header" {
    var img = try buildTestImage();
    defer img.deinit();

    const bytes = try ZxlWriter.toBytes(testing.allocator, &img);
    defer testing.allocator.free(bytes);

    // Magic
    try testing.expectEqualStrings("ZXL\x00", bytes[0..4]);
    // Version
    try testing.expectEqual(@as(u8, 1), bytes[4]);
    // Flags
    try testing.expectEqual(@as(u8, 0), bytes[5]);
    // Frame count = 1
    try testing.expectEqual(@as(u8, 1), bytes[6]);
    try testing.expectEqual(@as(u8, 0), bytes[7]);
    // Width = 2
    try testing.expectEqual(@as(u8, 2), bytes[8]);
    try testing.expectEqual(@as(u8, 0), bytes[9]);
    // Height = 2
    try testing.expectEqual(@as(u8, 2), bytes[10]);
    try testing.expectEqual(@as(u8, 0), bytes[11]);
    // Palette count = 4 (transparent + 3 colors)
    try testing.expectEqual(@as(u8, 4), bytes[12]);
}

// ========================================
// Palette
// ========================================

test "ZxlWriter: toBytes palette section correct" {
    var img = try buildTestImage();
    defer img.deinit();

    const bytes = try ZxlWriter.toBytes(testing.allocator, &img);
    defer testing.allocator.free(bytes);

    // Palette starts at byte 16, 4 entries × 4 bytes = 16 bytes
    // Index 0: transparent
    try testing.expectEqual(@as(u8, 0), bytes[16]);
    try testing.expectEqual(@as(u8, 0), bytes[17]);
    try testing.expectEqual(@as(u8, 0), bytes[18]);
    try testing.expectEqual(@as(u8, 0), bytes[19]);
    // Index 1: red
    try testing.expectEqual(@as(u8, 255), bytes[20]);
    try testing.expectEqual(@as(u8, 0), bytes[21]);
    try testing.expectEqual(@as(u8, 0), bytes[22]);
    try testing.expectEqual(@as(u8, 255), bytes[23]);
    // Index 2: green
    try testing.expectEqual(@as(u8, 0), bytes[24]);
    try testing.expectEqual(@as(u8, 255), bytes[25]);
    try testing.expectEqual(@as(u8, 0), bytes[26]);
    try testing.expectEqual(@as(u8, 255), bytes[27]);
    // Index 3: blue
    try testing.expectEqual(@as(u8, 0), bytes[28]);
    try testing.expectEqual(@as(u8, 0), bytes[29]);
    try testing.expectEqual(@as(u8, 255), bytes[30]);
    try testing.expectEqual(@as(u8, 255), bytes[31]);
}

// ========================================
// Frame
// ========================================

test "ZxlWriter: toBytes frame section correct" {
    var img = try buildTestImage();
    defer img.deinit();

    const bytes = try ZxlWriter.toBytes(testing.allocator, &img);
    defer testing.allocator.free(bytes);

    // Frame starts after header(16) + palette(4*4=16) = byte 32
    const f = 32;
    // name_len = 2 ("f1")
    try testing.expectEqual(@as(u8, 2), bytes[f]);
    // name
    try testing.expectEqualStrings("f1", bytes[f + 1 .. f + 3]);
    // duration_ms = 100 LE
    try testing.expectEqual(@as(u8, 100), bytes[f + 3]);
    try testing.expectEqual(@as(u8, 0), bytes[f + 4]);
    // origin_x = 4 LE
    try testing.expectEqual(@as(u8, 4), bytes[f + 5]);
    try testing.expectEqual(@as(u8, 0), bytes[f + 6]);
    // origin_y = -2 LE (0xFFFE)
    try testing.expectEqual(@as(u8, 0xFE), bytes[f + 7]);
    try testing.expectEqual(@as(u8, 0xFF), bytes[f + 8]);
    // reserved
    try testing.expectEqual(@as(u8, 0), bytes[f + 9]);
    // pixels: 1, 3, 2, 0
    try testing.expectEqual(@as(u8, 1), bytes[f + 10]);
    try testing.expectEqual(@as(u8, 3), bytes[f + 11]);
    try testing.expectEqual(@as(u8, 2), bytes[f + 12]);
    try testing.expectEqual(@as(u8, 0), bytes[f + 13]);
}

// ========================================
// Round-trip: build → write → read
// ========================================

test "ZxlWriter: round-trip write then read" {
    var original = try buildTestImage();
    defer original.deinit();

    const bytes = try ZxlWriter.toBytes(testing.allocator, &original);
    defer testing.allocator.free(bytes);

    var restored = try ZxlReader.fromBytes(testing.allocator, bytes);
    defer restored.deinit();

    // Palette
    try testing.expectEqual(original.palette.count, restored.palette.count);
    for (0..original.palette.count) |i| {
        const a = original.palette.colors[i];
        const b = restored.palette.colors[i];
        try testing.expectEqual(a.r, b.r);
        try testing.expectEqual(a.g, b.g);
        try testing.expectEqual(a.b, b.b);
        try testing.expectEqual(a.a, b.a);
    }

    // Frames
    try testing.expectEqual(original.frames.items.len, restored.frames.items.len);
    const of = original.getFrame(0).?;
    const rf = restored.getFrame(0).?;
    try testing.expectEqualStrings(of.name, rf.name);
    try testing.expectEqual(of.width, rf.width);
    try testing.expectEqual(of.height, rf.height);
    try testing.expectEqual(of.duration_ms, rf.duration_ms);
    try testing.expectEqual(of.origin_x, rf.origin_x);
    try testing.expectEqual(of.origin_y, rf.origin_y);
    try testing.expectEqualSlices(u8, of.pixels, rf.pixels);
}

// ========================================
// Round-trip: read test_2x2.zxl → write → byte-identical
// ========================================

test "ZxlWriter: round-trip preserves test_2x2.zxl" {
    var img = try ZxlReader.fromBytes(testing.allocator, test_data);
    defer img.deinit();

    const written = try ZxlWriter.toBytes(testing.allocator, &img);
    defer testing.allocator.free(written);

    try testing.expectEqualSlices(u8, test_data, written);
}

// ========================================
// Empty image
// ========================================

test "ZxlWriter: empty image (no frames)" {
    var img = try ZxlImage.init(testing.allocator, "empty");
    defer img.deinit();

    const bytes = try ZxlWriter.toBytes(testing.allocator, &img);
    defer testing.allocator.free(bytes);

    // header(16) + palette(1 entry * 4 bytes) = 20 bytes
    try testing.expectEqual(@as(usize, 20), bytes.len);
    // frame_count = 0
    try testing.expectEqual(@as(u8, 0), bytes[6]);
    try testing.expectEqual(@as(u8, 0), bytes[7]);
    // width/height = 0
    try testing.expectEqual(@as(u8, 0), bytes[8]);
    try testing.expectEqual(@as(u8, 0), bytes[10]);
}
