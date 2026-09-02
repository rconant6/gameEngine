const std = @import("std");
const Loc = @import("token.zig").Loc;
const Literal = @import("schema.zig").Literal;

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
            value: Literal, // the schema placeholder — comptime-borrowed; consumer renders the text
        },
        wrong_ref: struct {
            name: []const u8,
            want: []const u8,
            got: []const u8,
        },
    };

    severity: Severity,
    loc: Loc,
    tag: Tag,
};
