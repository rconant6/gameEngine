//! Completion — the DSL's self-teaching surface. ENGINE-AWARE (imports scene_fmt).
//!
//! Hybrid context detection: a backward token scan of the current line finds the
//! IMMEDIATE half-typed edit context; the compiled Ast (nodeAtByte) supplies the
//! ENCLOSING node's structure. Phase 1 covers TYPE and MEMBER positions; VALUE is
//! phase 2 (the .value arm returns nothing for now).
//!
//! What each context offers (Phase 1):
//!   TYPE   (after ':')      → shape variant names + container names
//!   MEMBER (inside {})      → the node type's fields + flat concern fields + flag words
//!   VALUE  (after a field)  → [] for now (phase 2: bools, enum_values)

const std = @import("std");
const Allocator = std.mem.Allocator;

const sfmt = @import("scene_fmt");
const Ast = sfmt.Ast;
const schema = sfmt.schema;
const Schema = sfmt.Schema;
const Token = sfmt.Token;
const Lexer = sfmt.Lexer;
const FieldSpec = sfmt.FieldSpec;

const ts = @import("types.zig");
const CompletionItem = ts.CompletionItem;

pub const Context = union(enum) {
    type_pos, // after ':' — offer types
    member: struct { node_type: []const u8 }, // inside {} — offer fields/flags for this shape
    value: struct { field: []const u8 }, // after a known field — Phase 2
    none,
};

const Scan = struct { left: Token, left2_tag: Token.Tag };

fn lineStart(src: [:0]const u8, byte: u32) u32 {
    var i = byte;
    while (i > 0 and src[i - 1] != '\n') : (i -= 1) {}
    return i;
}

// Lex the current line up to the cursor; keep the last three tokens. A trailing
// identifier touching the cursor is the word being TYPED (the client filters by
// it), so `left` is the token before it.
fn scanBack(src: [:0]const u8, byte: u32) Scan {
    const eof_tok = Token{ .tag = .eof, .loc = .{ .start = byte, .end = byte } };
    var lx = Lexer.init(src);
    lx.idx = lineStart(src, byte);

    var a = eof_tok; // 3rd-last
    var b = eof_tok; // 2nd-last
    var c = eof_tok; // last
    var any = false;
    while (true) {
        const t = lx.next();
        if (t.tag == .eof or t.loc.start >= byte) break;
        a = b;
        b = c;
        c = t;
        any = true;
    }
    if (!any) return .{ .left = eof_tok, .left2_tag = .eof };

    if (c.tag == .identifier and c.loc.end >= byte) // word under the cursor
        return .{ .left = b, .left2_tag = a.tag };
    return .{ .left = c, .left2_tag = b.tag };
}

pub fn classify(src: [:0]const u8, byte: u32, ast: *const Ast) Context {
    const s = scanBack(src, byte);

    return switch (s.left.tag) {
        .colon => .type_pos,
        .l_brace => memberOf(src, byte, ast),
        .identifier => blk: {
            if (s.left2_tag == .colon) break :blk .type_pos; // Name : <type-word>
            const name = s.left.loc.slice(src);
            if (schema.ownerOfFieldSpec(name) != null)
                break :blk .{ .value = .{ .field = name } }; // known field awaiting its value
            break :blk memberOf(src, byte, ast); // flag / bare ident → member
        },
        // a value / closed list ended → ready for the next member
        .number, .string_lit, .color_lit, .true, .false, .r_bracket, .r_brace, .comma => memberOf(
            src,
            byte,
            ast,
        ),
        .eof => if (ast.nodeAtByte(byte) != null)
            memberOf(src, byte, ast)
        else
            .none,
        else => .none, // .minus, .l_bracket, .invalid → mid-value / garbage
    };
}

fn memberOf(src: [:0]const u8, byte: u32, ast: *const Ast) Context {
    var idx = ast.nodeAtByte(byte) orelse return .none;

    while (ast.nodes[idx].tag != .node) {
        if (idx == 0) return .none;
        idx = ast.nodes[idx].parent_idx;
    }

    const tl = ast.nodes[idx].type_loc;
    if (tl.end <= tl.start) return .none; // type not written yet

    const name = tl.slice(src);
    if (Schema.isContainerType(name)) return .none;

    return .{ .member = .{ .node_type = name } };
}

