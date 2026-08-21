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
const schem = @import("schema.zig");
const Variant = schem.Variant;
const Schema = schem.Schema;
const schema = schem.schema;
const Literal = schem.Literal;
const FieldType = schem.FieldType;
const Asset = schem.Asset;

const Ctx = struct {
    perm: Allocator,
    ast: *const Ast,
    src: [:0]const u8,
    nodes: ArrayList(ResolvedNode) = .empty,
    diags: ArrayList(Diagnostic) = .empty,
    ast_to_graph: AutoHashMap(u32, u32),

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
    node_loc: Loc = .{},

    pub fn has(b: *ConcernBuilder, field: []const u8) bool {
        for (b.fields.items) |*f| {
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
    var ctx = Ctx{
        .perm = perm,
        .ast = ast,
        .src = src,
        .ast_to_graph = .init(perm),
    };
    defer ctx.ast_to_graph.deinit();

    try ctx.diags.appendSlice(ctx.perm, ast.errors);

    var it = ast.iterator();
    while (it.next()) |event| {
        switch (event) {
            .enter => |e| {
                if (e.node.tag == .node) {
                    const graph_idx = ctx.nodes.items.len;
                    try ctx.ast_to_graph.put(e.idx, @intCast(graph_idx));
                    const rn = try resolveNode(&ctx, e.idx);
                    try ctx.nodes.append(ctx.perm, rn);
                }
            },
            .exit => {},
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

    if (schema.findAsset(type_name)) |asset| {
        var builders: BuilderMap = .empty;
        defer builders.deinit(ctx.perm);

        const b = try activateConcern(ctx, &builders, asset.name, node.name_loc);
        var members = ctx.ast.childrenOf(node_idx);
        while (members.next()) |member_idx| {
            if (ctx.ast.nodes[member_idx].tag == .property) {
                try resolveAssetField(ctx, b, asset, member_idx);
            } else {
                try ctx.diag(
                    .err,
                    .{ .unknown_field = "unknown property of asset" },
                    node.name_loc,
                );
            }
        }
    }

    // resolve the type -> geometry or container kind
    const variant = schema.findVariant(type_name) orelse blk: {
        try ctx.diag(.err, .{ .unknown_type = type_name }, node.loc);
        break :blk null;
    };

    // builders keyed by concern Name
    var builders: BuilderMap = .empty;
    defer builders.deinit(ctx.perm);

    if (variant != null) {
        var gb = try activateConcern(ctx, &builders, "geometry", node.name_loc);
        gb.variant = type_name;
        _ = try activateConcern(ctx, &builders, "appearance", node.name_loc);
    }

    // walk this node's direct members (childrenOf yields INDICES)
    var members = ctx.ast.childrenOf(node_idx);
    while (members.next()) |member_idx| {
        const member = ctx.ast.nodes[member_idx];
        switch (member.tag) {
            .property => try resolveProperty(ctx, &builders, variant, member_idx),
            .flag => try resolveFlag(ctx, &builders, member_idx, type_name),
            .node => {
                const mem_name = member.name_loc.slice(ctx.src);
                if (Schema.flagConcern(mem_name)) |cn| {
                    var b = try activateConcern(ctx, &builders, cn, node.name_loc);
                    b.variant = member.type_loc.slice(ctx.src);

                    var subs = ctx.ast.childrenOf(member_idx);
                    while (subs.next()) |sub_idx| {
                        try resolveProperty(
                            ctx,
                            &builders,
                            schema.findVariant(b.variant.?),
                            sub_idx,
                        );
                    }
                }
            },
            else => {},
        }
    }

    // fill in the gaps. Value pointers to fill the builders in place
    var val_it = builders.valueIterator();
    while (val_it.next()) |b| {
        try fillPlaceholders(ctx, b);
        try fillDefaults(ctx, b);
    }

    return .{
        .label = label,
        .type_name = type_name,
        .loc = node.name_loc,
        .parent = parentResolvedIdx(ctx, node_idx),
        .concerns = try buildersToSlice(ctx.perm, &builders),
    };
}

fn finalize(ctx: *Ctx) !LabelGraph {
    return .{
        .nodes = try ctx.nodes.toOwnedSlice(ctx.perm),
        .diagnostics = try ctx.diags.toOwnedSlice(ctx.perm),
        .perm = ctx.perm,
    };
}

// MARK: Helpers
fn activateConcern(
    ctx: *Ctx,
    builders: *BuilderMap,
    name: []const u8,
    node_loc: Loc,
) error{OutOfMemory}!*ConcernBuilder {
    const gp_res = try builders.getOrPut(ctx.perm, name);

    if (!gp_res.found_existing)
        gp_res.value_ptr.* = .{ .name = name, .node_loc = node_loc };

    return gp_res.value_ptr;
}

fn parentResolvedIdx(ctx: *const Ctx, node_idx: u32) u32 {
    var curr_idx = ctx.ast.nodes[node_idx].parent_idx;
    while (curr_idx != 0) : (curr_idx = ctx.ast.nodes[curr_idx].parent_idx) {
        if (ctx.ast_to_graph.get(curr_idx)) |graph_idx| return graph_idx;
    }
    return 0;
}

fn buildersToSlice(
    perm: Allocator,
    builders: *BuilderMap,
) error{OutOfMemory}![]ResolvedConcern {
    const res_concerns = try perm.alloc(ResolvedConcern, builders.size);

    var it = builders.iterator();
    var idx: usize = 0;
    while (it.next()) |entry| : (idx += 1) {
        const b = entry.value_ptr;
        res_concerns[idx] = .{
            .name = b.name,
            .variant = b.variant,
            .fields = try b.fields.toOwnedSlice(perm),
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

/// Take ownership of an AUTHORED value before it enters the graph.
/// An authored `.vec` borrows the Ast's heap slice, and the Ast frees its own
/// values in deinit — so storing it directly would double-free. Everything else
/// (numbers, bools, colors) is by-value, and strings/idents borrow from `src`,
/// which outlives the graph. Result: every `.vec` in the graph is graph-owned,
/// matching LabelGraph.deinit's unconditional free.
fn ownValue(perm: Allocator, raw: RawValue) error{OutOfMemory}!RawValue {
    return switch (raw) {
        .vec => |v| .{ .vec = try perm.dupe(f64, v) },
        else => raw,
    };
}

fn resolveProperty(
    ctx: *Ctx,
    builders: *BuilderMap,
    variant: ?*const Variant,
    member_idx: u32,
) error{OutOfMemory}!void {
    const member = ctx.ast.nodes[member_idx];
    const field_name = member.name_loc.slice(ctx.src);
    const raw = ctx.ast.values[member.value_idx];

    // 1) a field of the chosen variant?
    if (variant) |v| {
        if (Schema.variantFieldSpec(v, field_name)) |spec| {
            try checkArity(ctx, spec.type, raw, member.name_loc);
            var b = try activateConcern(ctx, builders, "geometry", member.name_loc);
            try b.set(ctx.perm, .{
                .name = field_name,
                .value = try ownValue(ctx.perm, raw),
                .source = .authored,
                .loc = member.name_loc,
            });
            return;
        }
        // a miss falls through to the flat-field check below
    }

    // 2) a flat field a concern owns?
    if (schema.ownerOfFieldSpec(field_name)) |owned| {
        try checkArity(ctx, owned.spec.type, raw, member.name_loc);
        var b = try activateConcern(ctx, builders, owned.concern.name, member.name_loc);
        try b.set(ctx.perm, .{
            .name = field_name,
            .value = try ownValue(ctx.perm, raw),
            .source = .authored,
            .loc = member.name_loc,
        });
        return;
    }

    try ctx.diag(.err, .{ .unknown_field = field_name }, member.name_loc);
}

fn resolveAssetField(
    ctx: *Ctx,
    b: *ConcernBuilder,
    asset: *const Asset,
    member_idx: u32,
) error{OutOfMemory}!void {
    const member = ctx.ast.nodes[member_idx];
    const field_name = member.name_loc.slice(ctx.src);
    const raw = ctx.ast.values[member.value_idx];

    if (Schema.assetFieldSpec(asset, field_name)) |spec| {
        try checkArity(ctx, spec.type, raw, member.name_loc);
        try b.set(ctx.perm, .{
            .name = field_name,
            .value = try ownValue(ctx.perm, raw),
            .source = .authored,
            .loc = member.name_loc,
        });
        return;
    }

    try ctx.diag(.err, .{ .unknown_field = field_name }, member.name_loc);
}

fn resolveFlag(
    ctx: *Ctx,
    builders: *StringHashMapUnmanaged(ConcernBuilder),
    member_idx: u32,
    geo_type: []const u8,
) error{OutOfMemory}!void {
    const member = ctx.ast.nodes[member_idx];
    const field_name = member.name_loc.slice(ctx.src);

    if (Schema.flagConcern(field_name)) |cn| {
        const b = try activateConcern(ctx, builders, cn, member.name_loc);
        // (b) a variant concern inherits the geometry variant unless it already
        // has its own (set by an explicit `collides : rectangle` member-node).
        if (schema.findConcern(cn)) |c| {
            if (c.accepts != null and b.variant == null) b.variant = geo_type;
        }
    } else {
        // not a flag word at all
        try ctx.diag(
            .err,
            .{ .unknown_field = field_name },
            member.name_loc,
        );
    }
}

fn checkArity(
    ctx: *Ctx,
    field_type: FieldType,
    raw: RawValue,
    loc: Loc,
) error{OutOfMemory}!void {
    const expected: u8 = switch (field_type) {
        .vec2 => 2,
        .vec3 => 3,
        else => return,
    };

    if (raw != .vec) {
        try ctx.diag(.err, .type_mismatch, loc);
        return;
    }

    if (raw.vec.len != expected) {
        try ctx.diag(
            .err,
            .{ .arity_mismatch = .{
                .expected = expected,
                .got = raw.vec.len,
            } },
            loc,
        );
    }
}

fn fillPlaceholders(ctx: *Ctx, b: *ConcernBuilder) error{OutOfMemory}!void {
    if (b.variant == null) return;

    const v = schema.findVariant(b.variant.?).?;
    for (v.fields) |spec| {
        if (spec.required and !b.has(spec.name)) {
            const ph = spec.placeholder;
            try b.set(
                ctx.perm,
                .{
                    .name = spec.name,
                    .source = .placeholder,
                    .value = try literalToRaw(ctx.perm, ph),
                },
            );

            var buf: [64]u8 = undefined;
            try ctx.diag(
                .warning,
                .{
                    .default_placeholder = .{
                        .field = spec.name,
                        .value_text = Schema.renderLiteral(ph, &buf),
                    },
                },
                b.node_loc,
            );
        }
    }
}

fn fillDefaults(ctx: *Ctx, b: *ConcernBuilder) error{OutOfMemory}!void {
    if (b.variant != null) {
        const v = schema.findVariant(b.variant.?).?;
        for (v.fields) |spec| {
            if (!spec.required and !b.has(spec.name) and spec.default != .none) {
                try b.set(
                    ctx.perm,
                    .{
                        .name = spec.name,
                        .source = .default,
                        .value = try literalToRaw(ctx.perm, spec.default),
                    },
                );
            }
        }
    }

    const c = schema.findConcern(b.name).?;
    for (c.fields) |spec| {
        if (!b.has(spec.name) and spec.default != .none) {
            try b.set(
                ctx.perm,
                .{
                    .name = spec.name,
                    .source = .default,
                    .value = try literalToRaw(ctx.perm, spec.default),
                },
            );
        }
    }
}

fn fillAssetGaps(ctx: *Ctx, b: *ConcernBuilder, asset: *const Asset) error{OutOfMemory}!void {
    for (asset.fields) |spec| {
        if (b.has(spec.name)) continue;
        if (spec.required) {
            try b.set(
                ctx.perm,
                .{
                    .name = spec.name,
                    .source = .placeholder,
                    .value = try literalToRaw(ctx.perm, spec.placeholder),
                },
            );
            var buf: [64]u8 = undefined;
            ctx.diag(
                .warning,
                .{
                    .default_placeholder = .{
                        .field = spec.name,
                        .value_text = Schema.renderLiteral(spec.placeholder, &buf),
                    },
                },
                b.node_loc,
            );
        } else if (spec.default != .none) {
            try b.set(
                ctx.perm,
                .{
                    .name = spec.name,
                    .source = .default,
                    .value = try literalToRaw(ctx.perm, spec.default),
                },
            );
        }
    }
}
