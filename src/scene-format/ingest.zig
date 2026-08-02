const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const BuilderMap = StringHashMapUnmanaged(ConcernBuilder);
const tok = @import("token.zig");
const Loc = tok.Loc;
const syn_tree = @import("ast.zig");
const Ast = syn_tree.Ast;
const RawValue = syn_tree.RawValue;
const graph = @import("graph.zig");
const LabelGraph = graph.LabelGraph;
const ResolvedConcern = graph.ResolvedConcern;
const ResolvedNode = graph.ResolvedNode;
const ResolvedField = graph.ResolvedField;
const dg = @import("diagnostic.zig");
const Diagnostic = dg.Diagnostic;
const Severity = dg.Severity;
const schema = @import("schema.zig");
const Variant = schema.Variant;
const Schema = schema.Schema;
const Literal = schema.Literal;

const Ctx = struct {
    perm: Allocator,
    ast: *const Ast,
    src: [:0]const u8,
    nodes: ArrayList(ResolvedNode) = .empty,
    diags: ArrayList(Diagnostic) = .empty,
    ast_to_graph: AutoHashMap(u32, u32) = .empty,

    pub fn diag(ctx: *Ctx, sev: Severity, tag: Diagnostic.Tag, loc: Loc) !void {
        try ctx.diags.append(ctx.perm, .{
            .severity = sev,
            .loc = loc,
            .tag = tag,
        });
    }
};

const ConcernBuilder = struct {
    name: []const u8,
    variant: ?[]const u8 = null,
    fields: ArrayList(ResolvedField) = .empty,

    pub fn has(b: *ConcernBuilder, field: []const u8) bool {
        for (b.fields) |*f| {
            if (std.mem.eql(u8, f.name, field)) return true;
        }
        return false;
    }
    pub fn set(b: *ConcernBuilder, perm: Allocator, f: ResolvedField) !void {
        try b.fields.append(perm, f);
    }
};

pub fn ingest(
    perm: Allocator,
    ast: *const Ast,
    src: [:0]const u8,
) error{OutOfMemory}!LabelGraph {
    var ctx = Ctx{ .perm = perm, .ast = ast, .src = src };
    defer ctx.ast_to_graph.deinit(ctx.perm);
    // moving the parser errors forward through the pipeline
    try ctx.diags.appendSlice(ctx.perm, ast.errors);

    var it = ast.iterator();
    while (it.next()) |event| {
        switch (event) {
            .enter => |e| {
                if (e.node.tag == .node) {
                    const graph_idx = ctx.nodes.items.len;
                    try ctx.ast_to_graph.put(ctx.perm, e.idx, @intCast(graph_idx));
                    const rn = try resolveNode(&ctx, e.idx);
                    try ctx.nodes.append(ctx.perm, rn);
                    it.skip();
                }
            },
            .exit, .done => {},
        }
    }

    return finalize(&ctx);
}

fn resolveNode(ctx: *Ctx, node_idx: u32) error{OutOfMemory}!ResolvedNode {
    const node = ctx.ast.nodes[node_idx];
    const label = node.name_loc.slice(ctx.src);
    const type_name = node.type_loc.slice(ctx.src);

    if (Schema.isContainerType(type_name)) {
        return ResolvedNode{
            .label = label,
            .type_name = type_name,
            .parent = parentResolvedIdx(ctx, node_idx),
            .concerns = &.{},
            .loc = node.name_loc,
        };
    }

    // resolve the type -> geometry or container kind
    const variant = schema.schema.findVariant(type_name) orelse
        try ctx.diag(.err, node.tag, node.loc);

    // builders keyed by concern Name
    var builders: StringHashMap(ConcernBuilder) = .init(ctx.perm);
    defer builders.deinit();

    // MARK: HERE!
    if (variant != null) {
        const gb = try builders.getOrPut("geometry");
        gb.value_ptr.variant = type_name;
    }
}

fn finalize(ctx: *Ctx) !LabelGraph {
    return .{
        .nodes = ctx.nodes.toOwnedSlice(ctx.perm),
        .diagnostics = ctx.diags.toOwnedSlice(ctx.perm),
        .perm = ctx.perm,
    };
}

// MARK: Helpers
fn parentResolvedIdx(ctx: *const Ctx, node_idx: u32) u32 {
    var curr_idx = node_idx;
    while (curr_idx != 0) {
        const parent_idx = ctx.ast.nodes[node_idx].parent_idx;
        if (ctx.ast_to_graph.contains(parent_idx)) return parent_idx;

        curr_idx = parent_idx;
    }

    return 0;
}

// per active builder, alloc a ResolvedConcern and MOVE its fields out via
// b.fields.toOwnedSlice(perm) — transfers backing memory, leaves the list empty
// so the map's deferred deinit frees nothing live. Result is graph-owned.
fn buildersToSlice(
    perm: Allocator,
    builders: *BuilderMap,
) error{OutOfMemory}![]ResolvedConcern {
    const res_concerns = try perm.alloc(ResolvedConcern, builders.size);

    var it = builders.iterator();
    var idx: usize = 0;
    while (it.next()) |entry| : (idx += 1) {
        const b = entry.value_ptr;
        const concern = entry.key_ptr.*;
        // TODO: CHECK THIS IF IT IS NEEDED OR NOT when making builder
        defer perm.free(concern);

        res_concerns[idx] = .{
            .name = try perm.dupe(u8, concern),
            .variant = b.variant,
            .fields = b.fields.toOwnedSlice(),
        };
    }

    return res_concerns;
}

fn literalToRaw(perm: Allocator, lit: Literal) !RawValue {
    switch (lit) {
        .f32 => |f| return .{ .number = f },
        .boolean => |b| return .{ .boolean = b },
        .color => |c| return .{ .color = c },
        .ident => |i| return .{ .ident = i },
        .string => |s| return .{ .string = s },
        // TODO: might need ctx to dupe?
        .vec2 => |v2| {
            const dupes = try perm.alloc(f64, 2);
            dupes[0] = v2[0];
            dupes[1] = v2[1];
            return .{ .vec = dupes };
        },
        .vec3 => |v3| {
            const dupes = try perm.alloc(f64, 3);
            dupes[0] = v3[0];
            dupes[1] = v3[1];
            dupes[2] = v3[2];
            return .{ .vec = dupes };
        },
        .none => unreachable,
    }
}

fn childrenOf(node_idx: u32) bool {
    _ = node_idx;
    return false;
}
