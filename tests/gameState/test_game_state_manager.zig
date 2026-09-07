//! GameStateManager tests — state tree declaration, navigation,
//! transition-queue resolution, and game-scoped state variables.
//!
//! Written test-first against docs/brickles-readiness-plan.html Phase 1.
//! Three cases pin fixes that have NOT landed yet and are expected to
//! FAIL until they do:
//!   - "descend enters first child, ascend returns to parent"  (Plan 1A)
//!   - "restart_game resets the overlay stack"                 (Plan 1A)
//!   - "string state values are copied, not borrowed"          (Plan 1B)

const std = @import("std");
const testing = std.testing;

const game_state = @import("game_state");
const GameStateManager = game_state.GameStateManager;
const TransitionResult = game_state.TransitionResult;

const math = @import("math");
const GameMemory = @import("memory");

fn resolveOk(mgr: *GameStateManager) !TransitionResult {
    return mgr.resolvePending() orelse error.ExpectedTransition;
}

fn expectVarInt(mgr: *GameStateManager, key: []const u8, expected: i64) !void {
    const v = mgr.getStateVar(key) orelse return error.StateVarMissing;
    try testing.expect(v == .int);
    try testing.expectEqual(expected, v.int);
}

// MARK: Tree declaration

test "declareRoot links roots as siblings in declaration order" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const a = try mgr.declareRoot("menu", .{});
    const b = try mgr.declareRoot("game", .{});
    const c = try mgr.declareRoot("credits", .{});

    try testing.expectEqual(@as(usize, 3), mgr.roots.items.len);
    try testing.expectEqual(a, mgr.roots.items[0]);
    try testing.expectEqual(b, mgr.roots.items[1]);
    try testing.expectEqual(c, mgr.roots.items[2]);

    try testing.expect(a.prev_sibling == null);
    try testing.expectEqual(b, a.next_sibling.?);
    try testing.expectEqual(a, b.prev_sibling.?);
    try testing.expectEqual(c, b.next_sibling.?);
    try testing.expectEqual(b, c.prev_sibling.?);
    try testing.expect(c.next_sibling == null);

    try testing.expect(a.parent == null);
    try testing.expect(a.first_child == null);
}

test "declareRoot copies the state name" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var name_buf: [8]u8 = undefined;
    @memcpy(name_buf[0..4], "temp");
    const node = try mgr.declareRoot(name_buf[0..4], .{});

    name_buf[0] = 'X';
    try testing.expectEqualStrings("temp", node.name);
    try testing.expect(mgr.findByName("temp") != null);
}

test "declareChild builds the child chain under a parent" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const parent = try mgr.declareRoot("game", .{});
    const c1 = try mgr.declareChild("level1", parent, .{});
    const c2 = try mgr.declareChild("level2", parent, .{});
    const c3 = try mgr.declareChild("level3", parent, .{});

    try testing.expectEqual(@as(usize, 1), mgr.roots.items.len);
    try testing.expectEqual(c1, parent.first_child.?);
    try testing.expectEqual(c2, c1.next_sibling.?);
    try testing.expectEqual(c3, c2.next_sibling.?);
    try testing.expect(c3.next_sibling == null);
    try testing.expect(c1.prev_sibling == null);
    try testing.expectEqual(c1, c2.prev_sibling.?);
    try testing.expectEqual(c2, c3.prev_sibling.?);

    try testing.expectEqual(parent, c1.parent.?);
    try testing.expectEqual(parent, c2.parent.?);
    try testing.expectEqual(parent, c3.parent.?);
}

// MARK: transition_to

test "transition_to moves current and reports the target descriptor" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const serve = try mgr.declareRoot("serve", .{});
    const game_over = try mgr.declareRoot("game_over", .{
        .world_policy = .clear,
        .systems = .{ .movement = false, .actions = false },
    });

    mgr.queueAction(.{ .transition_to = "serve" });
    const first = try resolveOk(&mgr);
    try testing.expect(first.prev_state == null);
    try testing.expectEqualStrings("serve", first.next_state);
    try testing.expect(first.world_policy == .preserve);
    try testing.expect(first.systems.movement);
    try testing.expectEqual(serve, mgr.current.?);

    mgr.queueAction(.{ .transition_to = "game_over" });
    const second = try resolveOk(&mgr);
    try testing.expectEqualStrings("serve", second.prev_state.?);
    try testing.expectEqualStrings("game_over", second.next_state);
    try testing.expect(second.world_policy == .clear);
    try testing.expect(!second.systems.movement);
    try testing.expect(!second.systems.actions);
    try testing.expect(second.systems.camera);
    try testing.expectEqual(game_over, mgr.current.?);
}

