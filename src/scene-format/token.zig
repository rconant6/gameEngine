const std = @import("std");

pub const DataLocation = struct {
    start: u32,
    end: u32,

    pub fn format(self: DataLocation, w: *std.Io.Writer) !void {
        try w.print(" start: {d:4} end: {d:4}", .{ self.start, self.end });
    }
};
pub const SourceLocation = struct {
    line: u32,
    col: u32,
    len: u32,

    pub fn format(self: SourceLocation, w: *std.Io.Writer) !void {
        try w.print(
            "line: {d:3} col: {d:3}, len: {d:3}",
            .{ self.line, self.col, self.len },
        );
    }
};

pub const Token = struct {
    tag: Tag,
    loc: DataLocation,
    src_loc: SourceLocation,

    current_indent_level: u32 = 0,
    pending_dedents: u32 = 0,

    pub fn format(self: Token, w: *std.Io.Writer) !void {
        try w.print(
            "[TOKEN]\n  Tag: {}\n  SourceLoc {f}\n  DataLoc {f}",
            .{ self.tag, self.src_loc, self.loc },
        );
    }

    pub const Tag = enum {
        // Structure
        l_bracket,
        r_bracket,
        l_brace,
        r_brace,
        minus, // negative numbers
        dot, // floats
        comma,
        colon,
        whitespace,
        comment,
        indent,
        dedent,
        eof,

        // Keywords sections
        scene,
        entity,
        asset,
        shape,

        // Keywords types
        vec2,
        vec3,
        f32,
        i32,
        u32,
        bool,
        string,
        color,
        asset_ref,
        template,
        action,
        action_target,
        key,
        mouse,

        // Keywords asset-types
        font,

        // Literals
        number,
        string_lit,
        color_lit,
        true,
        false,

        // Identifiers
        identifier,

        invalid,
    };
};
