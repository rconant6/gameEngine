const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const tok = @import("token.zig");
const Token = tok.Token;
const SourceLocation = tok.SourceLocation;
const DataLocation = tok.DataLocation;

pub const LexerError = error{
    InvalidCharacter,
    InvalidColor,
    InvalidIndentation,
    InvalidNumber,
    TabIndentationFound,
    UnclosedString,
};

pub fn lexeme(src: [:0]const u8, token: Token) []const u8 {
    const start = token.loc.start;
    const end = token.loc.end;
    return src[start..end];
}

pub const Lexer = struct {
    const single_char_tokens = std.StaticStringMap(Token.Tag).initComptime(.{
        .{ "[", .l_bracket }, .{ "]", .r_bracket },
        .{ "{", .l_brace },   .{ "}", .r_brace },
        .{ ",", .comma },     .{ ".", .dot },
        .{ "-", .minus },     .{ ":", .colon },
    });

    const keywords = std.StaticStringMap(Token.Tag).initComptime(.{
        .{ "true", .true },           .{ "false", .false },
        .{ "scene", .scene },         .{ "string", .string },
        .{ "asset", .asset },         .{ "entity", .entity },
        .{ "shape", .shape },         .{ "vec2", .vec2 },
        .{ "vec3", .vec3 },           .{ "f32", .f32 },
        .{ "i32", .i32 },             .{ "u32", .u32 },
        .{ "bool", .bool },           .{ "color", .color },
        .{ "asset_ref", .asset_ref }, .{ "font", .font },
        .{ "template", .template },
    });

    src: [:0]const u8,
    index: u32 = 0,
    token_start: u32 = 0,
    src_loc: SourceLocation = .{ .line = 1, .col = 1, .len = 0 },

    hex_color_count: u32 = 0,
    indent_level: u32 = 0,
    dedents_left: u32 = 0,
    space_count: u32 = 0,

    const State = enum {
        start,
        comment,
        comment_start,
        fresh_line,
        identifier,
        number,
        number_after_dot,
        string,
        color,
        dedent_end,
        end,
    };

    const MAX_ERRORS: usize = 32;

    pub fn init(
        src: [:0]const u8,
    ) Lexer {
        return .{
            .src = src,
        };
    }

    pub fn next(self: *Lexer) !?Token {
        if (self.dedents_left > 0) {
            self.dedents_left -= 1;
            return self.consumeToken(.dedent);
        }
        state: switch (State.start) {
            .fresh_line => _fresh_line: switch (self.src[self.index]) {
                ' ' => {
                    self.advance();
                    self.space_count += 1;
                    self.token_start = self.index;
                    continue :_fresh_line self.src[self.index];
                },
                '\n' => {
                    self.newline();
                    self.advance();
                    self.space_count = 0;
                    self.token_start = self.index;
                    continue :_fresh_line self.src[self.index];
                },
                '/' => {
                    self.space_count = 0;
                    self.advance();
                    continue :state .comment_start;
                },
                '\t' => {
                    self.space_count = 0;

                    return LexerError.TabIndentationFound;
                },
                0 => continue :state .dedent_end,
                else => {
                    self.token_start = self.index;
                    if (self.space_count == self.indent_level) {
                        self.space_count = 0;
                        continue :state .start;
                    } else if (self.space_count > self.indent_level) {
                        if (self.space_count != self.indent_level + 2) {
                            return LexerError.InvalidIndentation;
                        }

                        self.indent_level = self.space_count;
                        self.space_count = 0;

                        return self.consumeToken(.indent);
                    } else {
                        const delta = self.indent_level - self.space_count;
                        if (delta % 2 != 0) {
                            return LexerError.InvalidIndentation;
                        }
                        self.indent_level = self.space_count;
                        self.dedents_left = (delta / 2) - 1;
                        self.space_count = 0;
                        return self.consumeToken(.dedent);
                    }
                },
            },
            .start => _start: switch (self.src[self.index]) {
                else => return LexerError.InvalidCharacter,
                0 => continue :state .dedent_end,
                ' ', '\t', '\r' => {
                    if (self.src_loc.col == 1) {
                        self.space_count = 0;
                        continue :state .fresh_line;
                    }
                    self.advance();
                    continue :_start self.src[self.index];
                },
                '\n' => {
                    self.advance();
                    self.newline();
                    continue :state .fresh_line;
                },
                '/' => {
                    self.token_start = self.index;
                    self.advance();
                    continue :state .comment_start;
                },
                '"' => {
                    self.token_start = self.index;
                    self.advance();
                    continue :state .string;
                },
                '#' => {
                    self.token_start = self.index;
                    self.advance();
                    self.hex_color_count = 0;
                    continue :state .color;
                },
                '[', ']', ',', '-', '{', '}', ':' => |c| {
                    // self.token_start = self.index;
                    const tag = single_char_tokens.get(&.{c}) orelse
                        return LexerError.InvalidCharacter;
                    self.advance();
                    return self.consumeToken(tag);
                },
                'A'...'Z', 'a'...'z', '_' => {
                    self.token_start = self.index;
                    continue :state .identifier;
                },
                '0'...'9' => {
                    self.token_start = self.index;
                    continue :state .number;
                },
            },
            .comment_start => {
                if (self.src[self.index] == '/') continue :state .comment;
                return LexerError.InvalidCharacter;
            },
            .comment => _comment: switch (self.src[self.index]) {
                0 => continue :state .dedent_end,
                '\n' => {
                    self.advance();
                    self.newline();
                    self.space_count = 0;
                    self.token_start = self.index;
                    continue :state .fresh_line;
                },
                else => {
                    self.advance();
                    continue :_comment self.src[self.index];
                },
            },
            .identifier => _id: switch (self.src[self.index]) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => {
                    self.advance();
                    continue :_id self.src[self.index];
                },
                else => {
                    const str = self.src[self.token_start..self.index];
                    const tag = keywords.get(str) orelse .identifier;

                    return self.consumeToken(tag);
                },
            },
            .number => _number: switch (self.src[self.index]) {
                else => return self.consumeToken(.number),
                '0'...'9' => {
                    self.advance();
                    continue :_number self.src[self.index];
                },
                '.' => {
                    self.advance();
                    continue :state .number_after_dot;
                },
            },
            .number_after_dot => {
                const c = self.src[self.index];

                if (c < '0' or c > '9') return LexerError.InvalidNumber;

                frac: switch (c) {
                    '0'...'9' => {
                        self.advance();
                        continue :frac self.src[self.index];
                    },
                    else => break :frac,
                }

                return self.consumeToken(.number);
            },
            .string => _string: switch (self.src[self.index]) {
                0 => {
                    // TODO: Need error system
                    return LexerError.UnclosedString;
                },
                '"' => {
                    self.advance();
                    // Adjust token_start to skip opening quote, end already excludes closing quote
                    const token = self.consumeToken(.string_lit);
                    return Token{
                        .tag = token.tag,
                        .loc = .{ .start = token.loc.start + 1, .end = token.loc.end - 1 },
                        .src_loc = token.src_loc,
                    };
                },
                '\n' => {
                    self.newline();
                    self.advance();
                    continue :_string self.src[self.index];
                },
                else => {
                    self.advance();
                    continue :_string self.src[self.index];
                },
            },
            .color => _color: switch (self.src[self.index]) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    self.advance();
                    self.hex_color_count += 1;
                    continue :_color self.src[self.index];
                },
                else => {
                    if (self.hex_color_count != 6 and self.hex_color_count != 8)
                        return LexerError.InvalidColor;
                    // Adjust token_start to skip '#'
                    const token = self.consumeToken(.color_lit);
                    return Token{
                        .tag = token.tag,
                        .loc = .{ .start = token.loc.start + 1, .end = token.loc.end },
                        .src_loc = token.src_loc,
                    };
                },
            },
            .dedent_end => {
                if (self.indent_level == 0) continue :state .end;

                self.indent_level -= 2;

                return self.consumeToken(.dedent);
            },
            .end => {
                return self.consumeToken(.eof);
            },
        }

        return null;
    }

    inline fn advance(self: *Lexer) void {
        self.index += 1;
        self.src_loc.col += 1;
    }
    inline fn newline(self: *Lexer) void {
        self.src_loc.line += 1;
        self.src_loc.col = 1;
    }
    fn consumeToken(self: *Lexer, tag: Token.Tag) Token {
        const len = self.index - self.token_start;
        self.src_loc.len = len;
        const token: Token = .{
            .tag = tag,
            .loc = .{ .start = self.token_start, .end = self.index },
            .src_loc = self.src_loc,
        };
        self.token_start = self.index;

        return token;
    }
};
