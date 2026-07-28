const std = @import("std");
const testing = std.testing;
const assets = @import("assets");
const math = @import("math");
const V2 = math.V2;

const sdf = assets.sdf;
const FilteredGlyph = assets.FilteredGlyph;

// Build a FilteredGlyph from one closed contour of V2 points (em units).
// contour_ends is the inclusive last index of the contour.
fn glyph(points: []V2) FilteredGlyph {
    const ends = struct {
        var buf: [1]u16 = undefined;
    };
    ends.buf[0] = @intCast(points.len - 1);
    return .{
        .points = points,
        .contour_ends = &ends.buf,
        .contour_count = 1,
        .total_points = @intCast(points.len),
    };
}

// A square filling the middle of the em box → clear inside/outside.
// Points are EM-NORMALIZED ([0,1] == one em), matching real glyph.points.
fn squareGlyph() FilteredGlyph {
    const lo: f32 = 0.25;
    const hi: f32 = 0.75;
    const S = struct {
        var pts: [4]V2 = undefined;
    };
    S.pts = .{
        .{ .x = lo, .y = lo },
        .{ .x = hi, .y = lo },
        .{ .x = hi, .y = hi },
        .{ .x = lo, .y = hi },
    };
    return glyph(&S.pts);
}

// Allocate a standalone dst sized to one cell, target origin (0,0), stride = cell.
const Cell = struct {
    pixels: []u8,
    dim: u16, // cell_px + 2*pad, both w and h

    fn init(cell_px: u16, pad: u16) !Cell {
        const dim = cell_px + 2 * pad;
        const pixels = try testing.allocator.alloc(u8, @as(usize, dim) * dim);
        @memset(pixels, 0);
        return .{ .pixels = pixels, .dim = dim };
    }
    fn deinit(self: *Cell) void {
        testing.allocator.free(self.pixels);
    }
    fn at(self: Cell, x: u16, y: u16) u8 {
        return self.pixels[@as(usize, y) * self.dim + x];
    }
    fn target(self: Cell) sdf.Target {
        return .{ .pixels = self.pixels, .stride = self.dim, .gx = 0, .gy = 0 };
    }
};

test "rasterInto returns size cell_px + 2*pad" {
    const cell: u16 = 32;
    const pad: u16 = 4;
    var g = squareGlyph();
    var c = try Cell.init(cell, pad);
    defer c.deinit();

    const sz = sdf.rasterInto(c.target(), &g, cell, pad);
    try testing.expectEqual(@as(u16, cell + 2 * pad), sz.w);
    try testing.expectEqual(@as(u16, cell + 2 * pad), sz.h);
}

test "coverage: pixels are only 0 or 255" {
    var g = squareGlyph();
    var c = try Cell.init(32, 4);
    defer c.deinit();

    _ = sdf.rasterInto(c.target(), &g, 32, 4);
    for (c.pixels) |p| try testing.expect(p == 0 or p == 255);
}

test "coverage: center of a filled square is inside (255)" {
    var g = squareGlyph();
    var c = try Cell.init(32, 4);
    defer c.deinit();

    _ = sdf.rasterInto(c.target(), &g, 32, 4);
    try testing.expectEqual(@as(u8, 255), c.at(c.dim / 2, c.dim / 2));
}

test "coverage: pad-border corners are outside (0)" {
    var g = squareGlyph();
    var c = try Cell.init(32, 4);
    defer c.deinit();

    _ = sdf.rasterInto(c.target(), &g, 32, 4);
    try testing.expectEqual(@as(u8, 0), c.at(0, 0));
    try testing.expectEqual(@as(u8, 0), c.at(c.dim - 1, c.dim - 1));
}

test "coverage: non-degenerate (some in, some out)" {
    var g = squareGlyph();
    var c = try Cell.init(32, 4);
    defer c.deinit();

    _ = sdf.rasterInto(c.target(), &g, 32, 4);
    var any_on = false;
    var any_off = false;
    for (c.pixels) |p| {
        if (p == 255) any_on = true;
        if (p == 0) any_off = true;
    }
    try testing.expect(any_on and any_off);
}

test "empty glyph writes nothing (dst stays 0)" {
    var g = FilteredGlyph{};
    var c = try Cell.init(16, 2);
    defer c.deinit();

    _ = sdf.rasterInto(c.target(), &g, 16, 2);
    for (c.pixels) |p| try testing.expectEqual(@as(u8, 0), p);
}

test "rasterInto writes only into its rect (offset target)" {
    // dst is 2 cells wide; write the glyph into the RIGHT cell, assert the left
    // cell is untouched. Proves gx/gy/stride land pixels in the right place.
    const cell: u16 = 16;
    const pad: u16 = 2;
    const dim: u16 = cell + 2 * pad;
    const stride: u16 = dim * 2;

    const pixels = try testing.allocator.alloc(u8, @as(usize, stride) * dim);
    defer testing.allocator.free(pixels);
    @memset(pixels, 0);

    var g = squareGlyph();
    _ = sdf.rasterInto(
        .{ .pixels = pixels, .stride = stride, .gx = dim, .gy = 0 },
        &g,
        cell,
        pad,
    );

    // left half (cols 0..dim) must be all zero
    var y: u16 = 0;
    while (y < dim) : (y += 1) {
        var x: u16 = 0;
        while (x < dim) : (x += 1) {
            try testing.expectEqual(@as(u8, 0), pixels[@as(usize, y) * stride + x]);
        }
    }
    // right half must have some coverage
    var any_on = false;
    y = 0;
    while (y < dim) : (y += 1) {
        var x: u16 = dim;
        while (x < stride) : (x += 1) {
            if (pixels[@as(usize, y) * stride + x] == 255) any_on = true;
        }
    }
    try testing.expect(any_on);
}
