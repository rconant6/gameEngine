const std = @import("std");
const assert = std.debug.assert;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const Token = tok.Token;
const Loc = tok.Loc;
const diag = @import("diagnostic.zig");
const Diagnostic = diag.Diagnostic;
const parse = @import("parser.zig");
const Parser = parse.Parser;

pub const Ast = struct {
    nodes: []const Node,
    values: []const RawValue,
    errors: []const Diagnostic,

    pub fn init(perm: Allocator, src: [:0]const u8) error{OutOfMemory}!Ast {
        var parser: Parser = .{
            .perm = perm,
            .src = src,
        };
        defer parser.meta.deinit(perm);

        return parser.parse();
    }
    pub fn deinit(self: *Ast, perm: Allocator) void {
        for (self.values) |v| {
            switch (v) {
                .vec => |floats| perm.free(floats),
                else => {},
            }
        }
        perm.free(self.values);

        perm.free(self.nodes);
        perm.free(self.errors);
    }
    pub fn iterator(ast: *const Ast) Iterator {
        return .{
            .nodes = ast.nodes,
        };
    }

    pub fn childrenOf(ast: *const Ast, parent_idx: u32) ChildIterator {
        const first = parent_idx + 1;

        const curr = if (first < ast.nodes.len and
            ast.nodes[first].parent_idx == parent_idx)
            first
        else
            0;

        return ChildIterator{
            .nodes = ast.nodes,
            .parent = parent_idx,
            .curr = curr,
        };
    }

    pub fn nodeAtByte(ast: *const Ast, byte: u32) ?u32 {
        for (ast.nodes[1..], 1..) |node, i| {
            const extent = if (node.body_end != 0)
                node.body_end
            else
                node.name_loc.end;

            if (byte <= extent and
                byte >= node.name_loc.start) return @intCast(i);
        }

        return null;
    }
};

pub const Node = struct {
    tag: Tag,
    loc: Loc,
    parent_idx: u32,
    next_idx: u32 = 0,
    name_loc: Loc = .{},
    type_loc: Loc = .{},
    value_idx: u32 = 0,
    body_end: u32 = 0,

    pub const Tag = enum(u8) { root, node, property, flag, missing };
};

pub const RawValue = union(enum) {
    number: f64,
    string: []const u8,
    color: u32,
    boolean: bool,
    vec: []f64,
    ident: []const u8,
};

pub const ChildIterator = struct {
    nodes: []const Node,
    parent: u32,
    curr: u32,

    pub fn next(it: *ChildIterator) ?u32 {
        if (it.curr == 0) return null;
        const result = it.curr;
        it.curr = it.nodes[result].next_idx;
        return result;
    }
};

pub const Iterator = struct {
    nodes: []const Node,
    last_entered: u32 = 0,
    state: State = .{ .enter = .{ .idx = 0, .next = 1 } },

    // Exhaustion is signalled by next() returning null, not by an event.
    pub const Event = union(enum) {
        enter: struct { idx: u32, node: *const Node },
        exit: struct { idx: u32, node: *const Node },
    };

    const State = union(enum) {
        enter: struct { // About to 'enter' a node (idx), the pre-order successor is next
            idx: u32,
            next: u32,
        },
        exit: struct { // About to leave (idx), target when I go back enough
            idx: u32,
            target: u32,
        },
        done: void,
    };

    pub fn next(it: *Iterator) ?Event {
        return switch (it.state) {
            .enter => |e| {
                it.last_entered = e.idx;

                const node = &it.nodes[e.idx];
                if (e.next == it.nodes.len) {
                    it.state = .{ .exit = .{
                        .idx = e.idx,
                        .target = @intCast(it.nodes.len),
                    } };
                    return .{ .enter = .{ .idx = e.idx, .node = node } };
                }

                const next_node = &it.nodes[e.next];
                if (next_node.parent_idx == e.idx) {
                    it.state = .{ .enter = .{
                        .idx = e.next,
                        .next = e.next + 1,
                    } };
                    return .{ .enter = .{ .idx = e.idx, .node = node } };
                }

                it.state = .{ .exit = .{
                    .idx = e.idx,
                    .target = e.next,
                } };
                return .{ .enter = .{ .idx = e.idx, .node = node } };
            },
            .exit => |x| {
                const node = &it.nodes[x.idx];
                if (x.target == it.nodes.len) {
                    if (x.idx == 0) it.state = .done else it.state = .{ .exit = .{
                        .idx = node.parent_idx,
                        .target = x.target,
                    } };
                    return .{ .exit = .{ .idx = x.idx, .node = node } };
                }
                const idx_parent = node.parent_idx;
                const target_parent = it.nodes[x.target].parent_idx;
                if (idx_parent == target_parent) {
                    it.state = .{ .enter = .{
                        .idx = x.target,
                        .next = x.target + 1,
                    } };
                    return .{ .exit = .{ .idx = x.idx, .node = node } };
                } else {
                    if (x.idx == 0) it.state =
                        .done else it.state = .{
                        .exit = .{
                            .idx = node.parent_idx,
                            .target = x.target,
                        },
                    };
                    return .{ .exit = .{ .idx = x.idx, .node = node } };
                }
            },
            .done => {
                return null;
            },
        };
    }
    pub fn skip(it: *Iterator) void {
        const e = switch (it.state) {
            .enter => |e| e,
            else => return,
        };

        var t: u32 = e.idx + 1;
        while (t < it.nodes.len) {
            var cur = t;
            var under = false;
            while (cur != 0) {
                cur = it.nodes[cur].parent_idx;
                if (cur == it.last_entered) {
                    under = true;
                    break;
                }
            }
            if (!under) break; // first node NOT under e.idx → subtree ends here
            t += 1;
        }
        it.state = .{ .exit = .{ .idx = it.last_entered, .target = t } };
    }
};