test "transition_to unknown state is rejected and consumed" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const serve = try mgr.declareRoot("serve", .{});
    mgr.queueAction(.{ .transition_to = "serve" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.{ .transition_to = "bogus" });
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(serve, mgr.current.?);

    // pending was consumed, not stuck
    try testing.expect(mgr.resolvePending() == null);
    mgr.queueAction(.{ .transition_to = "serve" });
    try testing.expect(mgr.resolvePending() != null);
}

// MARK: Sibling navigation

test "advance and goback walk siblings and stop at the ends" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const one = try mgr.declareRoot("one", .{});
    _ = try mgr.declareRoot("two", .{});
    const three = try mgr.declareRoot("three", .{});

    mgr.queueAction(.{ .transition_to = "one" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.advance);
    const fwd1 = try resolveOk(&mgr);
    try testing.expectEqualStrings("two", fwd1.next_state);
    try testing.expectEqualStrings("one", fwd1.prev_state.?);

    mgr.queueAction(.advance);
    const fwd2 = try resolveOk(&mgr);
    try testing.expectEqualStrings("three", fwd2.next_state);

    // off the end: rejected, current unchanged
    mgr.queueAction(.advance);
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(three, mgr.current.?);

    mgr.queueAction(.goback);
    const back1 = try resolveOk(&mgr);
    try testing.expectEqualStrings("two", back1.next_state);
    try testing.expectEqualStrings("three", back1.prev_state.?);

    mgr.queueAction(.goback);
    const back2 = try resolveOk(&mgr);
    try testing.expectEqualStrings("one", back2.next_state);

    // off the front: rejected, current unchanged
    mgr.queueAction(.goback);
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(one, mgr.current.?);
}

test "navigation without a current state resolves to null" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    _ = try mgr.declareRoot("only", .{});

    mgr.queueAction(.advance);
    try testing.expect(mgr.resolvePending() == null);
    mgr.queueAction(.goback);
    try testing.expect(mgr.resolvePending() == null);
    mgr.queueAction(.descend);
    try testing.expect(mgr.resolvePending() == null);
    mgr.queueAction(.ascend);
    try testing.expect(mgr.resolvePending() == null);
    mgr.queueAction(.restart_state);
    try testing.expect(mgr.resolvePending() == null);

    try testing.expect(mgr.current == null);
}

// MARK: Tree navigation (descend / ascend)

test "descend enters first child, ascend returns to parent" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const game = try mgr.declareRoot("game", .{});
    const level1 = try mgr.declareChild("level1", game, .{
        .systems = .{ .collision = false },
    });
    _ = try mgr.declareChild("level2", game, .{});

    mgr.queueAction(.{ .transition_to = "game" });
    _ = try resolveOk(&mgr);

    // PINS PLAN 1A: fails until resolvePending gains .descend/.ascend arms
    mgr.queueAction(.descend);
    const down = mgr.resolvePending() orelse return error.DescendNotWired;
    try testing.expectEqualStrings("level1", down.next_state);
    try testing.expectEqualStrings("game", down.prev_state.?);
    try testing.expect(!down.systems.collision);
    try testing.expectEqual(level1, mgr.current.?);

    mgr.queueAction(.ascend);
    const up = mgr.resolvePending() orelse return error.AscendNotWired;
    try testing.expectEqualStrings("game", up.next_state);
    try testing.expectEqualStrings("level1", up.prev_state.?);
    try testing.expectEqual(game, mgr.current.?);
}

test "descend on a leaf and ascend at a root resolve to null" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const leaf = try mgr.declareRoot("leaf", .{});
    mgr.queueAction(.{ .transition_to = "leaf" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.descend);
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(leaf, mgr.current.?);

    mgr.queueAction(.ascend);
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(leaf, mgr.current.?);
}

// MARK: Push / pop overlays

