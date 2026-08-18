const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const tok = @import("token.zig");
const Token = tok.Token;
const Tag = tok.Token.Tag;

const single_char_tokens = std.StaticStringMap(Token.Tag).initComptime(.{
    .{ "{", .l_brace },   .{ "}", .r_brace },
    .{ "[", .l_bracket }, .{ "]", .r_bracket },
    .{ ",", .comma },     .{ "-", .minus },
    .{ ":", .colon },
});

const keywords = std.StaticStringMap(Token.Tag).initComptime(.{
    .{ "true", .true }, .{ "false", .false },
});

pub const Lexer = struct {
    src: [:0]const u8,
    idx: u32 = 0,

    const State = enum {
        start,
        identifier,
        number,
        string,
        color,
        comment,
        invalid,
        invalid_number,
    };

    pub fn init(
        src: [:0]const u8,
    ) Lexer {
        return .{
            .src = src,
        };
    }

    pub fn next(self: *Lexer) Token {
        var tok_start: u32 = undefined;
        var hex_count: u32 = 0;
        var seen_dot = false;

        assert(self.idx <= self.src.len);

        return state: switch (State.start) {
            .start => switch (self.src[self.idx]) {
                ' ', '\t', '\r', '\n' => {
                    self.idx += 1;
                    continue :state .start;
                },
                0 => return .{
                    .tag = .eof,
                    .loc = .{ .start = self.idx, .end = self.idx },
                },
                '/' => {
                    if (self.src[self.idx + 1] == '/')
                        continue :state .comment
                    else {
                        tok_start = self.idx;
                        self.idx += 1;
                        continue :state .invalid;
                    }
                },
                '{', '}', '[', ']', ':', ',', '-' => |c| {
                    const tag = single_char_tokens.get(&.{c}) orelse .invalid;
                    self.idx += 1;
                    return .{
                        .tag = tag,
                        .loc = .{ .start = self.idx - 1, .end = self.idx },
                    };
                },
                '"' => {
                    tok_start = self.idx;
                    self.idx += 1;
                    continue :state .string;
                },
                '#' => {
                    tok_start = self.idx;
                    self.idx += 1;
                    continue :state .color;
                },
                '0'...'9' => {
                    tok_start = self.idx;
                    continue :state .number;
                },
                'A'...'Z', 'a'...'z', '_' => {
                    tok_start = self.idx;
                    continue :state .identifier;
                },
                else => {
                    tok_start = self.idx;
                    self.idx += 1;
                    continue :state .invalid;
                },
            },
            .comment => {
                switch (self.src[self.idx]) {
                    '\n', 0 => continue :state .start,
                    else => {
                        self.idx += 1;
                        continue :state .comment;
                    },
                }
            },
            .string => {
                switch (self.src[self.idx]) {
                    '"' => {
                        self.idx += 1;
                        return .{
                            .tag = .string_lit,
                            .loc = .{ .start = tok_start + 1, .end = self.idx - 1 },
                        };
                    },
                    0 => return .{
                        .tag = .invalid,
                        .loc = .{ .start = tok_start, .end = self.idx },
                    },
                    else => {
                        self.idx += 1;
                        continue :state .string;
                    },
                }
            },
            .color => {
                switch (self.src[self.idx]) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        self.idx += 1;
                        hex_count += 1;
                        continue :state .color;
                    },
                    else => {
                        if (hex_count == 6 or hex_count == 8) {
                            return .{
                                .tag = .color_lit,
                                .loc = .{ .start = tok_start + 1, .end = self.idx },
                            };
                        } else return .{
                            .tag = .invalid,
                            .loc = .{ .start = tok_start, .end = self.idx },
                        };
                    },
                }
            },
            .number => {
                switch (self.src[self.idx]) {
                    '0'...'9' => {
                        self.idx += 1;
                        continue :state .number;
                    },
                    '.' => {
                        if (seen_dot)
                            continue :state .invalid_number;

                        seen_dot = true;
                        switch (self.src[self.idx + 1]) {
                            '0'...'9' => {
                                self.idx += 1;
                                continue :state .number;
                            },
                            else => return .{
                                .tag = .number,
                                .loc = .{ .start = tok_start, .end = self.idx },
                            },
                        }
                    },
                    else => return .{
                        .tag = .number,
                        .loc = .{ .start = tok_start, .end = self.idx },
                    },
                }
            },
            .identifier => {
                switch (self.src[self.idx]) {
                    'A'...'Z', 'a'...'z', '0'...'9', '_' => {
                        self.idx += 1;
                        continue :state .identifier;
                    },
                    else => {
                        const word = self.src[tok_start..self.idx];
                        const tag = keywords.get(word) orelse .identifier;
                        return .{
                            .tag = tag,
                            .loc = .{ .start = tok_start, .end = self.idx },
                        };
                    },
                }
            },
            .invalid => return .{
                .tag = .invalid,
                .loc = .{ .start = tok_start, .end = self.idx },
            },
            .invalid_number => {
                switch (self.src[self.idx]) {
                    '0'...'9', '.', '_' => {
                        self.idx += 1;
                        continue :state .invalid_number;
                    },
                    else => return .{
                        .tag = .invalid,
                        .loc = .{ .start = tok_start, .end = self.idx },
                    },
                }
            },
        };
    }

    inline fn single(self: *Lexer, tag: Token.Tag) Token {
        self.idx += 1;
        return .{
            .tag = tag,
            .loc = .{ .start = self.idx - 1, .end = self.idx },
        };
    }
};

