//! Phase F1 — OnCollisionEnter: edge-triggered collision actions.
//!
//! Red-first. These target a `phase` field on CollisionTrigger that does NOT
//! exist yet (compile-red), plus the enter/stay firing semantics (behavior-red):
//!   - CollisionTrigger.Phase = enum { enter, stay }
//!   - phase: Phase = .enter   (default; multi-fire is the surprising one)
//!   - per-trigger contact set: an `enter` trigger fires once per contact, not
//!     every overlapping frame; `stay` keeps the old per-frame behavior.
//!
//! The bug this kills: brickles' gutter OnCollision (add_state_int{balls,-1} +
//! transition_state) fired ~11x per ball-crossing because actions fired every
//! overlapping frame. `enter` makes "do X once when these touch" expressible.
//!
//! Harness model (mirrors test_reflect_velocity's trigger half):
//!   - hand-roll an OnCollision component (heap actions + triggers, literal
//!     pattern, pattern_owned=false);
//!   - feed Collision events through TriggerContext + a fresh ActionQueue;
//!   - drive process() once per "frame", clearing the queue between frames
//!     (the queue is per-frame; the trigger's contact state persists on the
//!     component across frames);
//!   - assert how many actions landed in the queue.

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const ActionQueue = Action.ActionQueue;
const CollisionTrigger = Action.CollisionTrigger;
const OnCollision = Action.OnCollision;
const TriggerContext = Action.TriggerContext;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Tag = ecs.Tag;
const Collision = ecs.Collision;

const math = @import("math");
const V2 = math.V2;

// Add an OnCollision to `ent`: one trigger matching `pattern`, with `n_actions`
// placeholder actions, at the given phase. Actions/triggers are heap-owned so the
// component's deinit (run on world.deinit) frees them cleanly.
fn addCollisionTrigger(
    world: *World,
    ent: Entity,
    pattern: []const u8,
    phase: CollisionTrigger.Phase,
    n_actions: usize,
) !void {
    const actions = try testing.allocator.alloc(Action.Action, n_actions);
    for (actions) |*a| a.* = .{ .id = 0, .params = null, .priority = 0 };
    const triggers = try testing.allocator.alloc(CollisionTrigger, 1);
    triggers[0] = .{
        .other_tag_pattern = pattern,
        .actions = actions,
        .phase = phase,
    };
    try world.addComponent(ent, OnCollision, .{ .triggers = triggers });
}

fn mkCollision(a: Entity, b: Entity) Collision {
    return .{
        .entity_a = a,
        .entity_b = b,
        .point = V2.ZERO,
        .normal = .{ .x = 0, .y = 1 },
        .penetration = 0.1,
    };
}

// Run one "frame": fresh queue, feed the given events, return how many actions
// were queued. The trigger's contact state lives on the component and survives
// across calls — which is the whole point.
fn frame(world: *World, events: []const Collision) !usize {
    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    const tctx = TriggerContext{
        .collision_events = events,
        .action_queue = &queue,
    };
    try CollisionTrigger.process(world, tctx);
    return queue.actions.items.len;
}

// MARK: enter — fire once per contact

test "enter fires exactly once while two entities keep overlapping" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 1);
    const ball = try world.createEntity();
    try world.addComponent(ball, Tag, Tag.init("ball"));

    const ev = [_]Collision{mkCollision(self, ball)};

    // 3 frames of continuous overlap → action queues on frame 1 only.
    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev));
    try testing.expectEqual(@as(usize, 0), try frame(&world, &ev));
    try testing.expectEqual(@as(usize, 0), try frame(&world, &ev));
}

test "enter re-fires after the pair separates and touches again" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 1);
    const ball = try world.createEntity();
    try world.addComponent(ball, Tag, Tag.init("ball"));

    const ev = [_]Collision{mkCollision(self, ball)};
    const none = [_]Collision{};

    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev)); // enter
    try testing.expectEqual(@as(usize, 0), try frame(&world, &ev)); // still touching
    try testing.expectEqual(@as(usize, 0), try frame(&world, &none)); // separated
    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev)); // re-enter
}

test "enter queues every action on the trigger, once" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 3); // 3 actions
    const ball = try world.createEntity();
    try world.addComponent(ball, Tag, Tag.init("ball"));

    const ev = [_]Collision{mkCollision(self, ball)};
    try testing.expectEqual(@as(usize, 3), try frame(&world, &ev)); // all 3 on enter
    try testing.expectEqual(@as(usize, 0), try frame(&world, &ev)); // none after
}

// MARK: stay — fire every overlapping frame (the bounce case)

test "stay fires every frame the pair overlaps" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .stay, 1);
    const ball = try world.createEntity();
    try world.addComponent(ball, Tag, Tag.init("ball"));

    const ev = [_]Collision{mkCollision(self, ball)};
    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev));
    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev));
    try testing.expectEqual(@as(usize, 1), try frame(&world, &ev));
}

// MARK: per-other tracking

test "two distinct others each fire their own enter; neither re-fires" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 1);
    const ball_a = try world.createEntity();
    try world.addComponent(ball_a, Tag, Tag.init("ball"));
    const ball_b = try world.createEntity();
    try world.addComponent(ball_b, Tag, Tag.init("ball"));

    // both touch this frame → two enters (one per distinct other entity)
    const both = [_]Collision{ mkCollision(self, ball_a), mkCollision(self, ball_b) };
    try testing.expectEqual(@as(usize, 2), try frame(&world, &both));

    // still touching both next frame → zero (both already contacting)
    try testing.expectEqual(@as(usize, 0), try frame(&world, &both));

    // only A keeps touching → still zero (A was already in the set)
    const only_a = [_]Collision{mkCollision(self, ball_a)};
    try testing.expectEqual(@as(usize, 0), try frame(&world, &only_a));

    // B comes back after having dropped out → one fresh enter for B
    const both_again = [_]Collision{ mkCollision(self, ball_a), mkCollision(self, ball_b) };
    try testing.expectEqual(@as(usize, 1), try frame(&world, &both_again));
}

// MARK: robustness

test "a destroyed other does not wedge the contact set" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 1);
    const ball = try world.createEntity();
    try world.addComponent(ball, Tag, Tag.init("ball"));

    try testing.expectEqual(@as(usize, 1), try frame(&world, &[_]Collision{mkCollision(self, ball)}));

    // destroy the other; a frame with no events must clear it from the set
    world.destroyEntity(ball);
    try testing.expectEqual(@as(usize, 0), try frame(&world, &[_]Collision{}));

    // a new other (may recycle ball's id) touching now is a fresh enter
    const ball2 = try world.createEntity();
    try world.addComponent(ball2, Tag, Tag.init("ball"));
    try testing.expectEqual(@as(usize, 1), try frame(&world, &[_]Collision{mkCollision(self, ball2)}));
}

test "more simultaneous contacts than MAX_CONTACTS degrades safe (fires, no crash)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const self = try world.createEntity();
    try addCollisionTrigger(&world, self, "ball", .enter, 1);

    // 12 distinct others touch in one frame (MAX_CONTACTS is 8). Overflow policy
    // is "fire rather than silently drop" — so at least the first 8 fire and the
    // overflow ones still fire (degrade to stay), never panic or OOB.
    var others: [12]Entity = undefined;
    var evs: [12]Collision = undefined;
    for (&others, 0..) |*o, i| {
        o.* = try world.createEntity();
        try world.addComponent(o.*, Tag, Tag.init("ball"));
        evs[i] = mkCollision(self, o.*);
    }
    const fired = try frame(&world, &evs);
    try testing.expect(fired >= 8); // no hit silently dropped; no crash
}
