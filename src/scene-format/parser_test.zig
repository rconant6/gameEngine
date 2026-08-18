// End-to-end front-end tests: source → lex → parse → inspect the flat AST.
// Exercises token.zig + lexer.zig + parser.zig + ast.zig together.

const std = @import("std");
const testing = std.testing;
const ast = @import("ast.zig");
const Ast = ast.Ast;
const Node = ast.Node;
const NodeTag = Node.Tag;
const RawValue = ast.RawValue;

// Parse and return the Ast; caller deinits. Uses the testing allocator so leaks fail.
fn parse(src: [:0]const u8) !Ast {
    return Ast.init(testing.allocator, src);
}

// The text a node's name_loc points at.
fn nameOf(a: Ast, src: [:0]const u8, idx: usize) []const u8 {
    return a.nodes[idx].name_loc.slice(src);
}
// The text a node's type_loc points at (the word after ':').
fn typeOf(a: Ast, src: [:0]const u8, idx: usize) []const u8 {
    return a.nodes[idx].type_loc.slice(src);
}

// ---------------------------------------------------------------------------

test "empty source: just the root node, no errors" {
    const src: [:0]const u8 = "";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 1), a.nodes.len); // root only
    try testing.expectEqual(NodeTag.root, a.nodes[0].tag);
    try testing.expectEqual(@as(usize, 0), a.errors.len);
}

test "a single typed node: Ball : circle { }" {
    const src: [:0]const u8 = "Ball : circle { }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // nodes: [0]=root, [1]=Ball
    try testing.expectEqual(@as(usize, 2), a.nodes.len);
    try testing.expectEqual(NodeTag.node, a.nodes[1].tag);
    try testing.expectEqual(@as(u32, 0), a.nodes[1].parent_idx); // child of root
    try testing.expectEqualStrings("Ball", nameOf(a, src, 1));
    try testing.expectEqualStrings("circle", typeOf(a, src, 1));
}

test "a node with one property: Ball : circle { radius 0.35 }" {
    const src: [:0]const u8 = "Ball : circle { radius 0.35 }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // [0]=root [1]=Ball [2]=radius(property)
    try testing.expectEqual(@as(usize, 3), a.nodes.len);

    const prop = a.nodes[2];
    try testing.expectEqual(NodeTag.property, prop.tag);
    try testing.expectEqual(@as(u32, 1), prop.parent_idx); // child of Ball
    try testing.expectEqualStrings("radius", prop.name_loc.slice(src));

    // its value is a number 0.35 in the side table
    const v = a.values[prop.value_idx];
    try testing.expect(v == .number);
    try testing.expectEqual(@as(f64, 0.35), v.number);
}

test "a flag (bare identifier): Ball : circle { collides }" {
    const src: [:0]const u8 = "Ball : circle { collides }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // [0]root [1]Ball [2]collides(flag)
    try testing.expectEqual(@as(usize, 3), a.nodes.len);
    try testing.expectEqual(NodeTag.flag, a.nodes[2].tag);
    try testing.expectEqualStrings("collides", a.nodes[2].name_loc.slice(src));
}

test "the milestone noun with mixed members" {
    const src: [:0]const u8 = "Ball : circle { radius 0.35 fill white velocity [7, 5] collides }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // [0]root [1]Ball [2]radius(prop) [3]fill(prop) [4]velocity(prop) [5]collides(flag)
    try testing.expectEqual(@as(usize, 6), a.nodes.len);

    try testing.expectEqual(NodeTag.property, a.nodes[2].tag); // radius
    try testing.expectEqual(NodeTag.property, a.nodes[3].tag); // fill
    try testing.expectEqual(NodeTag.property, a.nodes[4].tag); // velocity
    try testing.expectEqual(NodeTag.flag, a.nodes[5].tag); // collides

    // all four are children of Ball (idx 1)
    for (2..6) |i| try testing.expectEqual(@as(u32, 1), a.nodes[i].parent_idx);

    // fill's value is a bare ident "white" (unresolved — ingest types it later)
    const fill_v = a.values[a.nodes[3].value_idx];
    try testing.expect(fill_v == .ident);
    try testing.expectEqualStrings("white", fill_v.ident);

    // velocity is a 2-element vec [7, 5]
    const vel_v = a.values[a.nodes[4].value_idx];
    try testing.expect(vel_v == .vec);
    try testing.expectEqual(@as(usize, 2), vel_v.vec.len);
    try testing.expectEqual(@as(f64, 7), vel_v.vec[0]);
    try testing.expectEqual(@as(f64, 5), vel_v.vec[1]);
}

