const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ts = @import("types.zig");
const Range = ts.Range;
const Position = ts.Position;
const sfmt = ts.sfmt;
const Loc = sfmt.Loc;

const Self = @This();

line_starts: []const u32,
src: [:0]const u8,

pub fn build(gpa: Allocator, src: [:0]const u8) !Self {
    var lines: ArrayList(u32) = .empty;

    try lines.append(gpa, 0);

    for (src, 0..) |c, i| {
        if (c == '\n') try lines.append(gpa, @intCast(i + 1));
    }

    return .{
        .line_starts = try lines.toOwnedSlice(gpa),
        .src = src,
    };
}
pub fn deinit(self: *const Self, gpa: Allocator) void {
    gpa.free(self.line_starts);
}

pub fn posOf(self: Self, byte: u32) Position {
    const S = struct {
        fn compareU32(context: u32, item: u32) std.math.Order {
            return std.math.order(context, item);
        }
    };

    const line = std.sort.upperBound(
        u32,
        self.line_starts,
        byte,
        S.compareU32,
    ) - 1;
    const line_start = self.line_starts[line];

    var character: u32 = 0;
    var idx = line_start;

    while (idx < byte) {
        const cp_len = std.unicode.utf8ByteSequenceLength(self.src[idx]) catch unreachable;

        const codepoint = std.unicode.utf8Decode(
            self.src[idx .. idx + cp_len],
        ) catch unreachable;

        character += if (codepoint <= 0x10000) 1 else 2;
        idx += cp_len;
    }

    return .{
        .character = character,
        .line = @intCast(line),
    };
}
pub fn rangeOf(self: Self, loc: Loc) Range {
    return Range{
        .start = self.posOf(loc.start),
        .end = self.posOf(loc.end),
    };
}

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

test "posOf: byte 0 is line 0, character 0" {
    var li = try Self.build(testing.allocator, "radius 0.35");
    defer li.deinit(testing.allocator);

    const p = li.posOf(0);
    try testing.expectEqual(@as(u32, 0), p.line);
    try testing.expectEqual(@as(u32, 0), p.character);
}

test "posOf: a byte partway into the first line" {
    // "0.35" starts at byte 7 on the single line.
    var li = try Self.build(testing.allocator, "radius 0.35");
    defer li.deinit(testing.allocator);

    const p = li.posOf(7);
    try testing.expectEqual(@as(u32, 0), p.line);
    try testing.expectEqual(@as(u32, 7), p.character);
}

test "posOf: a byte on the second line resets character to line-relative" {
    // "Ball\nradius" — 'r' of "radius" is byte 5, line 1, character 0.
    var li = try Self.build(testing.allocator, "Ball\nradius");
    defer li.deinit(testing.allocator);

    const p = li.posOf(5);
    try testing.expectEqual(@as(u32, 1), p.line);
    try testing.expectEqual(@as(u32, 0), p.character);
}

test "posOf: character is line-relative, not absolute" {
    // "ab\ncd" — 'd' is byte 4, line 1, character 1 (not 4).
    var li = try Self.build(testing.allocator, "ab\ncd");
    defer li.deinit(testing.allocator);

    const p = li.posOf(4);
    try testing.expectEqual(@as(u32, 1), p.line);
    try testing.expectEqual(@as(u32, 1), p.character);
}

test "posOf: character counts UTF-16 code units, not bytes" {
    // 'é' (U+00E9) is 2 bytes in UTF-8 but 1 UTF-16 code unit.
    // "é" occupies bytes 0..2; the byte after it (2) is character 1.
    var li = try Self.build(testing.allocator, "\u{00E9}x");
    defer li.deinit(testing.allocator);

    const p = li.posOf(2); // the 'x', one UTF-16 unit past 'é'
    try testing.expectEqual(@as(u32, 0), p.line);
    try testing.expectEqual(@as(u32, 1), p.character);
}

test "posOf: an astral char is two UTF-16 code units" {
    // '😀' (U+1F600) is 4 bytes in UTF-8 and 2 UTF-16 code units (surrogate pair).
    // The byte after it (4) is character 2.
    var li = try Self.build(testing.allocator, "\u{1F600}x");
    defer li.deinit(testing.allocator);

    const p = li.posOf(4); // the 'x', two UTF-16 units past the emoji
    try testing.expectEqual(@as(u32, 0), p.line);
    try testing.expectEqual(@as(u32, 2), p.character);
}

test "posOf: last line without a trailing newline" {
    // "a\nb" — 'b' is byte 2, line 1, character 0. No trailing '\n'.
    var li = try Self.build(testing.allocator, "a\nb");
    defer li.deinit(testing.allocator);

    const p = li.posOf(2);
    try testing.expectEqual(@as(u32, 1), p.line);
    try testing.expectEqual(@as(u32, 0), p.character);
}

test "rangeOf: a Loc maps to start/end Positions" {
    // "radius 0.35" — Loc over "0.35" is bytes 7..11, all on line 0.
    var li = try Self.build(testing.allocator, "radius 0.35");
    defer li.deinit(testing.allocator);

    const r = li.rangeOf(.{ .start = 7, .end = 11 });
    try testing.expectEqual(@as(u32, 0), r.start.line);
    try testing.expectEqual(@as(u32, 7), r.start.character);
    try testing.expectEqual(@as(u32, 0), r.end.line);
    try testing.expectEqual(@as(u32, 11), r.end.character);
}

test "rangeOf: a Loc spanning a newline" {
    // "a\nb" — Loc 0..3 starts line 0 char 0, ends line 1 char 1.
    var li = try Self.build(testing.allocator, "a\nb");
    defer li.deinit(testing.allocator);

    const r = li.rangeOf(.{ .start = 0, .end = 3 });
    try testing.expectEqual(@as(u32, 0), r.start.line);
    try testing.expectEqual(@as(u32, 0), r.start.character);
    try testing.expectEqual(@as(u32, 1), r.end.line);
    try testing.expectEqual(@as(u32, 1), r.end.character);
}
