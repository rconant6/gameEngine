//! Phase 4C — TimeTrigger / OnTimer.
//!
//! Drives the REAL Action.TimeTrigger.process() with dt frames and asserts
//! firing cadence: accumulate across frames, fire at the interval, one-shot vs
//! repeat, and the MAX_CATCHUP cap after a long frame.
//!
//! (Replaces the old phantom suite, which tested a local TimeTrigger copy.)

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const TimeTrigger = Action.TimeTrigger;
const OnTimer = Action.OnTimer;
const ActionQueue = Action.ActionQueue;
const TriggerContext = Action.TriggerContext;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

// placeholder handle — tests assert on FIRING count, not action behavior
fn placeholder() Action.Action {
    return .{ .id = 0, .params = null, .priority = 0 };
}

/// Add an OnTimer with one trigger of the given interval/repeat to `ent`.
fn addTimer(world: *World, ent: Entity, interval: f32, repeat: bool) !void {
    const actions = try testing.allocator.alloc(Action.Action, 1);
    actions[0] = placeholder();
    const triggers = try testing.allocator.alloc(TimeTrigger, 1);
    triggers[0] = .{ .interval = interval, .repeat = repeat, .actions = actions };
    try world.addComponent(ent, OnTimer, .{ .triggers = triggers });
}

/// Advance one frame by `dt`, return how many actions fired this frame.
fn tick(world: *World, dt: f32) !usize {
    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    const ctx = TriggerContext{ .delta_time = dt, .action_queue = &queue };
    try TimeTrigger.process(world, ctx);
    return queue.actions.items.len;
}

// MARK: accumulation

test "repeat timer accumulates across frames and fires at the interval" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTimer(&world, e, 1.0, true);

    // 0.4 + 0.4 = 0.8 < 1.0 → no fire yet
    try testing.expectEqual(@as(usize, 0), try tick(&world, 0.4));
    try testing.expectEqual(@as(usize, 0), try tick(&world, 0.4));
    // +0.4 = 1.2 ≥ 1.0 → fires once, 0.2 carries over
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.4));
    // 0.2 + 0.4 = 0.6 < 1.0 → no fire
    try testing.expectEqual(@as(usize, 0), try tick(&world, 0.4));
}

test "repeat timer keeps firing every interval" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTimer(&world, e, 0.5, true);

    // each tick of exactly the interval fires once
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.5));
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.5));
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.5));
}

// MARK: one-shot

test "one-shot timer fires once then never again" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTimer(&world, e, 1.0, false);

    try testing.expectEqual(@as(usize, 0), try tick(&world, 0.5)); // not yet
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.6)); // 1.1 ≥ 1.0 → fires
    // stays fired: no more fires regardless of further time
    try testing.expectEqual(@as(usize, 0), try tick(&world, 5.0));
    try testing.expectEqual(@as(usize, 0), try tick(&world, 5.0));
}

// MARK: catch-up cap

test "a long frame fires multiple times, capped at MAX_CATCHUP" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();
    try addTimer(&world, e, 0.1, true);

    // dt of 1.0 with interval 0.1 = 10 intervals, but MAX_CATCHUP caps at 4
    try testing.expectEqual(@as(usize, 4), try tick(&world, 1.0));
}

// MARK: multiple triggers / entities

test "multiple timers on one entity fire independently" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
    const e = try world.createEntity();

    const actions_a = try testing.allocator.alloc(Action.Action, 1);
    actions_a[0] = placeholder();
    const actions_b = try testing.allocator.alloc(Action.Action, 1);
    actions_b[0] = placeholder();
    const triggers = try testing.allocator.alloc(TimeTrigger, 2);
    triggers[0] = .{ .interval = 0.5, .repeat = true, .actions = actions_a };
    triggers[1] = .{ .interval = 1.0, .repeat = true, .actions = actions_b };
    try world.addComponent(e, OnTimer, .{ .triggers = triggers });

    // 0.5: only the first fires
    try testing.expectEqual(@as(usize, 1), try tick(&world, 0.5));
    // +0.5 = 1.0 total: first fires again AND second fires → 2
    try testing.expectEqual(@as(usize, 2), try tick(&world, 0.5));
}

// MARK: structural

test "TimeTrigger field defaults: repeat false, elapsed 0, fired false" {
    const actions = [_]Action.Action{placeholder()};
    const t = TimeTrigger{ .interval = 2.0, .actions = &actions };
    try testing.expectEqual(@as(f32, 2.0), t.interval);
    try testing.expect(!t.repeat); // one-shot by default
    try testing.expectEqual(@as(f32, 0.0), t.elapsed);
    try testing.expect(!t.fired);
}
