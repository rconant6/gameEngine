const std = @import("std");
const Loc = @import("token.zig").Loc;

pub const Severity = enum { err, warning };

pub const Diagnostic = struct {
    severity: Severity,
    loc: Loc,
    tag: union(enum) {
        // parse
        unexpected_token,
        invalid_token,
        missing_brace,
        // ingest-time
        unknown_type: []const u8,
        unknown_field: []const u8,
        unresolved_ref: []const u8,
        default_placeholder: struct {
            field: []const u8,
            value_text: []const u8,
        },

        // pub fn format(t: @This(), w: *std.Io.Writer) !void {
        //     try w.print("{t}", .{t.format});
        // }
    },

    // pub fn render(self: Diagnostic, src: [:0]const u8, w: *std.Io.Writer) !void {}
};
