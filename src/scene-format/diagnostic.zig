const std = @import("std");
const Loc = @import("token.zig").Loc;

pub const Severity = enum { err, warning };

pub const Diagnostic = struct {
    pub const Tag = union(enum) {
        // parse
        unexpected_token,
        invalid_token,
        missing_brace,
        // ingest-time
        type_mismatch,
        unknown_type: []const u8,
        unknown_field: []const u8,
        unresolved_ref: []const u8,
        arity_mismatch: struct {
            expected: u8,
            got: usize,
        },
        default_placeholder: struct {
            field: []const u8,
            value_text: []const u8,
        },

        // pub fn format(t: @This(), w: *std.Io.Writer) !void {
        //     try w.print("{t}", .{t.format});
        // }
    };

    severity: Severity,
    loc: Loc,
    tag: Tag,

    // pub fn render(self: Diagnostic, src: [:0]const u8, w: *std.Io.Writer) !void {}
};