// MARK: TESTS
const testing = std.testing;

// A step in the expected event stream (a tag + which node index it refers to).
const Step = struct {
    kind: enum { enter, exit },
    idx: u32 = 0,
};

// Drive the iterator to completion and check it matches `expected`.
fn expectWalk(nodes: []const Node, expected: []const Step) !void {
    var it = Iterator{ .nodes = nodes };
    for (expected, 0..) |step, i| {
        errdefer std.debug.print("mismatch at step {d}\n", .{i});
        const ev = it.next();
        switch (step.kind) {
            .enter => {
                try testing.expect(ev.? == .enter);
                // identity check: the event points at nodes[idx]
                try testing.expectEqual(&nodes[step.idx], ev.?.enter.node);
                try testing.expectEqual(step.idx, ev.?.enter.idx);
            },
            .exit => {
                try testing.expect(ev.? == .exit);
                try testing.expectEqual(&nodes[step.idx], ev.?.exit.node);
                try testing.expectEqual(step.idx, ev.?.exit.idx);
            },
        }
    }
    // the stream is exhausted: null, and it stays null
    try testing.expectEqual(@as(?Iterator.Event, null), it.next());
    try testing.expectEqual(@as(?Iterator.Event, null), it.next());
}

// helper to make a node with just tag + parent (loc/etc. don't matter for the walk)
fn n(tag: Node.Tag, parent: u32) Node {
    return .{ .tag = tag, .loc = .{}, .parent_idx = parent };
}

test "iterator: single root, no children" {
    // root
    const nodes = [_]Node{n(.root, 0)};
    try expectWalk(&nodes, &.{
        .{ .kind = .enter, .idx = 0 },
        .{ .kind = .exit, .idx = 0 },
    });
}

test "iterator: root with two leaf children" {
    // root { a  b }   (a and b are children of root=0)
    const nodes = [_]Node{
        n(.root, 0), // 0
        n(.node, 0), // 1  a
        n(.node, 0), // 2  b
    };
    try expectWalk(&nodes, &.{
        .{ .kind = .enter, .idx = 0 }, // root
        .{ .kind = .enter, .idx = 1 }, //   a
        .{ .kind = .exit, .idx = 1 }, //   /a
        .{ .kind = .enter, .idx = 2 }, //   b
        .{ .kind = .exit, .idx = 2 }, //   /b
        .{ .kind = .exit, .idx = 0 }, // /root
    });
}

test "iterator: nested — root { a { c } b }" {
    // pre-order: root(0), a(1,parent0), c(2,parent1), b(3,parent0)
    const nodes = [_]Node{
        n(.root, 0), // 0  root
        n(.node, 0), // 1  a  (child of root)
        n(.node, 1), // 2  c  (child of a)
        n(.node, 0), // 3  b  (child of root)
    };
    try expectWalk(&nodes, &.{
        .{ .kind = .enter, .idx = 0 }, // root
        .{ .kind = .enter, .idx = 1 }, //   a
        .{ .kind = .enter, .idx = 2 }, //     c
        .{ .kind = .exit, .idx = 2 }, //     /c
        .{ .kind = .exit, .idx = 1 }, //   /a  (unwind: c's parent(1) != b's parent(0))
        .{ .kind = .enter, .idx = 3 }, //   b
        .{ .kind = .exit, .idx = 3 }, //   /b
        .{ .kind = .exit, .idx = 0 }, // /root
    });
}

test "iterator: deep chain — root { a { b { c } } }" {
    // each node is the sole child of the previous — tests multi-level unwind
    const nodes = [_]Node{
        n(.root, 0), // 0
        n(.node, 0), // 1  a
        n(.node, 1), // 2  b
        n(.node, 2), // 3  c
    };
    try expectWalk(&nodes, &.{
        .{ .kind = .enter, .idx = 0 },
        .{ .kind = .enter, .idx = 1 },
        .{ .kind = .enter, .idx = 2 },
        .{ .kind = .enter, .idx = 3 },
        .{ .kind = .exit, .idx = 3 }, // unwind all the way back up
        .{ .kind = .exit, .idx = 2 },
        .{ .kind = .exit, .idx = 1 },
        .{ .kind = .exit, .idx = 0 },
    });
}

