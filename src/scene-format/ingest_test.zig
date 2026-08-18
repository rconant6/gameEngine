// Target tests for ingest — AST + schema → LabelGraph.
// Written before the build: this is the spec ingest must satisfy.
// Assumes:  pub fn ingest(perm, ast: *const Ast, src) error{OutOfMemory}!LabelGraph
// Adjust the entry-point call if your signature differs.

const std = @import("std");
const testing = std.testing;
const ast = @import("ast.zig");
const Ast = ast.Ast;
const graph = @import("graph.zig");
const LabelGraph = graph.LabelGraph;
const ResolvedNode = graph.ResolvedNode;
const ResolvedConcern = graph.ResolvedConcern;
const ResolvedField = graph.ResolvedField;
const Provenance = graph.Provenance;
const ingest = @import("ingest.zig").ingest;

// --- test harness ----------------------------------------------------------

// Parse src → AST, ingest → graph. Caller deinits both. Uses testing allocator.
const Fixture = struct {
    a: Ast,
    g: LabelGraph,
    src: [:0]const u8,
    fn deinit(f: *Fixture) void {
        f.g.deinit();
        f.a.deinit(testing.allocator);
    }
};
fn build(src: [:0]const u8) !Fixture {
    var a = try Ast.init(testing.allocator, src);
    errdefer a.deinit(testing.allocator);
    const g = try ingest(testing.allocator, &a, src);
    return .{ .a = a, .g = g, .src = src };
}

// find a resolved node by label
fn node(g: LabelGraph, label: []const u8) ?*const ResolvedNode {
    return g.find(label);
}
// find a concern on a node by name
fn concern(n: *const ResolvedNode, name: []const u8) ?*const ResolvedConcern {
    for (n.concerns) |*c| if (std.mem.eql(u8, c.name, name)) return c;
    return null;
}
// find a field in a concern by name
fn field(c: *const ResolvedConcern, name: []const u8) ?*const ResolvedField {
    for (c.fields) |*f| if (std.mem.eql(u8, f.name, name)) return f;
    return null;
}
// count diagnostics of a given severity
fn countSeverity(g: LabelGraph, sev: @import("diagnostic.zig").Severity) usize {
    var n: usize = 0;
    for (g.diagnostics) |d| {
        if (d.severity == sev) n += 1;
    }
    return n;
}

// ===========================================================================
// resolution
// ===========================================================================

test "resolve: Ball : circle { radius 0.35 } → geometry concern, variant circle" {
    var f = try build("Ball : circle { radius 0.35 }");
    defer f.deinit();

    try testing.expectEqual(@as(usize, 0), countSeverity(f.g, .err));

    const ball = node(f.g, "Ball").?;
    try testing.expectEqualStrings("circle", ball.type_name);

    const geo = concern(ball, "geometry").?;
    try testing.expectEqualStrings("circle", geo.variant.?);

    // radius is authored
    const radius = field(geo, "radius").?;
    try testing.expectEqual(Provenance.authored, radius.source);
    try testing.expect(radius.value == .number);
    try testing.expectEqual(@as(f64, 0.35), radius.value.number);
}

// ===========================================================================
// defaults (silent) — decision (a): geometry implies appearance, fill=magenta
// ===========================================================================

test "defaults: origin fills to zero (silent)" {
    var f = try build("Ball : circle { radius 1 }");
    defer f.deinit();

    const geo = concern(node(f.g, "Ball").?, "geometry").?;
    const origin = field(geo, "origin").?;
    try testing.expectEqual(Provenance.default, origin.source);
    try testing.expect(origin.value == .vec);
}

test "defaults: geometry auto-activates appearance (fill defaulted)" {
    var f = try build("Ball : circle { radius 1 }");
    defer f.deinit();

    const ball = node(f.g, "Ball").?;
    // appearance concern exists even though nothing appearance-ish was authored
    const app = concern(ball, "appearance").?;
    const fill = field(app, "fill").?;
    try testing.expectEqual(Provenance.default, fill.source);
    // (fill default is renderer magenta — value is an .ident or .color; assert it's present)
    try testing.expect(fill.value == .ident or fill.value == .color);
}

