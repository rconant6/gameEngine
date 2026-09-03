const std = @import("std");
const Allocator = std.mem.Allocator;
const ts = @import("types.zig");
const Range = ts.Range;
const LineIndex = @import("LineIndex.zig");
const sfmt = ts.sfmt;
const Ast = sfmt.Ast;
const ingest = sfmt.ingest;
const SceneDiagnostic = sfmt.Diagnostic;
const Severity = sfmt.Severity;

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    source: []const u8 = "scene",
    message: []const u8,
};

pub const DiagnosticSeverity = enum(u8) {
    err = 1,
    warn = 2,
    info = 3,
    hint = 4,

    // LSP wants the numeric code (1..4), not the enum name — serialize the tag.
    pub fn jsonStringify(self: DiagnosticSeverity, jw: anytype) !void {
        try jw.write(@intFromEnum(self));
    }
};

pub fn collect(
    arena: Allocator,
    src: [:0]const u8,
    lines: LineIndex,
) error{OutOfMemory}![]Diagnostic {
    var ast = try Ast.init(arena, src);
    const g = try ingest(arena, &ast, src);

    var out: std.ArrayList(Diagnostic) = .empty;
    for (g.diagnostics) |d| {
        try out.append(arena, .{
            .range = lines.rangeOf(d.loc),
            .severity = severityOf(d.severity),
            .message = try messageOf(arena, d.tag),
        });
    }

    return out.toOwnedSlice(arena);
}

pub fn messageOf(
    arena: Allocator,
    tag: SceneDiagnostic.Tag,
) error{OutOfMemory}![]const u8 {
    return switch (tag) {
        .unexpected_token => "unexpected token",
        .invalid_token => "invalid token - bad scene/template syntax",
        .missing_brace => "missing '}' before end of input",
        .type_mismatch => "type mismatch",
        .unknown_type => |t| std.fmt.allocPrint(
            arena,
            "unknown type '{s}'",
            .{t},
        ),
        .unknown_field => |f| std.fmt.allocPrint(
            arena,
            "unknown field '{s}'",
            .{f},
        ),
        .unresolved_ref => |r| std.fmt.allocPrint(
            arena,
            "unresolved reference '{s}'",
            .{r},
        ),
        .arity_mismatch => |a| std.fmt.allocPrint(
            arena,
            "expected {d} components, got {d}",
            .{ a.expected, a.got },
        ),
        .default_placeholder => |d| blk: {
            // render the Literal here (presentation layer); allocPrint copies the
            // rendered text into arena, so the stack buf may safely dangle after.
            var buf: [64]u8 = undefined;
            const val = sfmt.Schema.renderLiteral(d.value, &buf);
            break :blk std.fmt.allocPrint(
                arena,
                "'{s}' not set - using placeholder {s}",
                .{ d.field, val },
            );
        },
        .wrong_ref => |w| std.fmt.allocPrint(
            arena,
            "'{s}' should be a {s}, got {s}",
            .{ w.name, w.want, w.got },
        ),
    };
}

pub fn severityOf(sev: Severity) DiagnosticSeverity {
    return switch (sev) {
        .err => .err,
        .warning => .warn,
    };
}

// ============================================================================
// Tests
// ============================================================================
const testing = std.testing;

// Compile a snippet through collect() with a scratch arena; caller drives asserts.
fn collectSnippet(arena: Allocator, src: [:0]const u8) ![]Diagnostic {
    const lines = try LineIndex.build(arena, src);
    // LineIndex.deinit is a no-op against an arena; skip it — arena frees all.
    return collect(arena, src, lines);
}

// Does any diagnostic's message contain `needle`?
fn anyMessageContains(diags: []const Diagnostic, needle: []const u8) bool {
    for (diags) |d| {
        if (std.mem.indexOf(u8, d.message, needle) != null) return true;
    }
    return false;
}

test "collect: clean source yields no diagnostics" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const diags = try collectSnippet(arena, "Ball : circle { radius 1 }");
    try testing.expectEqual(@as(usize, 0), diags.len);
}

test "collect: unknown type is reported as an error" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const diags = try collectSnippet(arena, "Ball : circel { }"); // typo'd shape
    try testing.expect(diags.len >= 1);
    try testing.expect(anyMessageContains(diags, "circel"));
    // at least one is an error-severity diagnostic
    var saw_err = false;
    for (diags) |d| if (d.severity == .err) {
        saw_err = true;
    };
    try testing.expect(saw_err);
}

test "collect: unknown field is reported and names the field" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const diags = try collectSnippet(arena, "Ball : circle { radius 1 flurb 3 }");
    try testing.expect(anyMessageContains(diags, "flurb"));
}

test "collect: arity mismatch on a vec2 field is an error" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // position is vec2; [1,2,3] is 3 elements → arity error. Source is well-formed.
    const diags = try collectSnippet(arena, "Ball : circle { radius 1 position [1, 2, 3] }");
    var saw_err = false;
    for (diags) |d| if (d.severity == .err) {
        saw_err = true;
    };
    try testing.expect(saw_err);
}

test "collect: missing required field warns with a placeholder" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // circle.radius is required; omitting it → default_placeholder WARNING.
    const diags = try collectSnippet(arena, "Ball : circle { }");
    var saw_warn = false;
    for (diags) |d| if (d.severity == .warn) {
        saw_warn = true;
    };
    try testing.expect(saw_warn);
    try testing.expect(anyMessageContains(diags, "radius"));
}

test "collect: diagnostic carries a real range, not a zero span" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // "flurb" starts well into the line, so its range must be past character 0.
    const diags = try collectSnippet(arena, "Ball : circle { radius 1 flurb 3 }");
    var found = false;
    for (diags) |d| {
        if (std.mem.indexOf(u8, d.message, "flurb") != null) {
            found = true;
            try testing.expectEqual(@as(u32, 0), d.range.start.line);
            try testing.expect(d.range.start.character > 0);
        }
    }
    try testing.expect(found);
}