test "push forces preserve and suspends, pop restores" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const playing = try mgr.declareRoot("playing", .{ .world_policy = .clear });
    const pause = try mgr.declareRoot("pause", .{
        .world_policy = .clear, // deliberately .clear to prove push overrides it
        .systems = .{ .movement = false, .physics = false },
    });

    mgr.queueAction(.{ .transition_to = "playing" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.{ .push = pause });
    const pushed = try resolveOk(&mgr);
    try testing.expectEqualStrings("pause", pushed.next_state);
    try testing.expectEqualStrings("playing", pushed.prev_state.?);
    try testing.expect(pushed.world_policy == .preserve); // forced, despite pause declaring .clear
    try testing.expect(!pushed.systems.movement);
    try testing.expectEqual(@as(usize, 1), mgr.stack_depth);
    try testing.expectEqual(pause, mgr.current.?);

    mgr.queueAction(.pop);
    const popped = try resolveOk(&mgr);
    try testing.expectEqualStrings("playing", popped.next_state);
    try testing.expectEqualStrings("pause", popped.prev_state.?);
    try testing.expect(popped.world_policy == .preserve); // forced, despite playing declaring .clear
    try testing.expect(popped.systems.movement);
    try testing.expectEqual(@as(usize, 0), mgr.stack_depth);
    try testing.expectEqual(playing, mgr.current.?);
}

test "pop with nothing pushed is rejected" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const only = try mgr.declareRoot("only", .{});
    mgr.queueAction(.{ .transition_to = "only" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.pop);
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(only, mgr.current.?);
    try testing.expectEqual(@as(usize, 0), mgr.stack_depth);
}

test "push beyond the stack limit is rejected" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    _ = try mgr.declareRoot("base", .{});
    const overlay = try mgr.declareRoot("overlay", .{});

    mgr.queueAction(.{ .transition_to = "base" });
    _ = try resolveOk(&mgr);

    const max_depth = 16; // mirrors MAX_STACK_DEPTH in GameStateManager.zig
    var i: usize = 0;
    while (i < max_depth) : (i += 1) {
        mgr.queueAction(.{ .push = overlay });
        try testing.expect(mgr.resolvePending() != null);
    }
    try testing.expectEqual(@as(usize, max_depth), mgr.stack_depth);

    mgr.queueAction(.{ .push = overlay });
    try testing.expect(mgr.resolvePending() == null);
    try testing.expectEqual(@as(usize, max_depth), mgr.stack_depth);
    try testing.expectEqual(overlay, mgr.current.?);
}

// MARK: Queue semantics

test "queueAction keeps the first action when one is pending" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    _ = try mgr.declareRoot("one", .{});
    _ = try mgr.declareRoot("two", .{});

    mgr.queueAction(.{ .transition_to = "one" });
    mgr.queueAction(.{ .transition_to = "two" }); // dropped: first wins

    const r = try resolveOk(&mgr);
    try testing.expectEqualStrings("one", r.next_state);
    try testing.expect(mgr.resolvePending() == null);
}

// MARK: Restarts

test "restart_state re-reports the current descriptor" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const arena = try mgr.declareRoot("arena", .{
        .world_policy = .clear,
        .systems = .{ .lifetime = false },
    });
    mgr.queueAction(.{ .transition_to = "arena" });
    _ = try resolveOk(&mgr);

    mgr.queueAction(.restart_state);
    const r = try resolveOk(&mgr);
    try testing.expectEqualStrings("arena", r.next_state);
    try testing.expectEqualStrings("arena", r.prev_state.?);
    try testing.expect(r.world_policy == .clear);
    try testing.expect(!r.systems.lifetime);
    try testing.expectEqual(arena, mgr.current.?);
}

test "restart_game forces world clear and wipes state vars" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const serve = try mgr.declareRoot("serve", .{}); // declared .preserve
    _ = try mgr.declareRoot("game_over", .{ .world_policy = .clear });

    mgr.queueAction(.{ .transition_to = "game_over" });
    _ = try resolveOk(&mgr);

    try mgr.setStateVar("score", .{ .int = 5 });
    try mgr.setStateVar("winner", .{ .string = "left" });

    mgr.queueAction(.{ .restart_game = "serve" });
    const r = try resolveOk(&mgr);
    try testing.expectEqualStrings("serve", r.next_state);
    try testing.expect(r.world_policy == .clear); // forced, despite serve declaring .preserve
    try testing.expectEqual(serve, mgr.current.?);

    try testing.expect(mgr.getStateVar("score") == null);
    try testing.expect(mgr.getStateVar("winner") == null);

    // manager is still usable after the reset
    try mgr.setStateVar("score", .{ .int = 0 });
    try expectVarInt(&mgr, "score", 0);
}