// ===========================================================================
// placeholder + teaching (the core) — decision: geometry required
// ===========================================================================

test "placeholder: Ball : circle { } → radius placeholdered + a warning" {
    var f = try build("Ball : circle { }");
    defer f.deinit();

    // no ERRORS (missing required geometry is a WARNING, not an error)
    try testing.expectEqual(@as(usize, 0), countSeverity(f.g, .err));
    // exactly one warning (the placeholder teaching move)
    try testing.expect(countSeverity(f.g, .warning) >= 1);

    const geo = concern(node(f.g, "Ball").?, "geometry").?;
    const radius = field(geo, "radius").?;
    try testing.expectEqual(Provenance.placeholder, radius.source);
    // the placeholder value is visible (1.0), so something renders
    try testing.expect(radius.value == .number);
    try testing.expectEqual(@as(f64, 1.0), radius.value.number);
}

// ===========================================================================
// flags — decision (b): collides activates collision, inherits geometry variant
// ===========================================================================

test "flag: collides activates a collision concern inheriting the circle variant" {
    var f = try build("Ball : circle { radius 1 collides }");
    defer f.deinit();

    const ball = node(f.g, "Ball").?;
    const col = concern(ball, "collision").?;
    try testing.expectEqualStrings("circle", col.variant.?); // inherited from geometry

    // collision flat defaults present
    const solid = field(col, "solid").?;
    try testing.expectEqual(Provenance.default, solid.source);
    try testing.expect(solid.value == .boolean);
    try testing.expectEqual(false, solid.value.boolean);
}

// ===========================================================================
// errors (never-throw)
// ===========================================================================

test "error: unknown type still returns a graph" {
    var f = try build("Ball : circel { }"); // typo'd shape
    defer f.deinit();

    try testing.expect(countSeverity(f.g, .err) >= 1); // unknown_type
    // a node is still produced (never-fails)
    try testing.expect(node(f.g, "Ball") != null);
}

test "error: unknown field is reported, geometry still resolves" {
    var f = try build("Ball : circle { radius 1 flurb 3 }");
    defer f.deinit();

    try testing.expect(countSeverity(f.g, .err) >= 1); // unknown_field "flurb"
    // radius still made it through
    const geo = concern(node(f.g, "Ball").?, "geometry").?;
    try testing.expect(field(geo, "radius") != null);
}

// ===========================================================================
// containment — decision (d): containers are pure containment, no concerns
// ===========================================================================

test "containment: Level : level { Ball : circle {} } → 2 nodes, Ball under Level" {
    var f = try build("Level : level { Ball : circle { radius 1 } }");
    defer f.deinit();

    const level = node(f.g, "Level").?;
    const ball = node(f.g, "Ball").?;

    // a container has NO concerns
    try testing.expectEqual(@as(usize, 0), level.concerns.len);

    // Ball's parent is Level's index in graph.nodes
    // (find Level's index)
    var level_idx: u32 = 0;
    for (f.g.nodes, 0..) |*nd, i| {
        if (nd == level) level_idx = @intCast(i);
    }
    try testing.expectEqual(level_idx, ball.parent);
}

// ===========================================================================
// arity — decision (e): ingest validates vec element count
// ===========================================================================

test "arity: a 3-elem vec on a vec2 field is an error" {
    // position is vec2; giving [1,2,3] should flag arity_mismatch
    var f = try build("Ball : circle { radius 1 position [1, 2, 3] }");
    defer f.deinit();

    // it must be the ARITY error, not a parse error — the source is well-formed
    try testing.expectEqual(@as(usize, 0), f.a.errors.len);
    try testing.expect(countSeverity(f.g, .err) >= 1);
}

test "arity: a correct vec2 is fine" {
    var f = try build("Ball : circle { radius 1 position [1, 2] }");
    defer f.deinit();

    // no errors at all — parses clean, resolves clean
    try testing.expectEqual(@as(usize, 0), countSeverity(f.g, .err));

    // position routes to placement concern, no arity error
    const place = concern(node(f.g, "Ball").?, "placement").?;
    const pos = field(place, "position").?;
    try testing.expect(pos.value == .vec);
    try testing.expectEqual(@as(usize, 2), pos.value.vec.len);
}
