const std = @import("std");
const Allocator = std.mem.Allocator;
const ast = @import("ast.zig");
const RawValue = ast.RawValue;
const diag = @import("diagnostic.zig");
const Diagnostic = diag.Diagnostic;
const tok = @import("token.zig");
const Loc = tok.Loc;

pub const Provenance = enum {
    authored, // kid wrote it - silent
    default, // filled from the default - silent
    placeholder, // required field missing - WARNS
};

pub const ResolvedField = struct {
    name: []const u8, // borrows from src(authored) or schema (default)
    value: RawValue, // instantiator will type it later
    source: Provenance,
    loc: Loc = .{}, // author span if authored or empty
};

pub const ResolvedConcern = struct {
    name: []const u8, // "geometry", "appearance", ....
    variant: ?[]const u8 = null, // shape name etc..for variant concerns
    fields: []ResolvedField,
};

pub const ResolvedNode = struct {
    label: []const u8, // node's name = adressing label
    type_name: []const u8, // word after the : selects type
    parent: u32, // index into the graph.nodes (0 = root/toplevel)
    concerns: []ResolvedConcern, // node's active concerns fully resolved
    loc: Loc = .{}, // node's name span
};

pub const LabelGraph = struct {
    nodes: []ResolvedNode,
    diagnostics: []Diagnostic, // ingest warning and errors, joined w/ parse errors
    perm: Allocator,

    pub fn deinit(g: *LabelGraph) void {
        for (g.nodes) |*node| {
            for (node.concerns) |*concern| {
                for (concern.fields) |*field| {
                    switch (field.value) {
                        .vec => |v| g.perm.free(v),
                        else => {},
                    }
                }
                g.perm.free(concern.fields);
            }
            g.perm.free(node.concerns);
        }
        g.perm.free(g.nodes);
        g.perm.free(g.diagnostics);
    }

    pub fn find(g: *const LabelGraph, label: []const u8) ?*const ResolvedNode {
        for (g.nodes) |*node| {
            if (std.mem.eql(u8, node.label, label)) return node;
        }
        return null;
    }
    pub fn hasErrors(g: *const LabelGraph) bool {
        for (g.diagnostics) |d| {
            if (d.severity == .err) return true;
        }

        return false;
    }
};

// ============================================================================
// Tests — the LabelGraph methods, exercised on hand-built graphs (no ingest).
// ============================================================================
const testing = std.testing;

// Build a minimal graph with the given node labels, all slices heap-allocated
// via `perm` so `deinit` is valid to call. No fields/concerns → nothing to free
// beyond the node/concern/diag slices themselves.
fn makeGraph(perm: Allocator, labels: []const []const u8, diags: []const Diagnostic) !LabelGraph {
    const nodes = try perm.alloc(ResolvedNode, labels.len);
    for (labels, 0..) |label, i| {
        nodes[i] = .{
            .label = label,
            .type_name = "circle",
            .parent = 0,
            .concerns = try perm.alloc(ResolvedConcern, 0), // empty, heap-owned
        };
    }
    const d = try perm.dupe(Diagnostic, diags);
    return .{ .nodes = nodes, .diagnostics = d, .perm = perm };
}

test "LabelGraph.find returns the matching node (stable pointer into nodes)" {
    var g = try makeGraph(testing.allocator, &.{ "Ball", "Paddle", "Wall" }, &.{});
    defer g.deinit();

    const p = g.find("Paddle").?;
    try testing.expectEqualStrings("Paddle", p.label);
    // it's a pointer INTO g.nodes, not a copy
    try testing.expectEqual(&g.nodes[1], p);
}

test "LabelGraph.find returns null for a missing label" {
    var g = try makeGraph(testing.allocator, &.{ "Ball", "Wall" }, &.{});
    defer g.deinit();

    try testing.expectEqual(@as(?*const ResolvedNode, null), g.find("Nope"));
}

test "LabelGraph.hasErrors is false with no diagnostics" {
    var g = try makeGraph(testing.allocator, &.{"Ball"}, &.{});
    defer g.deinit();
    try testing.expect(!g.hasErrors());
}

test "LabelGraph.hasErrors is false when only warnings are present" {
    const warn = Diagnostic{ .severity = .warning, .loc = .{}, .tag = .invalid_token };
    var g = try makeGraph(testing.allocator, &.{"Ball"}, &.{warn});
    defer g.deinit();
    try testing.expect(!g.hasErrors());
}

test "LabelGraph.hasErrors is true when an error is present" {
    const err = Diagnostic{ .severity = .err, .loc = .{}, .tag = .unexpected_token };
    const warn = Diagnostic{ .severity = .warning, .loc = .{}, .tag = .invalid_token };
    var g = try makeGraph(testing.allocator, &.{"Ball"}, &.{ warn, err });
    defer g.deinit();
    try testing.expect(g.hasErrors());
}

test "LabelGraph.deinit frees a .vec field payload (no leak)" {
    const perm = testing.allocator;
    // build one node with one concern with one .vec-valued field
    const vec = try perm.alloc(f64, 2);
    vec[0] = 7;
    vec[1] = 5;
    const fields = try perm.alloc(ResolvedField, 1);
    fields[0] = .{ .name = "velocity", .value = .{ .vec = vec }, .source = .authored };
    const concerns = try perm.alloc(ResolvedConcern, 1);
    concerns[0] = .{ .name = "motion", .fields = fields };
    const nodes = try perm.alloc(ResolvedNode, 1);
    nodes[0] = .{ .label = "Ball", .type_name = "circle", .parent = 0, .concerns = concerns };

    var g = LabelGraph{ .nodes = nodes, .diagnostics = try perm.alloc(Diagnostic, 0), .perm = perm };
    g.deinit(); // testing allocator will fail the test if the .vec payload leaks
}