test "value kinds: number, string, color, bool, negative" {
    const src: [:0]const u8 = "N : x { a 1.5 b \"hi\" c #4488FF d true e -6.0 }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // properties are nodes 2..6
    const a_v = a.values[a.nodes[2].value_idx];
    try testing.expect(a_v == .number);
    try testing.expectEqual(@as(f64, 1.5), a_v.number);

    const b_v = a.values[a.nodes[3].value_idx];
    try testing.expect(b_v == .string);
    try testing.expectEqualStrings("hi", b_v.string); // quotes excluded

    const c_v = a.values[a.nodes[4].value_idx];
    try testing.expect(c_v == .color);
    try testing.expectEqual(@as(u32, 0x4488FF), c_v.color); // '#' excluded, hex parsed

    const d_v = a.values[a.nodes[5].value_idx];
    try testing.expect(d_v == .boolean);
    try testing.expectEqual(true, d_v.boolean);

    const e_v = a.values[a.nodes[6].value_idx];
    try testing.expect(e_v == .number);
    try testing.expectEqual(@as(f64, -6.0), e_v.number);
}

test "nested containment: Level : level { Ball : circle { } }" {
    const src: [:0]const u8 = "Level : level { Ball : circle { } }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    // [0]root [1]Level [2]Ball
    try testing.expectEqual(@as(usize, 3), a.nodes.len);
    try testing.expectEqual(@as(u32, 0), a.nodes[1].parent_idx); // Level under root
    try testing.expectEqual(@as(u32, 1), a.nodes[2].parent_idx); // Ball under Level
    try testing.expectEqualStrings("Level", nameOf(a, src, 1));
    try testing.expectEqualStrings("Ball", nameOf(a, src, 2));
}

test "two sibling nodes at top level" {
    const src: [:0]const u8 = "A : x { } B : y { }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), a.errors.len);
    try testing.expectEqual(@as(usize, 3), a.nodes.len); // root, A, B
    try testing.expectEqual(@as(u32, 0), a.nodes[1].parent_idx);
    try testing.expectEqual(@as(u32, 0), a.nodes[2].parent_idx);
    // sibling link: A.next_idx should point at B
    try testing.expectEqual(@as(u32, 2), a.nodes[1].next_idx);
}

// --- error / recovery (never-fails contract) --------------------------------

test "missing closing brace is recorded, not thrown" {
    const src: [:0]const u8 = "Ball : circle { radius 0.35";
    var a = try parse(src); // returns an Ast, does NOT error
    defer a.deinit(testing.allocator);

    try testing.expect(a.errors.len >= 1); // a missing_brace diagnostic
    // the good content still parsed
    try testing.expectEqualStrings("Ball", nameOf(a, src, 1));
}

test "recovery: a good node after a broken one still parses" {
    // first node missing its brace, second is fine
    const src: [:0]const u8 = "Bad : circle radius 0.35 Good : rectangle { }";
    var a = try parse(src);
    defer a.deinit(testing.allocator);

    try testing.expect(a.errors.len >= 1);
    // "Good" should appear somewhere in the node stream
    var found_good = false;
    for (a.nodes) |node| {
        if (node.tag == .node and std.mem.eql(u8, node.name_loc.slice(src), "Good")) {
            found_good = true;
        }
    }
    try testing.expect(found_good);
}
