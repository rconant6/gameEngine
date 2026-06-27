//! Phase 6B — StateTextSys: bind a Text entity to a game-state variable.
//!
//! These tests target a system and a component that do NOT exist yet, so they
//! are red at the COMPILE step until 6B lands:
//!   - ecs.StateText                        (new component, src/ecs/Components.zig)
//!   - systems.stateTextSystem(world, mgr)  (new, src/systems/StateTextSys.zig)
//!
//! Behavior under test (from docs/brickles-readiness-plan.html 6B):
//!   For each entity with {StateText, Text}: read the state var named by
//!   StateText.key; format "<prefix><value>" into the StateText's OWNED inline
//!   buffer (st.buf); point text.text at st.buf[0..st.len].
//!
//! Format per StateValue variant:
//!   int    "{s}{d}"      float  "{s}{d:.1}"
//!   string "{s}{s}"      bool   "{s}{}"  (-> true / false)
//!
//! THE LOAD-BEARING INVARIANT (see the red callout in the plan): text.text must
//! point INTO the StateText component's own buf, not at borrowed scratch. The
//! "writes into owned buffer" test asserts exactly that by checking the slice
//! pointer lies within st.buf — if a future refactor formats into a temp and
//! borrows it, that test goes red even though the string content looks right.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Text = ecs.Text;
const StateText = ecs.StateText;

const renderer = @import("renderer");
const Colors = renderer.Colors;

const game_state = @import("game_state");
const GameStateManager = game_state.GameStateManager;

const math = @import("math");
const GameMemory = math.GameMemory;

const systems = @import("systems");
const stateTextSystem = systems.stateTextSystem;

const white = Colors.WHITE;

// Spawn an entity carrying a Text + StateText pair. The Text starts with
// placeholder content the system is expected to overwrite.
fn spawnBound(world: *World, key: []const u8, prefix: []const u8) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Text, .{
        .text = "placeholder",
        .font_name = "__default__",
        .size = 1.5,
        .text_color = white,
    });
    try world.addComponent(e, StateText, .{ .key = key, .prefix = prefix });
    return e;
}

// MARK: formatting per StateValue variant

test "int state var renders as prefix + integer" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("score_left", .{ .int = 7 });
    const e = try spawnBound(&world, "score_left", "SCORE: ");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("SCORE: 7", text.text);
}

test "empty prefix renders the bare value" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("score_right", .{ .int = 0 });
    const e = try spawnBound(&world, "score_right", "");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("0", text.text);
}

test "float state var renders with one decimal" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("time", .{ .float = 3.25 });
    const e = try spawnBound(&world, "time", "T=");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("T=3.3", text.text); // {d:.1} rounds 3.25 half-up -> 3.3
}

test "string state var renders verbatim after prefix" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("player", .{ .string = "ALICE" });
    const e = try spawnBound(&world, "player", "P1: ");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("P1: ALICE", text.text);
}

test "bool state var renders true/false" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("ready", .{ .bool = true });
    const e = try spawnBound(&world, "ready", "READY=");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("READY=true", text.text);
}

// MARK: the load-bearing invariant — text.text points into owned storage

test "system writes into the StateText's own buffer, not a borrow" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("score_left", .{ .int = 42 });
    const e = try spawnBound(&world, "score_left", "");

    stateTextSystem(&world, &mgr);

    const st = world.getComponentMut(e, StateText).?;
    const text = world.getComponent(e, Text).?;

    // st.len records what was written, and text.text must be exactly that prefix
    // of the component's own inline buffer — same base pointer, same length.
    try testing.expectEqualStrings("42", text.text);
    try testing.expectEqual(st.len, text.text.len);
    try testing.expectEqual(@intFromPtr(&st.buf[0]), @intFromPtr(text.text.ptr));
}

// MARK: robustness

test "missing state var leaves the existing text untouched" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    // no setStateVar for "absent" — getStateVar returns null, system skips.
    const e = try spawnBound(&world, "absent", "X=");

    stateTextSystem(&world, &mgr);

    const text = world.getComponent(e, Text).?;
    try testing.expectEqualStrings("placeholder", text.text); // unchanged
}

test "value change between frames is reflected on the next run" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    try mgr.setStateVar("score_left", .{ .int = 1 });
    const e = try spawnBound(&world, "score_left", "");

    stateTextSystem(&world, &mgr);
    try testing.expectEqualStrings("1", world.getComponent(e, Text).?.text);

    try mgr.setStateVar("score_left", .{ .int = 23 });
    stateTextSystem(&world, &mgr);
    try testing.expectEqualStrings("23", world.getComponent(e, Text).?.text);
}

// MARK: truncation — must fit in buf without panicking

test "oversized formatted text truncates instead of panicking" {
    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();

    var world = try World.init(testing.allocator);
    defer world.deinit();

    // A 60-char prefix plus a number would exceed the 64-byte buf. The system
    // must truncate to the buffer, never overrun or panic.
    const long_prefix = "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJ"; // 60 chars
    try mgr.setStateVar("score_left", .{ .int = 999999 });
    const e = try spawnBound(&world, "score_left", long_prefix);

    stateTextSystem(&world, &mgr); // must not panic

    const st = world.getComponentMut(e, StateText).?;
    const text = world.getComponent(e, Text).?;

    try testing.expect(text.text.len <= st.buf.len); // never exceeds the buffer
    try testing.expectEqual(st.len, text.text.len);
    // what did fit is a correct prefix of the intended string
    try testing.expect(std.mem.startsWith(u8, long_prefix, text.text[0..@min(text.text.len, long_prefix.len)]));
}
