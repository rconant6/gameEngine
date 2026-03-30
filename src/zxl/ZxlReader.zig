const std = @import("std");
const Allocator = std.mem.Allocator;
const img = @import("ZxlImage.zig");
const ZxlImage = img.ZxlImage;
const ZxlPalette = img.ZxlPalette;
const math = @import("math");
const Rgba = math.Rgba;
const log = @import("debug").log;

pub const ReadError = error{
    InvalidMagic,
    UnsupportedVersion,
    UnexpectedEof,
    InvalidPixelData,
    InvalidPixelIndex,
} || Allocator.Error;

const magic = "ZXL\x00";

pub fn fromBytes(allocator: Allocator, data: []const u8) ReadError!ZxlImage {
    if (data.len < 16) return error.UnexpectedEof;

    if (!std.mem.eql(u8, data[0..4], magic)) return error.InvalidMagic;

    const version = data[4];
    if (version != 1) return error.UnsupportedVersion;

    // NOTE: Header fields
    const frame_count = readU16Le(data[6..8]);
    const canvas_width = readU16Le(data[8..10]);
    const canvas_height = readU16Le(data[10..12]);
    const palette_size_raw = data[12];

    // NOTE: For now we cap at 255 since ZxlPalette.count is u8.
    const effective_palette_size: u16 = if (palette_size_raw == 0)
        256
    else
        @as(u16, palette_size_raw);

    const palette_bytes = effective_palette_size * 4;
    if (data.len < 16 + palette_bytes) return error.UnexpectedEof;

    var palette = ZxlPalette{};
    palette.count = @truncate(effective_palette_size);
    for (0..effective_palette_size) |i| {
        const base = 16 + i * 4;
        palette.colors[i] = .{
            .r = data[base + 0],
            .g = data[base + 1],
            .b = data[base + 2],
            .a = data[base + 3],
        };
    }

    var pos: usize = 16 + palette_bytes;

    var image = try ZxlImage.init(allocator, "");
    errdefer image.deinit();
    image.palette = palette;

    for (0..frame_count) |_| {
        if (pos + 1 > data.len) return error.UnexpectedEof;
        const name_len = data[pos];
        pos += 1;

        if (pos + name_len > data.len) return error.UnexpectedEof;
        const name = data[pos .. pos + name_len];
        pos += name_len;

        // Frame fields: duration(2) + origin_x(2) + origin_y(2) + reserved(1) = 7 bytes
        if (pos + 7 > data.len) return error.UnexpectedEof;
        const duration_ms = readU16Le(data[pos..][0..2]);
        pos += 2;
        const origin_x = readI16Le(data[pos..][0..2]);
        pos += 2;
        const origin_y = readI16Le(data[pos..][0..2]);
        pos += 2;
        pos += 1; // reserved

        const pixel_count = @as(usize, canvas_width) * @as(usize, canvas_height);
        if (pos + pixel_count > data.len) return error.UnexpectedEof;
        const pixels = data[pos .. pos + pixel_count];
        pos += pixel_count;

        try image.addFrame(name, canvas_width, canvas_height, pixels, duration_ms, origin_x, origin_y);
    }

    return image;
}

pub fn fromFile(allocator: Allocator, path: []const u8) !ZxlImage {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.err(.application, "Unable to open file {s}: {any}", .{ path, err });
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const buf = try allocator.alloc(u8, file_size);
    defer allocator.free(buf);

    const bytes_read = try file.readAll(buf);
    _ = bytes_read;

    return try fromBytes(allocator, buf);
}

fn readU16Le(bytes: *const [2]u8) u16 {
    return std.mem.littleToNative(u16, @bitCast(bytes.*));
}

fn readI16Le(bytes: *const [2]u8) i16 {
    return std.mem.littleToNative(i16, @bitCast(bytes.*));
}
