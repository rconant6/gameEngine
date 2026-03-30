const std = @import("std");
const testing = std.testing;
const zxl = @import("zxl");
const ZxlImage = zxl.ZxlImage;
const ZxlPalette = zxl.ZxlPalette;
const math = @import("math");
const Rgba = math.Rgba;

// ========================================
// Palette
// ========================================

test "ZxlPalette: starts with transparent at index 0" {
    const palette = ZxlPalette{};
    const c = palette.getColor(0);
    try testing.expectEqual(@as(u8, 0), c.r);
    try testing.expectEqual(@as(u8, 0), c.g);
    try testing.expectEqual(@as(u8, 0), c.b);
    try testing.expectEqual(@as(u8, 0), c.a);
    try testing.expectEqual(@as(u8, 1), palette.count);
}

test "ZxlPalette: addColor and retrieve" {
    var palette = ZxlPalette{};
    const red = Rgba{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const idx = palette.addColor(red);

    try testing.expectEqual(@as(u8, 1), idx);
    try testing.expectEqual(@as(u8, 2), palette.count);

    const got = palette.getColor(idx);
    try testing.expectEqual(@as(u8, 255), got.r);
    try testing.expectEqual(@as(u8, 0), got.g);
    try testing.expectEqual(@as(u8, 0), got.b);
    try testing.expectEqual(@as(u8, 255), got.a);
}

test "ZxlPalette: addColor multiple colors" {
    var palette = ZxlPalette{};
    const red = Rgba{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const green = Rgba{ .r = 0, .g = 255, .b = 0, .a = 255 };
    const blue = Rgba{ .r = 0, .g = 0, .b = 255, .a = 255 };

    const r_idx = palette.addColor(red);
    const g_idx = palette.addColor(green);
    const b_idx = palette.addColor(blue);

    try testing.expectEqual(@as(u8, 1), r_idx);
    try testing.expectEqual(@as(u8, 2), g_idx);
    try testing.expectEqual(@as(u8, 3), b_idx);
    try testing.expectEqual(@as(u8, 4), palette.count);
}

test "ZxlPalette: addColor returns 0 when full" {
    var palette = ZxlPalette{};
    // Fill up to 255 entries (indices 1..254)
    for (0..254) |_| {
        _ = palette.addColor(.{ .r = 1, .g = 2, .b = 3, .a = 255 });
    }
    try testing.expectEqual(@as(u8, 255), palette.count);

    // Next add should return 0 (palette full)
    const idx = palette.addColor(.{ .r = 99, .g = 99, .b = 99, .a = 255 });
    try testing.expectEqual(@as(u8, 0), idx);
    try testing.expectEqual(@as(u8, 255), palette.count);
}

test "ZxlPalette: findColor finds existing color" {
    var palette = ZxlPalette{};
    const red = Rgba{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const green = Rgba{ .r = 0, .g = 255, .b = 0, .a = 255 };
    _ = palette.addColor(red);
    _ = palette.addColor(green);

    const found = palette.findColor(green);
    try testing.expectEqual(@as(?u8, 2), found);
}

test "ZxlPalette: findColor returns null for missing color" {
    var palette = ZxlPalette{};
    _ = palette.addColor(.{ .r = 255, .g = 0, .b = 0, .a = 255 });

    const found = palette.findColor(.{ .r = 0, .g = 0, .b = 255, .a = 255 });
    try testing.expectEqual(@as(?u8, null), found);
}

test "ZxlPalette: findColor finds transparent at index 0" {
    const palette = ZxlPalette{};
    const found = palette.findColor(.{ .r = 0, .g = 0, .b = 0, .a = 0 });
    try testing.expectEqual(@as(?u8, 0), found);
}

test "ZxlPalette: getColor out of bounds returns clear" {
    const palette = ZxlPalette{};
    const c = palette.getColor(200);
    try testing.expectEqual(@as(u8, 0), c.a);
}

// ========================================
// ZxlImage
// ========================================

test "ZxlImage: init and deinit" {
    var img = try ZxlImage.init(testing.allocator, "test");
    defer img.deinit();

    try testing.expectEqualStrings("test", img.name);
    try testing.expectEqual(@as(usize, 0), img.frames.items.len);
    try testing.expectEqual(@as(u8, 1), img.palette.count);
}

test "ZxlImage: addFrame stores frame data" {
    var img = try ZxlImage.init(testing.allocator, "sprite");
    defer img.deinit();

    const pixels = &[_]u8{ 0, 1, 1, 0 };
    try img.addFrame("idle", 2, 2, pixels, 100, 0, 0);

    try testing.expectEqual(@as(usize, 1), img.frames.items.len);

    const frame = img.getFrame(0).?;
    try testing.expectEqualStrings("idle", frame.name);
    try testing.expectEqual(@as(u16, 2), frame.width);
    try testing.expectEqual(@as(u16, 2), frame.height);
    try testing.expectEqual(@as(u16, 100), frame.duration_ms);
    try testing.expectEqualSlices(u8, pixels, frame.pixels);
}

test "ZxlImage: addFrame rejects wrong pixel count" {
    var img = try ZxlImage.init(testing.allocator, "bad");
    defer img.deinit();

    const pixels = &[_]u8{ 0, 1, 2 }; // 3 pixels for a 2x2 frame
    const result = img.addFrame("frame", 2, 2, pixels, 0, 0, 0);
    try testing.expectError(error.InvalidPixelData, result);
}

test "ZxlImage: addFrame multiple frames" {
    var img = try ZxlImage.init(testing.allocator, "anim");
    defer img.deinit();

    try img.addFrame("frame0", 1, 1, &[_]u8{0}, 100, 0, 0);
    try img.addFrame("frame1", 1, 1, &[_]u8{1}, 100, 0, 0);
    try img.addFrame("frame2", 1, 1, &[_]u8{2}, 200, 4, -2);

    try testing.expectEqual(@as(usize, 3), img.frames.items.len);

    const f2 = img.getFrame(2).?;
    try testing.expectEqualStrings("frame2", f2.name);
    try testing.expectEqual(@as(u16, 200), f2.duration_ms);
    try testing.expectEqual(@as(i16, 4), f2.origin_x);
    try testing.expectEqual(@as(i16, -2), f2.origin_y);
}

test "ZxlImage: getFrame out of bounds returns null" {
    var img = try ZxlImage.init(testing.allocator, "empty");
    defer img.deinit();

    try testing.expectEqual(@as(?*const zxl.ZxlFrame, null), img.getFrame(0));
    try testing.expectEqual(@as(?*const zxl.ZxlFrame, null), img.getFrame(99));
}

test "ZxlImage: getFrameByName" {
    var img = try ZxlImage.init(testing.allocator, "sprite");
    defer img.deinit();

    try img.addFrame("idle", 1, 1, &[_]u8{0}, 0, 0, 0);
    try img.addFrame("walk", 1, 1, &[_]u8{1}, 0, 0, 0);

    const walk = img.getFrameByName("walk").?;
    try testing.expectEqualStrings("walk", walk.name);

    const missing = img.getFrameByName("jump");
    try testing.expectEqual(@as(?*const zxl.ZxlFrame, null), missing);
}

// ========================================
// ZxlFrame
// ========================================

test "ZxlFrame: getPixel reads correct index" {
    var img = try ZxlImage.init(testing.allocator, "px");
    defer img.deinit();

    // 3x2 frame:
    // [0, 1, 2]
    // [3, 4, 5]
    const pixels = &[_]u8{ 0, 1, 2, 3, 4, 5 };
    try img.addFrame("grid", 3, 2, pixels, 0, 0, 0);

    const frame = img.getFrame(0).?;
    try testing.expectEqual(@as(u8, 0), frame.getPixel(0, 0));
    try testing.expectEqual(@as(u8, 2), frame.getPixel(2, 0));
    try testing.expectEqual(@as(u8, 3), frame.getPixel(0, 1));
    try testing.expectEqual(@as(u8, 5), frame.getPixel(2, 1));
}

// ========================================
// toRgbaBuffer
// ========================================

test "ZxlImage: toRgbaBuffer expands palette indices" {
    var img = try ZxlImage.init(testing.allocator, "rgba");
    defer img.deinit();

    const red_idx = img.palette.addColor(.{ .r = 255, .g = 0, .b = 0, .a = 255 });
    const blue_idx = img.palette.addColor(.{ .r = 0, .g = 0, .b = 255, .a = 255 });

    // 2x1: red, blue
    const pixels = &[_]u8{ red_idx, blue_idx };
    try img.addFrame("test", 2, 1, pixels, 0, 0, 0);

    const buf = try img.toRgbaBuffer(0);
    defer testing.allocator.free(buf);

    try testing.expectEqual(@as(usize, 8), buf.len); // 2 pixels * 4 bytes

    // pixel 0: red
    try testing.expectEqual(@as(u8, 255), buf[0]);
    try testing.expectEqual(@as(u8, 0), buf[1]);
    try testing.expectEqual(@as(u8, 0), buf[2]);
    try testing.expectEqual(@as(u8, 255), buf[3]);

    // pixel 1: blue
    try testing.expectEqual(@as(u8, 0), buf[4]);
    try testing.expectEqual(@as(u8, 0), buf[5]);
    try testing.expectEqual(@as(u8, 255), buf[6]);
    try testing.expectEqual(@as(u8, 255), buf[7]);
}

test "ZxlImage: toRgbaBuffer transparent pixels" {
    var img = try ZxlImage.init(testing.allocator, "alpha");
    defer img.deinit();

    // index 0 = transparent
    const pixels = &[_]u8{ 0, 0 };
    try img.addFrame("clear", 2, 1, pixels, 0, 0, 0);

    const buf = try img.toRgbaBuffer(0);
    defer testing.allocator.free(buf);

    // Both pixels should be fully transparent
    for (0..2) |p| {
        const base = p * 4;
        try testing.expectEqual(@as(u8, 0), buf[base + 0]);
        try testing.expectEqual(@as(u8, 0), buf[base + 1]);
        try testing.expectEqual(@as(u8, 0), buf[base + 2]);
        try testing.expectEqual(@as(u8, 0), buf[base + 3]);
    }
}

test "ZxlImage: toRgbaBuffer invalid frame returns error" {
    var img = try ZxlImage.init(testing.allocator, "err");
    defer img.deinit();

    const result = img.toRgbaBuffer(0);
    try testing.expectError(error.InvalidFrame, result);
}

// ========================================
// Owns copies (memory safety)
// ========================================

test "ZxlImage: addFrame owns copies of data" {
    var img = try ZxlImage.init(testing.allocator, "copy");
    defer img.deinit();

    var pixels = [_]u8{ 0, 1, 2, 3 };
    try img.addFrame("f", 2, 2, &pixels, 0, 0, 0);

    // Mutate the original - frame should be unaffected
    pixels[0] = 99;
    const frame = img.getFrame(0).?;
    try testing.expectEqual(@as(u8, 0), frame.pixels[0]);
}
