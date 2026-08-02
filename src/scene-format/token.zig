const std = @import("std");
const assert = std.debug.assert;

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub fn format(self: Token, w: *std.Io.Writer) !void {
        try w.print(
            "[TOKEN]\n  Tag: {}\n  Loc: {f}",
            .{ self.tag, self.loc },
        );
    }

    pub const Tag = enum {
        l_brace,
        r_brace,
        colon,
        comma,
        identifier,
        number,
        string_lit,
        color_lit,
        true,
        false,
        minus,
        eof,
        invalid,
    };
};

pub const Loc = struct {
    start: u32 = undefined,
    end: u32 = undefined,

    pub fn slice(loc: Loc, src: [:0]const u8) []const u8 {
        assert(loc.end <= src.len);

        return src[loc.start..loc.end];
    }

    pub fn getSelection(loc: Loc, src: [:0]const u8) CodeSegment {
        assert(loc.end <= src.len);

        var selection: CodeSegment = .{
            .start = .{ .line = 1, .col = 1 },
            .end = undefined,
        };

        for (src[0..loc.start]) |c| {
            if (c == '\n') {
                selection.start.line += 1;
                selection.start.col = 1;
            } else selection.start.col += 1;
        }

        selection.end = selection.start;
        for (src[loc.start..loc.end]) |c| {
            if (c == '\n') {
                selection.end.line += 1;
                selection.end.col = 1;
            } else selection.end.col += 1;
        }

        return selection;
    }

    pub fn format(self: Loc, w: *std.Io.Writer) !void {
        const fmt =
            \\[Loc]: Start: {d}  End: {d}
        ;
        try w.print(
            fmt,
            .{ self.start, self.end },
        );
    }

    pub const CodeSegment = struct {
        start: Position,
        end: Position,

        pub const Position = struct {
            line: u32,
            col: u32,
        };

        pub fn format(self: CodeSegment, w: *std.Io.Writer) !void {
            const fmt =
                \\[Seg]: Start[line: {d}  col {d}]
                \\         End[line: {d}  col {d}]
            ;
            try w.print(
                fmt,
                .{
                    self.start.line, self.start.col,
                    self.end.line,   self.end.col,
                },
            );
        }
    };
};

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

test "Loc.slice returns the exact bytes of the span" {
    const src: [:0]const u8 = "Ball : circle";
    const loc: Loc = .{ .start = 0, .end = 4 };
    try testing.expectEqualStrings("Ball", loc.slice(src));
}

test "Loc.slice handles a span ending at the last byte" {
    // regression: end == src.len is a VALID slice (last-byte token, no trailing newline)
    const src: [:0]const u8 = "abc";
    const loc: Loc = .{ .start = 0, .end = 3 };
    try testing.expectEqualStrings("abc", loc.slice(src));
}

test "Loc.slice of a single-char span" {
    const src: [:0]const u8 = "a{b}";
    const loc: Loc = .{ .start = 1, .end = 2 };
    try testing.expectEqualStrings("{", loc.slice(src));
}

test "getSelection: single-line span reports 1-based line/col" {
    const src: [:0]const u8 = "radius 0.35";
    // "0.35" occupies bytes 7..11
    const loc: Loc = .{ .start = 7, .end = 11 };
    const sel = loc.getSelection(src);
    try testing.expectEqual(@as(u32, 1), sel.start.line);
    try testing.expectEqual(@as(u32, 8), sel.start.col); // 1-based: byte offset 7 → col 8
    try testing.expectEqual(@as(u32, 1), sel.end.line);
    try testing.expectEqual(@as(u32, 12), sel.end.col);
}

test "getSelection: span on the second line" {
    const src: [:0]const u8 = "Ball\nradius";
    // "radius" is on line 2, bytes 5..11
    const loc: Loc = .{ .start = 5, .end = 11 };
    const sel = loc.getSelection(src);
    try testing.expectEqual(@as(u32, 2), sel.start.line);
    try testing.expectEqual(@as(u32, 1), sel.start.col);
    try testing.expectEqual(@as(u32, 2), sel.end.line);
    try testing.expectEqual(@as(u32, 7), sel.end.col);
}

test "getSelection: span crossing a newline" {
    const src: [:0]const u8 = "a\nb";
    const loc: Loc = .{ .start = 0, .end = 3 };
    const sel = loc.getSelection(src);
    try testing.expectEqual(@as(u32, 1), sel.start.line);
    try testing.expectEqual(@as(u32, 2), sel.end.line);
}
