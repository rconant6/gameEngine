const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const graph = @import("graph.zig");
const LabelGraph = graph.LabelGraph;
const ResolvedConcern = graph.ResolvedConcern;
const dg = @import("diagnostic.zig");
const Diagnostic = dg.Diagnostic;
const schem = @import("schema.zig");
const schema = schem.schema;
const Schema = schem.Schema;
const FieldSpec = schem.FieldSpec;
const st = @import("ast.zig");
const RawValue = st.RawValue;
const ingest = @import("ingest.zig").ingest;

pub fn resolveRefs(perm: Allocator, g: *LabelGraph) error{OutOfMemory}!void {
    var extra: ArrayList(Diagnostic) = .empty;
    defer extra.deinit(perm);

    for (g.nodes) |*node| {
        for (node.concerns) |*c| {
            for (c.fields) |*f| {
                const spec = specFor(c, f.name) orelse continue;
                if (spec.type != .label_ref) continue;

                const target_name = labelOf(f.value) orelse {
                    try extra.append(perm, .{
                        .severity = .err,
                        .loc = f.loc,
                        .tag = .type_mismatch,
                    });
                    continue;
                };

                if (g.find(target_name)) |tgt| {
                    const ref_kind = spec.ref_kind orelse continue;
                    if (!std.mem.eql(u8, tgt.type_name, ref_kind)) {
                        try extra.append(perm, .{
                            .severity = .err,
                            .loc = f.loc,
                            .tag = .{ .wrong_ref = .{
                                .name = target_name,
                                .want = ref_kind,
                                .got = tgt.type_name,
                            } },
                        });
                    }
                } else {
                    try extra.append(perm, .{
                        .severity = .err,
                        .loc = f.loc,
                        .tag = .{ .unresolved_ref = target_name },
                    });
                }
            }
        }
    }

    if (extra.items.len == 0) return;

    const merged = try perm.alloc(Diagnostic, g.diagnostics.len + extra.items.len);
    @memcpy(merged[0..g.diagnostics.len], g.diagnostics);
    @memcpy(merged[g.diagnostics.len..], extra.items);
    perm.free(g.diagnostics);
    g.diagnostics = merged;
}

pub fn ingestResolved(
    perm: Allocator,
    tree: *const st.Ast,
    src: [:0]const u8,
) error{OutOfMemory}!LabelGraph {
    var g = try ingest(perm, tree, src);
    errdefer g.deinit();
    try resolveRefs(perm, &g);
    return g;
}

fn specFor(c: *const ResolvedConcern, field: []const u8) ?*const FieldSpec {
    if (c.variant) |vn| {
        if (schema.findVariant(vn)) |v| {
            if (Schema.variantFieldSpec(v, field)) |s| return s;
        }
    }
    if (schema.findConcern(c.name)) |con| {
        for (con.fields) |*f| {
            if (std.mem.eql(u8, f.name, field)) return f;
        }
    }
    if (schema.findAsset(c.name)) |a| {
        return Schema.assetFieldSpec(a, field);
    }

    return null;
}

fn labelOf(v: RawValue) ?[]const u8 {
    return switch (v) {
        .ident => |i| i,
        .string => |s| s,
        else => null,
    };
}

// ============================================================================
// Tests — pass 2 over a real parsed+ingested graph.
// ============================================================================
const testing = std.testing;

const Fixture = struct {
    a: st.Ast,
    g: LabelGraph,
    fn deinit(f: *Fixture) void {
        f.g.deinit();
        f.a.deinit(testing.allocator);
    }
};

/// parse + ingest, but do NOT run pass 2 — tests call resolveRefs themselves so
/// they can assert on the before/after.
fn build(src: [:0]const u8) !Fixture {
    var a = try st.Ast.init(testing.allocator, src);
    errdefer a.deinit(testing.allocator);
    const g = try ingest(testing.allocator, &a, src);
    return .{ .a = a, .g = g };
}

fn countTag(g: LabelGraph, comptime want: std.meta.Tag(Diagnostic.Tag)) usize {
    var n: usize = 0;
    for (g.diagnostics) |d| {
        if (d.tag == want) n += 1;
    }
    return n;
}

