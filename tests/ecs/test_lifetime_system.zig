//! Phase 2C — LifetimeSys collect-then-destroy.
//!
//! Bug: cleanup() destroys entities WHILE iterating the Destroy storage. Each
//! destroyEntity does a swap-remove that moves the last dense element into the
//! just-visited slot, but the query cursor already advanced past it — so with
//! two or more doomed entities in one frame, one survives until the next frame.
//!
//! These tests target the FIXED signature: run(world, dt, frame). They will not
//! compile against the current run(world, dt) — that mismatch is the red.
//!
//! Fix shape (from the readiness plan): collect doomed entities into a
//! frame-allocated list first, THEN destroy them after iteration completes.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Lifetime = ecs.Lifetime;
const Destroy = ecs.Destroy;

const systems = @import("systems");
const lifetimeSystem = systems.lifetimeSystem;

const eps = 0.0001;

fn spawn(world: *World, remaining: f32) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = .{ .x = 0, .y = 0 }, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Lifetime, .{ .remaining = remaining });
    return e;
}

// MARK: decrement / expiry

test "lifetime decrements by dt without expiring" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try spawn(&world, 1.0);
    lifetimeSystem(&world, 0.25, testing.allocator);

    try testing.expect(world.hasComponent(e, Lifetime));
    const lt = world.getComponent(e, Lifetime).?;
    try testing.expectApproxEqAbs(@as(f32, 0.75), lt.remaining, eps);
    try testing.expect(!world.hasComponent(e, Destroy));
}

test "an entity reaching zero lifetime is destroyed in the same frame" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try spawn(&world, 0.1);
    lifetimeSystem(&world, 0.2, testing.allocator); // overshoots zero

    // destroyed → its components are gone
    try testing.expect(!world.hasComponent(e, Lifetime));
    try testing.expect(!world.hasComponent(e, Transform));
}

test "exactly zero remaining counts as expired" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try spawn(&world, 0.5);
    lifetimeSystem(&world, 0.5, testing.allocator); // remaining hits exactly 0.0

    try testing.expect(!world.hasComponent(e, Lifetime)); // <= 0 destroys
}

// MARK: the bug — multiple expiries in one frame

test "all expired entities are destroyed in one frame (collect-then-destroy)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // three entities all expire this frame. With destroy-during-iteration,
    // swap-remove skips at least one, leaving it alive.
    const a = try spawn(&world, 0.1);
    const b = try spawn(&world, 0.1);
    const c = try spawn(&world, 0.1);

    lifetimeSystem(&world, 1.0, testing.allocator);

    try testing.expect(!world.hasComponent(a, Lifetime));
    try testing.expect(!world.hasComponent(b, Lifetime));
    try testing.expect(!world.hasComponent(c, Lifetime)); // the one the bug leaves behind
}

test "expired entities die while survivors keep ticking, single frame" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // interleave doomed and surviving entities so a swap-remove skip would be
    // observable as a survivor that should have died (or vice versa).
    const doomed1 = try spawn(&world, 0.1);
    const alive1 = try spawn(&world, 5.0);
    const doomed2 = try spawn(&world, 0.1);
    const alive2 = try spawn(&world, 5.0);
    const doomed3 = try spawn(&world, 0.1);

    lifetimeSystem(&world, 1.0, testing.allocator);

    // all short-lived ones gone
    try testing.expect(!world.hasComponent(doomed1, Lifetime));
    try testing.expect(!world.hasComponent(doomed2, Lifetime));
    try testing.expect(!world.hasComponent(doomed3, Lifetime));

    // long-lived ones survive with decremented timers
    try testing.expect(world.hasComponent(alive1, Lifetime));
    try testing.expect(world.hasComponent(alive2, Lifetime));
    try testing.expectApproxEqAbs(@as(f32, 4.0), world.getComponent(alive1, Lifetime).?.remaining, eps);
    try testing.expectApproxEqAbs(@as(f32, 4.0), world.getComponent(alive2, Lifetime).?.remaining, eps);
}

test "running with no entities and no expiries is a safe no-op" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    lifetimeSystem(&world, 0.016, testing.allocator); // empty world

    const survivor = try spawn(&world, 2.0);
    lifetimeSystem(&world, 0.016, testing.allocator); // nothing expires
    try testing.expect(world.hasComponent(survivor, Lifetime));
}