test "iterator: mixed depths — root { a { c d } b }" {
    // root(0) a(1,0) c(2,1) d(3,1) b(4,0)
    const nodes = [_]Node{
        n(.root, 0), // 0 root
        n(.node, 0), // 1 a
        n(.node, 1), // 2 c
        n(.node, 1), // 3 d
        n(.node, 0), // 4 b
    };
    try expectWalk(&nodes, &.{
        .{ .kind = .enter, .idx = 0 }, // root
        .{ .kind = .enter, .idx = 1 }, //   a
        .{ .kind = .enter, .idx = 2 }, //     c
        .{ .kind = .exit, .idx = 2 }, //     /c
        .{ .kind = .enter, .idx = 3 }, //     d  (sibling of c under a)
        .{ .kind = .exit, .idx = 3 }, //     /d
        .{ .kind = .exit, .idx = 1 }, //   /a
        .{ .kind = .enter, .idx = 4 }, //   b
        .{ .kind = .exit, .idx = 4 }, //   /b
        .{ .kind = .exit, .idx = 0 }, // /root
    });
}

//MARK: SkipTests
// Drive with a skip requested right after entering node `skip_after_idx`.
fn expectWalkSkip(nodes: []const Node, skip_at: u32, expected: []const Step) !void {
    var it = Iterator{ .nodes = nodes };
    for (expected, 0..) |step, i| {
        errdefer std.debug.print("mismatch at step {d}\n", .{i});
        const ev = it.next();
        switch (step.kind) {
            .enter => {
                try testing.expect(ev.? == .enter);
                try testing.expectEqual(&nodes[step.idx], ev.?.enter.node);
                if (ev.?.enter.idx == skip_at) it.skip(); // prune this subtree
            },
            .exit => {
                try testing.expect(ev.? == .exit);
                try testing.expectEqual(&nodes[step.idx], ev.?.exit.node);
            },
        }
    }
    try testing.expectEqual(@as(?Iterator.Event, null), it.next());
}

test "iterator: skip prunes a subtree" {
    // root { a { c d } b } — skip `a` (idx 1): should NOT visit c,d; exit a, go to b
    const nodes = [_]Node{
        n(.root, 0), // 0 root
        n(.node, 0), // 1 a  <- skipped
        n(.node, 1), // 2 c  (should be skipped)
        n(.node, 1), // 3 d  (should be skipped)
        n(.node, 0), // 4 b
    };
    try expectWalkSkip(&nodes, 1, &.{
        .{ .kind = .enter, .idx = 0 }, // root
        .{ .kind = .enter, .idx = 1 }, //   a  (skip requested here)
        .{ .kind = .exit, .idx = 1 }, //   /a  — c,d NOT visited
        .{ .kind = .enter, .idx = 4 }, //   b
        .{ .kind = .exit, .idx = 4 }, //   /b
        .{ .kind = .exit, .idx = 0 }, // /root
    });
}

// MARK: nodeAtByte tests
test "nodeAtByte: cursor inside a node's body returns that node" {
    var ast = try Ast.init(testing.allocator, "Ball : circle { radius 1 }");
    defer ast.deinit(testing.allocator);

    const idx = ast.nodeAtByte(16) orelse return error.TestExpectedNode;
    try testing.expectEqualStrings("Ball", ast.nodes[idx].name_loc.slice("Ball : circle { radius 1 }"));
}

test "nodeAtByte: cursor on the node name returns the node" {
    var ast = try Ast.init(testing.allocator, "Ball : circle { radius 1 }");
    defer ast.deinit(testing.allocator);
    try testing.expect(ast.nodeAtByte(0) != null);
}

test "nodeAtByte: deepest node wins for a nested cursor" {
    const src = "Level : level { Ball : circle { radius 1 } }";
    var ast = try Ast.init(testing.allocator, src);
    defer ast.deinit(testing.allocator);

    const idx = ast.nodeAtByte(32) orelse return error.TestExpectedNode;
    try testing.expectEqualStrings("Ball", ast.nodes[idx].name_loc.slice(src));
}

test "nodeAtByte: cursor between the outer and inner node is the outer" {
    const src = "Level : level { Ball : circle { radius 1 } }";
    var ast = try Ast.init(testing.allocator, src);
    defer ast.deinit(testing.allocator);

    const idx = ast.nodeAtByte(15) orelse return error.TestExpectedNode;
    try testing.expectEqualStrings("Level", ast.nodes[idx].name_loc.slice(src));
}

test "nodeAtByte: an unclosed node still has an extent to EOF" {
    const src = "Ball : circle { radius 1";
    var ast = try Ast.init(testing.allocator, src);
    defer ast.deinit(testing.allocator);

    try testing.expect(ast.nodeAtByte(24) != null);
}