test "resolveRefs: a ref to the right kind of asset is clean" {
    var f = try build(
        \\Roboto : font { path "a.ttf" }
        \\Score : text { string "hi" font Roboto }
    );
    defer f.deinit();

    const before = f.g.diagnostics.len;
    try resolveRefs(testing.allocator, &f.g);

    // a valid ref emits NOTHING — no new diagnostics at all
    try testing.expectEqual(before, f.g.diagnostics.len);
    try testing.expectEqual(@as(usize, 0), countTag(f.g, .unresolved_ref));
    try testing.expectEqual(@as(usize, 0), countTag(f.g, .wrong_ref));
}

test "resolveRefs: a ref to a nonexistent label is unresolved_ref" {
    var f = try build(
        \\Score : text { string "hi" font Nope }
    );
    defer f.deinit();

    try resolveRefs(testing.allocator, &f.g);

    try testing.expectEqual(@as(usize, 1), countTag(f.g, .unresolved_ref));
    for (f.g.diagnostics) |d| {
        if (d.tag == .unresolved_ref)
            try testing.expectEqualStrings("Nope", d.tag.unresolved_ref);
    }
}

test "resolveRefs: a ref to the WRONG kind names both sides" {
    var f = try build(
        \\Ball : circle { radius 1 }
        \\Score : text { string "hi" font Ball }
    );
    defer f.deinit();

    try resolveRefs(testing.allocator, &f.g);

    try testing.expectEqual(@as(usize, 1), countTag(f.g, .wrong_ref));
    try testing.expectEqual(@as(usize, 0), countTag(f.g, .unresolved_ref));
    for (f.g.diagnostics) |d| {
        if (d.tag == .wrong_ref) {
            try testing.expectEqualStrings("Ball", d.tag.wrong_ref.name);
            try testing.expectEqualStrings("font", d.tag.wrong_ref.want);
            try testing.expectEqualStrings("circle", d.tag.wrong_ref.got);
        }
    }
}

test "resolveRefs: a graph with no label_ref fields is untouched" {
    var f = try build("Ball : circle { radius 1 }");
    defer f.deinit();

    const before_ptr = f.g.diagnostics.ptr;
    const before_len = f.g.diagnostics.len;
    try resolveRefs(testing.allocator, &f.g);

    // no work => no realloc: the slice is pointer-identical
    try testing.expectEqual(before_ptr, f.g.diagnostics.ptr);
    try testing.expectEqual(before_len, f.g.diagnostics.len);
}

test "resolveRefs: pre-existing diagnostics survive the merge" {
    // `flurb` is an unknown field -> ingest emits an error before pass 2 runs
    var f = try build(
        \\Score : text { string "hi" flurb 3 font Nope }
    );
    defer f.deinit();

    const before = f.g.diagnostics.len;
    try testing.expect(before > 0); // ingest already complained

    try resolveRefs(testing.allocator, &f.g);

    // count grows by exactly the new findings; the old ones are still there
    try testing.expectEqual(before + 1, f.g.diagnostics.len);
    try testing.expectEqual(@as(usize, 1), countTag(f.g, .unknown_field));
    try testing.expectEqual(@as(usize, 1), countTag(f.g, .unresolved_ref));
}

test "resolveRefs: every bad ref is reported, not just the first" {
    // the merge-inside-the-loop bug passed a single-ref test and broke here
    var f = try build(
        \\A : text { string "a" font NopeOne }
        \\B : text { string "b" font NopeTwo }
        \\C : text { string "c" font NopeThree }
    );
    defer f.deinit();

    try resolveRefs(testing.allocator, &f.g);

    try testing.expectEqual(@as(usize, 3), countTag(f.g, .unresolved_ref));
}

test "resolveRefs: mesh.ref resolves against a mesh_data asset" {
    var f = try build(
        \\Tree : mesh_data { path "tree.obj" }
        \\Trunk : mesh { ref Tree }
    );
    defer f.deinit();

    const before = f.g.diagnostics.len;
    try resolveRefs(testing.allocator, &f.g);

    try testing.expectEqual(before, f.g.diagnostics.len);
}

test "ingestResolved runs both passes" {
    const a = testing.allocator;
    const src: [:0]const u8 =
        \\Score : text { string "hi" font Nope }
    ;
    var tree = try st.Ast.init(a, src);
    defer tree.deinit(a);

    var g = try ingestResolved(a, &tree, src);
    defer g.deinit();

    // pass 2 ran without the caller invoking it separately
    try testing.expectEqual(@as(usize, 1), countTag(g, .unresolved_ref));
}