test "restart_game resets the overlay stack" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    _ = try mgr.declareRoot("base", .{});
    const pause = try mgr.declareRoot("pause", .{});
    _ = try mgr.declareRoot("serve", .{});

    mgr.queueAction(.{ .transition_to = "base" });
    _ = try resolveOk(&mgr);
    mgr.queueAction(.{ .push = pause });
    _ = try resolveOk(&mgr);
    try testing.expectEqual(@as(usize, 1), mgr.stack_depth);

    mgr.queueAction(.{ .restart_game = "serve" });
    _ = try resolveOk(&mgr);

    // PINS PLAN 1A: fails until restart_game resets stack_depth
    try testing.expectEqual(@as(usize, 0), mgr.stack_depth);
}

// MARK: State variables

test "state vars round trip all four value types" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    try mgr.setStateVar("lives", .{ .int = 42 });
    try mgr.setStateVar("speed", .{ .float = 2.5 });
    try mgr.setStateVar("muted", .{ .bool = true });
    try mgr.setStateVar("title", .{ .string = "hello" });

    try expectVarInt(&mgr, "lives", 42);

    const speed = mgr.getStateVar("speed") orelse return error.StateVarMissing;
    try testing.expect(speed == .float);
    try testing.expectEqual(@as(f64, 2.5), speed.float);

    const muted = mgr.getStateVar("muted") orelse return error.StateVarMissing;
    try testing.expect(muted == .bool);
    try testing.expect(muted.bool);

    const title = mgr.getStateVar("title") orelse return error.StateVarMissing;
    try testing.expect(title == .string);
    try testing.expectEqualStrings("hello", title.string);

    try testing.expect(mgr.getStateVar("nope") == null);
}

test "state var keys are copied, not borrowed" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var key_buf: [8]u8 = undefined;
    @memcpy(key_buf[0..5], "score");
    try mgr.setStateVar(key_buf[0..5], .{ .int = 7 });

    key_buf[0] = 'X';
    try expectVarInt(&mgr, "score", 7);
}

test "string state values are copied, not borrowed" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var val_buf: [8]u8 = undefined;
    @memcpy(val_buf[0..5], "alpha");
    try mgr.setStateVar("word", .{ .string = val_buf[0..5] });

    @memset(val_buf[0..5], 'X');

    const v = mgr.getStateVar("word") orelse return error.StateVarMissing;
    try testing.expect(v == .string);
    // PINS PLAN 1B: fails until setStateVar dupes string values
    try testing.expectEqualStrings("alpha", v.string);
}

test "setStateVar overwrites and can change value type" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    try mgr.setStateVar("v", .{ .int = 1 });
    try expectVarInt(&mgr, "v", 1);

    try mgr.setStateVar("v", .{ .string = "abc" });
    var v = mgr.getStateVar("v") orelse return error.StateVarMissing;
    try testing.expect(v == .string);
    try testing.expectEqualStrings("abc", v.string);

    // string -> string overwrite (post-Plan-1B this must free the old copy)
    try mgr.setStateVar("v", .{ .string = "defgh" });
    v = mgr.getStateVar("v") orelse return error.StateVarMissing;
    try testing.expectEqualStrings("defgh", v.string);

    // string -> non-string (post-Plan-1B this must free the old copy)
    try mgr.setStateVar("v", .{ .bool = false });
    v = mgr.getStateVar("v") orelse return error.StateVarMissing;
    try testing.expect(v == .bool);
    try testing.expect(!v.bool);
}

// MARK: Lookup

test "findByName searches the whole forest" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    const menu = try mgr.declareRoot("menu", .{});
    const game = try mgr.declareRoot("game", .{});
    _ = try mgr.declareChild("world1", game, .{});
    const world2 = try mgr.declareChild("world2", game, .{});
    const boss = try mgr.declareChild("boss", world2, .{});

    try testing.expectEqual(menu, mgr.findByName("menu").?);
    try testing.expectEqual(game, mgr.findByName("game").?);
    try testing.expectEqual(boss, mgr.findByName("boss").?);
    try testing.expect(mgr.findByName("nope") == null);
}
