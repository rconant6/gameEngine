//! Phase 4B — InputTrigger phases (pressed / held / released).
//!
//! Drives InputTrigger.process() with hand-built input snapshots and asserts
//! which phase fires. A frame is simulated by clearFrameStates() +
//! updateState(key, down):
//!   pressed  = key goes down this frame  (just_pressed)
//!   held     = key was already down, still down
//!   released = key goes up this frame     (just_released)

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const InputTrigger = Action.InputTrigger;
const OnInput = Action.OnInput;
const ActionQueue = Action.ActionQueue;
const TriggerContext = Action.TriggerContext;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

const platform = @import("platform");
const Input = platform.Input;
const Keyboard = platform.Keyboard;
const Mouse = platform.Mouse;
const KeyCode = platform.KeyCode;

// A placeholder action handle — these tests assert on FIRING (did the trigger
// queue an action this frame), not on what the action does.
fn placeholder() Action.Action {
    return .{ .id = 0, .params = null, .priority = 0 };
}

const InputHarness = struct {
    keyboard: Keyboard = .{},
    mouse: Mouse = undefined, // key-only tests never read the mouse
    input: Input = undefined,

    fn init(self: *InputHarness) void {
        self.keyboard = .{};
        self.mouse = std.mem.zeroes(Mouse);
        self.input = .{ .keyboard = &self.keyboard, .mouse = &self.mouse };
    }
    // advance one frame: clear edge state, then set the key's down/up
    fn frame(self: *InputHarness, key: KeyCode, down: bool) void {
        self.keyboard.clearFrameStates();
        self.keyboard.updateState(key, down);
    }
};

/// Run process against `harness`, return how many actions were queued this frame.
fn fireCount(world: *World, harness: *const InputHarness) !usize {
    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    const ctx = TriggerContext{ .input = &harness.input, .action_queue = &queue };
    try InputTrigger.process(world, ctx);
    return queue.actions.items.len;
}

fn addTrigger(world: *World, ent: Entity, key: KeyCode, phase: InputTrigger.Phase) !void {
    const actions = try testing.allocator.alloc(Action.Action, 1);
    actions[0] = placeholder();
    const triggers = try testing.allocator.alloc(InputTrigger, 1);
    triggers[0] = .{ .input = .{ .key = key }, .phase = phase, .actions = actions };
    try world.addComponent(ent, OnInput, .{ .triggers = triggers });
}

// MARK: pressed

test "phase=pressed fires only on the down edge, not while held" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTrigger(&world, e, .Space, .pressed);

    var h: InputHarness = undefined;
    h.init();

    // frame 1: key goes down → pressed fires
    h.frame(.Space, true);
    try testing.expectEqual(@as(usize, 1), try fireCount(&world, &h));

    // frame 2: key still down (held) → pressed does NOT fire
    h.frame(.Space, true);
    try testing.expectEqual(@as(usize, 0), try fireCount(&world, &h));
}

// MARK: held

test "phase=held fires every frame the key is down" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTrigger(&world, e, .W, .held);

    var h: InputHarness = undefined;
    h.init();

    h.frame(.W, true); // down edge — held counts it (isDown true)
    try testing.expectEqual(@as(usize, 1), try fireCount(&world, &h));

    h.frame(.W, true); // still down → fires again
    try testing.expectEqual(@as(usize, 1), try fireCount(&world, &h));

    h.frame(.W, false); // released → no longer down → does not fire
    try testing.expectEqual(@as(usize, 0), try fireCount(&world, &h));
}

// MARK: released

test "phase=released fires only on the up edge" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTrigger(&world, e, .S, .released);

    var h: InputHarness = undefined;
    h.init();

    h.frame(.S, true); // down → released does NOT fire
    try testing.expectEqual(@as(usize, 0), try fireCount(&world, &h));

    h.frame(.S, false); // up edge → released fires once
    try testing.expectEqual(@as(usize, 1), try fireCount(&world, &h));

    h.frame(.S, false); // still up → does not fire again
    try testing.expectEqual(@as(usize, 0), try fireCount(&world, &h));
}

// MARK: default phase

test "phase defaults to pressed when omitted (edge-only firing)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();

    // construct a trigger WITHOUT setting phase → struct default .pressed
    const actions = try testing.allocator.alloc(Action.Action, 1);
    actions[0] = placeholder();
    const triggers = try testing.allocator.alloc(InputTrigger, 1);
    triggers[0] = .{ .input = .{ .key = .Space }, .actions = actions };
    try world.addComponent(e, OnInput, .{ .triggers = triggers });

    var h: InputHarness = undefined;
    h.init();

    h.frame(.Space, true);
    try testing.expectEqual(@as(usize, 1), try fireCount(&world, &h)); // edge fires
    h.frame(.Space, true);
    try testing.expectEqual(@as(usize, 0), try fireCount(&world, &h)); // held does not
}

// MARK: structural (kept from the old suite)

test "InputTrigger holds key/mouse input and its actions" {
    const actions = [_]Action.Action{placeholder()};
    const t = InputTrigger{ .input = .{ .key = .Space }, .actions = &actions };
    try testing.expectEqual(KeyCode.Space, t.input.key);
    try testing.expectEqual(@as(usize, 1), t.actions.len);
    try testing.expectEqual(InputTrigger.Phase.pressed, t.phase); // default
}
