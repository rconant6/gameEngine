const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ast = @import("ast.zig");
const Ast = ast.Ast;
const Node = ast.Node;
const NodeTag = Node.Tag;
const RawValue = ast.RawValue;
const diag = @import("diagnostic.zig");
const Diagnostic = diag.Diagnostic;
const lex = @import("lexer.zig");
const Lexer = lex.Lexer;
const tok = @import("token.zig");
const Token = tok.Token;
const Tag = Token.Tag;
const Loc = tok.Loc;

pub const Parser = struct {
    perm: Allocator,

    src: [:0]const u8,
    node_idx: u32 = 0,

    nodes: ArrayList(Node) = .empty,
    values: ArrayList(RawValue) = .empty,
    errors: ArrayList(Diagnostic) = .empty,
    meta: ArrayList(struct { last_child_idx: u32 = 0 }) = .empty,

    lexer: Lexer = undefined,
    tok: Token = .{ .tag = .invalid, .loc = .{ .start = 0, .end = 0 } },
    prev_loc: Loc = undefined,

    // AST constructor — never fails except OOM
    // Syntax errors are data in `errors`.
    pub fn parse(p: *Parser) error{OutOfMemory}!Ast {
        p.lexer = .init(p.src);

        // node 0 is the root
        try p.nodes.append(p.perm, .{
            .tag = .root,
            .loc = .{ .start = 0, .end = 0 },
            .parent_idx = 0,
        });
        try p.meta.append(p.perm, .{});

        p.consume();

        parser: switch (p.tok.tag) {
            .eof => {
                // any still-open nodes = unclosed braces
                while (p.node_idx != 0) {
                    try p.err(.missing_brace, p.tok.loc);
                    p.up();
                }
                break :parser;
            },

            .r_brace => {
                if (p.node_idx == 0) {
                    // stray '}' at top level
                    try p.err(.unexpected_token, p.tok.loc);
                    p.consume();
                    continue :parser p.tok.tag;
                }
                p.consume();
                p.up();
                continue :parser p.tok.tag;
            },
            .r_bracket => {
                if (p.node_idx == 0) {
                    // stray ']' at top level
                    try p.err(.unexpected_token, p.tok.loc);
                    p.consume();
                    continue :parser p.tok.tag;
                }
                p.consume();
                p.up();
                continue :parser p.tok.tag;
            },

            .identifier => {
                const name = p.tok;
                p.consume();

                switch (p.tok.tag) {
                    .colon => { // Name : type {
                        p.consume();
                        if (p.tok.tag != .identifier) {
                            try p.err(.unexpected_token, p.tok.loc);
                            p.recover();
                            continue :parser p.tok.tag;
                        }
                        const type_tok = p.tok;
                        p.consume();
                        if (p.tok.tag != .l_brace) {
                            try p.err(.missing_brace, p.tok.loc);
                            p.recover();
                            continue :parser p.tok.tag;
                        }
                        p.consume();
                        const idx = try p.addChild(.node, name.loc, type_tok.loc);
                        p.down(idx);
                        continue :parser p.tok.tag;
                    },

                    .l_brace => { // Name {  (typeless container)
                        p.consume();
                        const idx = try p.addChild(.node, name.loc, .{});
                        p.down(idx);
                        continue :parser p.tok.tag;
                    },

                    else => { // member of the current node
                        if (startsValue(p.tok.tag)) { // field value -> property
                            const vidx = p.parseValue() orelse {
                                p.recover();
                                continue :parser p.tok.tag;
                            };
                            const c = try p.addChild(.property, name.loc, .{});
                            p.nodes.items[c].value_idx = vidx;
                        } else { // bare word -> flag
                            _ = try p.addChild(.flag, name.loc, .{});
                        }
                        continue :parser p.tok.tag;
                    },
                }
            },

            else => {
                try p.err(.unexpected_token, p.tok.loc);
                p.recover();
                continue :parser p.tok.tag;
            },
        }

        return p.finalize();
    }

    pub fn deinit(p: *Parser) void {
        p.nodes.deinit(p.perm);
        p.errors.deinit(p.perm);
        p.values.deinit(p.perm);
        p.meta.deinit(p.perm);
    }

    fn finalize(p: *Parser) error{OutOfMemory}!Ast {
        return .{
            .nodes = try p.nodes.toOwnedSlice(p.perm),
            .values = try p.values.toOwnedSlice(p.perm),
            .errors = try p.errors.toOwnedSlice(p.perm),
        };
    }

    fn parseValue(p: *Parser) ?u32 {
        switch (p.tok.tag) {
            .number => {
                const f = std.fmt.parseFloat(
                    f64,
                    p.tok.loc.slice(p.src),
                ) catch {
                    p.err(.invalid_token, p.tok.loc) catch return null;
                    return null;
                };
                p.consume();
                return p.push(.{ .number = f });
            },
            .minus => {
                p.consume();
                if (p.tok.tag != .number) {
                    p.err(.unexpected_token, p.tok.loc) catch {};
                    return null;
                }
                const f = std.fmt.parseFloat(
                    f64,
                    p.tok.loc.slice(p.src),
                ) catch {
                    p.err(.invalid_token, p.tok.loc) catch {};
                    return null;
                };
                p.consume();
                return p.push(.{ .number = -f });
            },
            .string_lit => {
                const s = p.tok.loc.slice(p.src); // span already excludes quotes
                p.consume();
                return p.push(.{ .string = s });
            },
            .color_lit => {
                const c = std.fmt.parseInt(
                    u32,
                    p.tok.loc.slice(p.src),
                    16,
                ) catch {
                    p.err(.invalid_token, p.tok.loc) catch {};
                    return null;
                };
                p.consume();
                return p.push(.{ .color = c });
            },
            .true => {
                p.consume();
                return p.push(.{ .boolean = true });
            },
            .false => {
                p.consume();
                return p.push(.{ .boolean = false });
            },
            .identifier => {
                const w = p.tok.loc.slice(p.src);
                p.consume();
                return p.push(.{ .ident = w });
            },
            // .l_brace => return p.parseVec(),
            .l_bracket => return p.parseVec(),
            else => {
                p.err(.unexpected_token, p.tok.loc) catch {};
                return null;
            },
        }
    }

    // [ number (, number)* ]
    // arity checked later at ingest.
    fn parseVec(p: *Parser) ?u32 {
        p.consume(); // '{'
        var nums: ArrayList(f64) = .empty;
        errdefer nums.deinit(p.perm);

        while (true) {
            var neg = false;
            if (p.tok.tag == .minus) {
                p.consume();
                neg = true;
            }
            if (p.tok.tag != .number) {
                p.err(.unexpected_token, p.tok.loc) catch {};
                nums.deinit(p.perm);
                return null;
            }
            var n = std.fmt.parseFloat(f64, p.tok.loc.slice(p.src)) catch {
                p.err(.invalid_token, p.tok.loc) catch {};
                nums.deinit(p.perm);
                return null;
            };
            if (neg) n = -n;
            nums.append(p.perm, n) catch {
                nums.deinit(p.perm);
                return null;
            };
            p.consume();

            if (p.tok.tag == .comma) {
                p.consume();
                continue;
            }
            break;
        }

        if (p.tok.tag != .r_bracket) {
            p.err(.unexpected_token, p.tok.loc) catch {};
            nums.deinit(p.perm);
            return null;
        }
        p.consume(); // '}'

        const owned = nums.toOwnedSlice(p.perm) catch return null;
        return p.push(.{ .vec = owned });
    }

    fn push(p: *Parser, v: RawValue) ?u32 {
        const idx: u32 = @intCast(p.values.items.len);
        p.values.append(p.perm, v) catch return null;
        return idx;
    }

    // MARK: Tree building
    fn addChild(p: *Parser, tag: NodeTag, name_loc: Loc, type_loc: Loc) error{OutOfMemory}!u32 {
        const idx: u32 = @intCast(p.nodes.items.len);

        try p.nodes.append(p.perm, .{
            .tag = tag,
            .loc = name_loc,
            .parent_idx = p.node_idx,
            .next_idx = 0,
            .name_loc = name_loc,
            .type_loc = type_loc,
            .value_idx = 0,
        });
        try p.meta.append(p.perm, .{});

        const parent_meta = &p.meta.items[p.node_idx];
        if (parent_meta.last_child_idx != 0)
            p.nodes.items[parent_meta.last_child_idx].next_idx = idx;
        parent_meta.last_child_idx = idx;

        return idx;
    }

    fn up(p: *Parser) void {
        p.node_idx = p.nodes.items[p.node_idx].parent_idx;
    }
    fn down(p: *Parser, idx: u32) void {
        p.node_idx = idx;
    }

    fn recover(p: *Parser) void {
        recover: switch (p.tok.tag) {
            .eof, .r_brace, .r_bracket => return,
            .identifier => {
                const pk = p.peek();
                if (pk == .colon or pk == .l_brace or pk == .l_bracket) return; // start of a real member/node
                p.consume();
                continue :recover p.tok.tag;
            },
            else => {
                p.consume();
                continue :recover p.tok.tag;
            },
        }
    }

    // MARK: Token streams
    fn consume(p: *Parser) void {
        p.prev_loc = p.tok.loc;
        p.tok = p.lexer.next();
    }
    fn peek(p: *Parser) Tag {
        var save = p.lexer; // Lexer is a small value struct; copy + advance the copy
        return save.next().tag;
    }
    fn peek2(p: *Parser) struct { t1: Tag, t2: Tag } {
        var save = p.lexer;
        const t1 = save.next().tag;
        const t2 = save.next().tag;
        return .{ .t1 = t1, .t2 = t2 };
    }

    // append a bare-tag diagnostic (no payload)
    fn err(p: *Parser, comptime tag: anytype, loc: Loc) error{OutOfMemory}!void {
        try p.errors.append(p.perm, .{ .severity = .err, .loc = loc, .tag = tag });
    }
};

fn startsValue(t: Tag) bool {
    return switch (t) {
        .number,
        .minus,
        .string_lit,
        .color_lit,
        .true,
        .false,
        .l_brace,
        .l_bracket,
        .identifier,
        => true,
        else => false,
    };
}