// Collect the tag stream (excluding the final .eof) for a source string.
fn tags(src: [:0]const u8, buf: []Tag) []Tag {
    var l = Lexer.init(src);
    var n: usize = 0;
    while (true) {
        const t = l.next();
        if (t.tag == .eof) break;
        buf[n] = t.tag;
        n += 1;
    }
    return buf[0..n];
}

fn expectTags(src: [:0]const u8, expected: []const Tag) !void {
    var buf: [64]Tag = undefined;
    try testing.expectEqualSlices(Tag, expected, tags(src, &buf));
}

// --- the milestone: a full noun ------------------------------------------------

test "milestone: Ball : circle { radius 0.35 fill white collides }" {
    try expectTags(
        "Ball : circle { radius 0.35 fill white collides }",
        &.{
            .identifier, // Ball
            .colon, //     :
            .identifier, // circle
            .l_brace, //   {
            .identifier, // radius
            .number, //    0.35
            .identifier, // fill
            .identifier, // white
            .identifier, // collides   (a flag is just an identifier at the lexer level)
            .r_brace, //   }
        },
    );
}

// --- single-char tokens --------------------------------------------------------

test "delimiters each lex to one token" {
    try expectTags("{}:,-", &.{ .l_brace, .r_brace, .colon, .comma, .minus });
}

// --- whitespace is insignificant ----------------------------------------------

test "whitespace and newlines are skipped, no indent/dedent tokens" {
    try expectTags("  {\n\t}  ", &.{ .l_brace, .r_brace });
}

// --- comments produce no tokens ------------------------------------------------

test "line comment is skipped entirely" {
    try expectTags("{ // this is a comment\n }", &.{ .l_brace, .r_brace });
}

test "comment running to EOF (no trailing newline)" {
    try expectTags("{ } // trailing", &.{ .l_brace, .r_brace });
}

// --- identifiers & keywords ----------------------------------------------------

test "true and false are keywords, other words are identifiers" {
    try expectTags("true false circle radius", &.{ .true, .false, .identifier, .identifier });
}

test "identifiers may contain digits and underscores" {
    try expectTags("half_width x2 _hidden", &.{ .identifier, .identifier, .identifier });
}

// --- numbers -------------------------------------------------------------------

test "integer and float numbers" {
    try expectTags("7 0.35 100", &.{ .number, .number, .number });
}

test "float numbers with missing digits" {
    try expectTags("0.35 100. .045", &.{ .number, .number, .invalid, .invalid, .number });
}

test "multi-dot number is invalid, not a number" {
    try expectTags("0.35.100", &.{.invalid}); // one bad number-token
    try expectTags("1.2.3", &.{.invalid});
}

test "negative number lexes as minus then number" {
    try expectTags("-6.0", &.{ .minus, .number });
}

// --- strings -------------------------------------------------------------------

test "string literal, span excludes the quotes" {
    var l = Lexer.init("\"ball\"");
    const t = l.next();
    try testing.expectEqual(Tag.string_lit, t.tag);
    try testing.expectEqualStrings("ball", t.loc.slice("\"ball\""));
}

test "unterminated string is invalid, not a thrown error" {
    try expectTags("\"oops", &.{.invalid});
}

// --- colors --------------------------------------------------------------------

test "6-digit color, span excludes the hash" {
    var l = Lexer.init("#4488FF");
    const t = l.next();
    try testing.expectEqual(Tag.color_lit, t.tag);
    try testing.expectEqualStrings("4488FF", t.loc.slice("#4488FF"));
}

test "8-digit color is valid" {
    try expectTags("#4488FFAA", &.{.color_lit});
}

test "wrong-length color is invalid" {
    try expectTags("#123", &.{.invalid});
}

// --- bad input never throws ----------------------------------------------------

test "a stray character is an invalid token, lexing continues" {
    try expectTags("{ @,. }", &.{ .l_brace, .invalid, .comma, .invalid, .r_brace });
}

test "a stray character is not greedy, lexing continues" {
    try expectTags("{ @foo }", &.{ .l_brace, .invalid, .identifier, .r_brace });
}

// --- vectors are brackets + numbers + commas (structure, not a vec token) ---
// Brackets, not braces: `{` is unambiguously a node body, `[` a vec value.

test "a vec literal [7, 5] is delimiter tokens (typed later at ingest)" {
    try expectTags("[7, 5]", &.{ .l_bracket, .number, .comma, .number, .r_bracket });
}

test "brackets and braces are distinct tokens" {
    try expectTags("[]{}", &.{ .l_bracket, .r_bracket, .l_brace, .r_brace });
}
