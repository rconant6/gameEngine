const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const math = @import("math");
const Rgba = math.Rgba;

const max_colors = 256;

pub const ZxlPalette = struct {
    colors: [max_colors]Rgba = [_]Rgba{.{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    }} ** max_colors, // RGBA, index 0 = transparent
    count: u8 = 1, // always have clear in 0

    pub fn addColor(self: *ZxlPalette, rgba: Rgba) u8 {
        if (self.count >= 255) return 0;
        const idx = self.count;
        self.colors[idx] = rgba;
        self.count += 1;

        return idx;
    }
    pub fn findColor(self: *const ZxlPalette, rgba: Rgba) ?u8 {
        for (self.colors[0..self.count], 0..) |color, i| {
            if (@as(u32, @bitCast(rgba)) ==
                @as(u32, @bitCast(color))) return @intCast(i);
        }
        return null;
    }
    pub fn getColor(self: *const ZxlPalette, index: u8) Rgba {
        if (index >= self.count) {
            return Rgba.clear;
        }
        return self.colors[index];
    }
};

pub const ZxlFrame = struct {
    name: []const u8, // allocated
    pixels: []u8, // palette indices, len = w * h
    width: u16,
    height: u16,
    duration_ms: u16,
    origin_x: i16,
    origin_y: i16,

    pub fn getPixel(self: *const ZxlFrame, x: usize, y: usize) u8 {
        const idx = y * self.width + x;
        return self.pixels[idx];
    }
    // pub fn setPixel(self: *ZxlFrame, x: usize, y: usize, width: usize, index: u8) u8 {
    //     _ = self;
    //     _ = x;
    //     _ = y;
    //     _ = width;
    //     _ = index;
    //     return 0;
    // }
};

pub const ZxlImage = struct {
    gpa: Allocator,
    name: []u8,
    frames: ArrayList(ZxlFrame),
    palette: ZxlPalette,

    pub fn init(allocator: Allocator, name: []const u8) !ZxlImage {
        return .{
            .gpa = allocator,
            .name = try allocator.dupe(u8, name),
            .frames = .empty,
            .palette = .{},
        };
    }
    pub fn deinit(self: *ZxlImage) void {
        for (self.frames.items) |*frame| {
            self.gpa.free(frame.pixels);
            self.gpa.free(frame.name);
        }

        self.frames.deinit(self.gpa);
        self.gpa.free(self.name);
    }

    pub fn addFrame(
        self: *ZxlImage,
        name: []const u8,
        width: u16,
        height: u16,
        pixels: []const u8,
        duration_ms: u16,
        origin_x: i16,
        origin_y: i16,
    ) !void {
        const expected_len = @as(usize, width) * @as(usize, height);
        if (pixels.len != expected_len) {
            return error.InvalidPixelData;
        }

        const name_copy = try self.gpa.dupe(u8, name);
        const pixel_copy = try self.gpa.dupe(u8, pixels);

        try self.frames.append(self.gpa, .{
            .name = name_copy,
            .pixels = pixel_copy,
            .width = width,
            .height = height,
            .duration_ms = duration_ms,
            .origin_x = origin_x,
            .origin_y = origin_y,
        });
    }
    pub fn getFrame(self: *const ZxlImage, index: usize) ?*const ZxlFrame {
        if (index >= self.frames.items.len) return null;
        return &self.frames.items[index];
    }
    pub fn getFrameByName(self: *const ZxlImage, name: []const u8) ?*const ZxlFrame {
        for (self.frames.items) |*frame| {
            if (std.mem.eql(u8, frame.name, name)) {
                return frame;
            }
        }
        return null;
    }

    pub fn toRgbaBuffer(self: *const ZxlImage, frame_index: usize) ![]u8 {
        const frame = self.getFrame(frame_index) orelse return error.InvalidFrame;

        const pixel_count = @as(usize, frame.width) * @as(usize, frame.height);
        const out = try self.gpa.alloc(u8, pixel_count * 4);

        var i: usize = 0;
        while (i < pixel_count) : (i += 1) {
            const palette_idx = frame.pixels[i];
            const color = self.palette.getColor(palette_idx);

            const base = i * 4;
            out[base + 0] = color.r;
            out[base + 1] = color.g;
            out[base + 2] = color.b;
            out[base + 3] = color.a;
        }

        return out;
    }
    // pub fn toRgbaBufferWithPalette(frame_index: usize, alt_palette: *const ZxlPalette) []u8 {
    //     _ = frame_index;
    //     _ = alt_palette;
    // }
};