pub fn complete(
    arena: Allocator,
    src: [:0]const u8,
    byte: u32,
) error{OutOfMemory}![]CompletionItem {
    var ast = try Ast.init(arena, src);
    var items: std.ArrayList(CompletionItem) = .empty;

    switch (classify(src, byte, &ast)) {
        .type_pos => for (schema.typeNames()) |t| {
            try items.append(arena, .{
                .label = t.name,
                .kind = .struct_,
                .detail = if (t.kind == .container)
                    "container"
                else
                    "shape",
            });
        },
        .member => |m| {
            // per-shape fields (the only source that needs the compiled tree)
            if (schema.findVariant(m.node_type)) |v| {
                for (v.fields) |*f| try items.append(
                    arena,
                    try fieldItem(arena, f),
                );
            }
            // universal concern fields + flag words
            for (schema.concernFields()) |f| try items.append(
                arena,
                try fieldItem(arena, f),
            );
            for (schema.flagWords()) |fw| try items.append(arena, .{
                .label = fw.word,
                .kind = .keyword,
                .detail = try std.fmt.allocPrint(
                    arena,
                    "activates {s}",
                    .{fw.activates},
                ),
            });
        },
        .value, .none => {}, // Phase 2 / nothing to offer
    }

    return items.toOwnedSlice(arena);
}

fn fieldItem(
    arena: Allocator,
    f: *const FieldSpec,
) error{OutOfMemory}!CompletionItem {
    return .{
        .label = f.name,
        .kind = .field,
        .detail = try fieldDetail(arena, f),
    };
}

fn fieldDetail(
    arena: Allocator,
    f: *const FieldSpec,
) error{OutOfMemory}![]const u8 {
    const ty = @tagName(f.type);
    if (f.required) return std.fmt.allocPrint(
        arena,
        "{s}, required",
        .{ty},
    );
    if (f.default == .none) return std.fmt.allocPrint(
        arena,
        "{s}, optional",
        .{ty},
    );

    var buf: [64]u8 = undefined;
    const d = Schema.renderLiteral(f.default, &buf);

    return std.fmt.allocPrint(arena, "{s}, default {s}", .{ ty, d });
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
fn hasLabel(items: []const CompletionItem, label: []const u8) bool {
    for (items) |it| {
        if (std.mem.eql(u8, it.label, label)) return true;
    }
    return false;
}

fn completeSrc(arena: Allocator, src: [:0]const u8, byte: u32) ![]CompletionItem {
    return complete(arena, src, byte);
}

test "TYPE: after ':' offers shape variants and containers" {
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();

    // "Ball : c" — cursor at end (byte 8), type position
    const items = try completeSrc(arena, "Ball : c", 8);
    try testing.expect(hasLabel(items, "circle"));
    try testing.expect(hasLabel(items, "rectangle"));
    try testing.expect(hasLabel(items, "entity")); // a container type
}

test "MEMBER: inside a circle body offers circle's fields" {
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();

    // "Ball : circle { r" — cursor at byte 17, member position inside circle
    const items = try completeSrc(arena, "Ball : circle { r", 17);
    try testing.expect(hasLabel(items, "radius")); // circle's required field
    try testing.expect(hasLabel(items, "origin")); // circle's optional field
}

test "MEMBER: offers flat concern fields and flag words" {
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();

    const items = try completeSrc(arena, "Ball : circle { ", 16);
    try testing.expect(hasLabel(items, "fill")); // appearance concern flat field
    try testing.expect(hasLabel(items, "velocity")); // motion concern flat field
    try testing.expect(hasLabel(items, "collides")); // a flag word
}

test "MEMBER: a rectangle body offers rectangle's fields, not circle's" {
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();

    const items = try completeSrc(arena, "Wall : rectangle { ", 19);
    try testing.expect(hasLabel(items, "half_width"));
    try testing.expect(hasLabel(items, "half_height"));
    try testing.expect(!hasLabel(items, "radius")); // circle-only, must NOT appear
}

test "VALUE: phase 1 returns no items (deferred to phase 2)" {
    var a = std.heap.ArenaAllocator.init(testing.allocator);
    defer a.deinit();
    const arena = a.allocator();

    // "Ball : circle { visible " — cursor after a bool field name; phase 2 territory
    const items = try completeSrc(arena, "Ball : circle { visible ", 24);
    try testing.expectEqual(@as(usize, 0), items.len);
}
