const std = @import("std");
const Allocator = std.mem.Allocator;
const img = @import("ZxlImage.zig");
const ZxlImage = img.ZxlImage;
const ZxlPalette = img.ZxlPalette;
const ZxlFrame = img.ZxlFrame;

const magic = "ZXL\x00";

pub fn toBytes(allocator: Allocator, image: *const ZxlImage) ![]u8 {
    // Compute total size
    const palette_bytes: usize = @as(usize, image.palette.count) * 4;

    var frames_bytes: usize = 0;
    for (image.frames.items) |frame| {
        // name_len(1) + name + duration(2) + origin_x(2) + origin_y(2) + reserved(1) + pixels
        frames_bytes += 1 + frame.name.len + 7 + @as(usize, frame.width) * @as(usize, frame.height);
    }

    const total = 16 + palette_bytes + frames_bytes;
    const buf = try allocator.alloc(u8, total);
    errdefer allocator.free(buf);

    var pos: usize = 0;

    // Header
    @memcpy(buf[0..4], magic);
    buf[4] = 1; // version
    buf[5] = 0; // flags

    // frame_count
    const frame_count: u16 = @intCast(image.frames.items.len);
    writeU16Le(buf[6..8], frame_count);

    // canvas dimensions from first frame (or 0 if no frames)
    if (image.frames.items.len > 0) {
        writeU16Le(buf[8..10], image.frames.items[0].width);
        writeU16Le(buf[10..12], image.frames.items[0].height);
    } else {
        writeU16Le(buf[8..10], 0);
        writeU16Le(buf[10..12], 0);
    }

    buf[12] = image.palette.count;
    buf[13] = 0;
    buf[14] = 0;
    buf[15] = 0;
    pos = 16;

    // Palette
    for (0..image.palette.count) |i| {
        const c = image.palette.colors[i];
        buf[pos + 0] = c.r;
        buf[pos + 1] = c.g;
        buf[pos + 2] = c.b;
        buf[pos + 3] = c.a;
        pos += 4;
    }

    // Frames
    for (image.frames.items) |frame| {
        // name_len + name
        const name_len: u8 = @intCast(frame.name.len);
        buf[pos] = name_len;
        pos += 1;
        @memcpy(buf[pos .. pos + name_len], frame.name);
        pos += name_len;

        // duration_ms, origin_x, origin_y, reserved
        writeU16Le(buf[pos..][0..2], frame.duration_ms);
        pos += 2;
        writeI16Le(buf[pos..][0..2], frame.origin_x);
        pos += 2;
        writeI16Le(buf[pos..][0..2], frame.origin_y);
        pos += 2;
        buf[pos] = 0; // reserved
        pos += 1;

        // pixels
        const pixel_count = @as(usize, frame.width) * @as(usize, frame.height);
        @memcpy(buf[pos .. pos + pixel_count], frame.pixels);
        pos += pixel_count;
    }

    return buf;
}

pub fn toFile(allocator: Allocator, image: *const ZxlImage, path: []const u8) !void {
    const bytes = try toBytes(allocator, image);
    defer allocator.free(bytes);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(bytes);
}

fn writeU16Le(buf: *[2]u8, val: u16) void {
    buf.* = @bitCast(std.mem.nativeToLittle(u16, val));
}

fn writeI16Le(buf: *[2]u8, val: i16) void {
    buf.* = @bitCast(std.mem.nativeToLittle(i16, val));
}
