//! Phase 7C — entity generations + ID recycling.
//!
//! Red-first: these target API that does NOT exist yet and will fail to compile
//! / fail assertions until 7C lands:
//!   - Entity gains `gen: u32 = 0`            (src/ecs/Entity.zig)
//!   - World.isAlive(entity) -> bool          (src/ecs/World.zig)
//!   - createEntity recycles freed ids, bumping gen
//!   - destroyEntity guards on isAlive, bumps generation, frees the id
//!   - getComponent/getComponentMut/hasComponent reject stale handles
//!   - Query stamps the live generation on Entry.entity (decision 3a)
//!
//! The bug this prevents: ids grow forever and stale handles silently alias
//! whatever later reused the slot. With generations, a handle to a destroyed
//! entity reads as "has nothing", never as the recycled occupant.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

const Position = struct { x: f32, y: f32 };
const Health = struct { hp: i32 };

// MARK: liveness basics

test "a freshly created entity is alive" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try world.createEntity();
    try testing.expect(world.isAlive(e));
}

test "a destroyed entity is no longer alive" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try world.createEntity();
    world.destroyEntity(e);
    try testing.expect(!world.isAlive(e));
}

test "the invalid/sentinel entity (id 0) is never alive" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    try testing.expect(!world.isAlive(Entity{ .id = 0 }));
}

// MARK: id recycling + generation bump

test "destroying then creating reuses the id with a bumped generation" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const first = try world.createEntity();
    world.destroyEntity(first);

    const second = try world.createEntity();
    // same slot recycled...
    try testing.expectEqual(first.id, second.id);
    // ...but a newer generation, so the two handles are distinguishable
    try testing.expect(second.gen != first.gen);
    try testing.expect(world.isAlive(second));
    try testing.expect(!world.isAlive(first)); // the old handle stays dead
}

test "ids are only recycled after a destroy, otherwise they grow" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const a = try world.createEntity();
    const b = try world.createEntity();
    try testing.expect(a.id != b.id); // no destroy yet → distinct ids
    try testing.expect(a.gen == 0 and b.gen == 0);
}

// MARK: the core protection — stale handles alias nothing

test "a stale handle reads no components even after its slot is recycled" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const old = try world.createEntity();
    try world.addComponent(old, Health, .{ .hp = 100 });
    try testing.expect(world.hasComponent(old, Health));

    world.destroyEntity(old);

    // recycle the slot with a different occupant
    const new = try world.createEntity();
    try testing.expectEqual(old.id, new.id); // same underlying slot
    try world.addComponent(new, Health, .{ .hp = 5 });

    // the stale handle must NOT see the new entity's component
    try testing.expect(!world.hasComponent(old, Health));
    try testing.expect(world.getComponent(old, Health) == null);
    try testing.expect(world.getComponentMut(old, Health) == null);

    // the live handle sees its own
    const h = world.getComponent(new, Health) orelse return error.MissingComponent;
    try testing.expectEqual(@as(i32, 5), h.hp);
}

test "destroyEntity on a stale handle is a no-op, not corruption" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const old = try world.createEntity();
    world.destroyEntity(old);

    const new = try world.createEntity(); // recycles old.id, gen bumped
    try world.addComponent(new, Health, .{ .hp = 7 });

    world.destroyEntity(old); // stale: must not touch `new`
    try testing.expect(world.isAlive(new));
    const h = world.getComponent(new, Health) orelse return error.MissingComponent;
    try testing.expectEqual(@as(i32, 7), h.hp);

    world.destroyEntity(old); // double-destroy of a stale handle: still safe
    try testing.expect(world.isAlive(new));
}

// MARK: query round-trip (decision 3a — query stamps the live generation)

test "an entity handed back by a query passes isAlive" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // force a recycle so the live slot's generation is non-zero — a query that
    // stamped gen 0 would fail isAlive here.
    const throwaway = try world.createEntity();
    world.destroyEntity(throwaway);

    const e = try world.createEntity();
    try world.addComponent(e, Position, .{ .x = 1, .y = 2 });
    try world.addComponent(e, Health, .{ .hp = 50 });

    var q = world.query(.{ Position, Health });
    var seen: usize = 0;
    while (q.next()) |entry| {
        seen += 1;
        try testing.expect(world.isAlive(entry.entity)); // handle is self-certifying
        try testing.expectEqual(e.id, entry.entity.id);
        try testing.expectEqual(e.gen, entry.entity.gen); // stamped with the live gen
    }
    try testing.expectEqual(@as(usize, 1), seen);
}

// MARK: bulk teardown still clears despite the generation guard

test "destroyAllExcept clears every entity but the kept one, across recycles" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // advance some generations first so the internal id-sweep can't rely on gen 0
    const tmp = try world.createEntity();
    world.destroyEntity(tmp);

    const keep = try world.createEntity();
    const a = try world.createEntity();
    const b = try world.createEntity();
    try world.addComponent(keep, Health, .{ .hp = 1 });
    try world.addComponent(a, Health, .{ .hp = 2 });
    try world.addComponent(b, Health, .{ .hp = 3 });

    world.destroyAllExcept(keep);

    try testing.expect(world.isAlive(keep));
    try testing.expect(world.hasComponent(keep, Health));
    try testing.expect(!world.isAlive(a));
    try testing.expect(!world.isAlive(b));
    try testing.expect(!world.hasComponent(a, Health));
    try testing.expect(!world.hasComponent(b, Health));
}

// MARK: free-list integrity — the tight cases the first sweep test missed
//
// The bug: destroyAllExcept / deinit iterate raw ids 0..next_entity_id. A slot
// that was destroyed-but-not-recycled is dead, yet a synthesized handle carrying
// the slot's CURRENT generation passes isAlive — so the sweep destroys it a
// SECOND time, bumping gen again and appending the id to free_ids twice. A
// double-entry in free_ids means createEntity later hands the same id to two
// live entities, which then alias one component slot. These tests force that
// shape and assert it can't happen.

// No id is ever handed to two live entities at once — the core invariant.
fn assertNoLiveIdAliases(world: *World, fresh: []const Entity) !void {
    for (fresh, 0..) |e, i| {
        try testing.expect(world.isAlive(e));
        for (fresh[i + 1 ..]) |other| {
            try testing.expect(e.id != other.id); // distinct slots for distinct live entities
        }
    }
}

test "destroyAllExcept does not double-free an already-destroyed slot" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const keep = try world.createEntity();
    const a = try world.createEntity();
    const b = try world.createEntity();
    const c = try world.createEntity();

    // b is destroyed but NOT recycled — its id sits in the free list while the
    // sweep is about to walk over it.
    world.destroyEntity(b);

    world.destroyAllExcept(keep);

    // a and c are gone; b stays gone; keep survives.
    try testing.expect(world.isAlive(keep));
    try testing.expect(!world.isAlive(a));
    try testing.expect(!world.isAlive(b));
    try testing.expect(!world.isAlive(c));

    // The real test: allocate a fresh batch. If b's id was double-appended to the
    // free list, two of these would collide on the same id.
    var fresh: [4]Entity = undefined;
    for (&fresh) |*slot| slot.* = try world.createEntity();
    try assertNoLiveIdAliases(&world, &fresh);
}

test "repeated destroyAllExcept cycles never corrupt the free list" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const camera = try world.createEntity(); // the "keep" across all cycles

    // Simulate several game restarts: spawn a batch, destroy a couple by hand
    // (leaving them in the free list), then clear-all-except-camera.
    var cycle: usize = 0;
    while (cycle < 5) : (cycle += 1) {
        var batch: [6]Entity = undefined;
        for (&batch) |*slot| slot.* = try world.createEntity();

        // hand-destroy two mid-batch so the sweep meets free-list members
        world.destroyEntity(batch[1]);
        world.destroyEntity(batch[4]);

        world.destroyAllExcept(camera);

        // camera is the only survivor every cycle
        try testing.expect(world.isAlive(camera));
        for (batch) |e| try testing.expect(!world.isAlive(e));
    }

    // After all the churn, a fresh allocation must still yield unique live ids.
    var fresh: [8]Entity = undefined;
    for (&fresh) |*slot| slot.* = try world.createEntity();
    try assertNoLiveIdAliases(&world, &fresh);
    try testing.expect(world.isAlive(camera)); // never swept away
}

test "destroying an already-destroyed slot by fresh handle is rejected" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try world.createEntity();
    world.destroyEntity(e); // id now free, gen bumped

    // A caller who reconstructs a handle with the slot's *current* generation
    // (the exact thing the sweep used to do) must not be able to re-destroy a
    // free slot and double-append it.
    const free_before = world.free_ids.items.len;
    world.destroyEntity(.{ .id = e.id, .gen = world.generations.items[e.id] });
    const free_after = world.free_ids.items.len;
    try testing.expectEqual(free_before, free_after); // no second append

    // and the slot still cleanly recycles exactly once
    const reused = try world.createEntity();
    try testing.expectEqual(e.id, reused.id);
    const other = try world.createEntity();
    try testing.expect(other.id != reused.id);
}

test "components are gone after a sweep even for recycled-then-rebuilt slots" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const keep = try world.createEntity();
    try world.addComponent(keep, Health, .{ .hp = 99 });

    // build up generation churn on the non-keep slots
    const x = try world.createEntity();
    world.destroyEntity(x);
    const y = try world.createEntity(); // recycles x's slot, gen >= 1
    try world.addComponent(y, Position, .{ .x = 1, .y = 1 });
    try world.addComponent(y, Health, .{ .hp = 12 });

    world.destroyAllExcept(keep);

    // y's slot (a recycled, non-zero-gen slot) must be fully cleared, not skipped
    try testing.expect(!world.isAlive(y));
    try testing.expect(!world.hasComponent(y, Health));
    try testing.expect(!world.hasComponent(y, Position));

    // keep is untouched
    try testing.expect(world.isAlive(keep));
    try testing.expectEqual(@as(i32, 99), (world.getComponent(keep, Health).?).hp);

    // Probe storage WITHOUT the isAlive guard: a query walks live dense storage
    // directly. If the sweep merely hid y behind the gen check but left its
    // component data in storage, the query would still surface that phantom
    // Position. Only `keep` has Health, and nothing else should have Position.
    var pos_seen: usize = 0;
    var pq = world.query(.{Position});
    while (pq.next()) |_| pos_seen += 1;
    try testing.expectEqual(@as(usize, 0), pos_seen); // y's Position truly gone from storage

    var health_seen: usize = 0;
    var hq = world.query(.{Health});
    while (hq.next()) |entry| {
        health_seen += 1;
        try testing.expectEqual(keep.id, entry.entity.id); // only keep remains
    }
    try testing.expectEqual(@as(usize, 1), health_seen);

    // And the definitive leak check: recycle y's slot. If y's components leaked
    // in storage, the recycled occupant at the same id would inherit them.
    const reborn = try world.createEntity();
    try testing.expect(!world.hasComponent(reborn, Health));
    try testing.expect(!world.hasComponent(reborn, Position));
}

// MARK: additional edge cases

test "addComponent on a stale handle is rejected" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const old = try world.createEntity();
    world.destroyEntity(old);
    const new = try world.createEntity(); // recycles old.id

    // adding through the dead handle must not land on the live occupant
    world.addComponent(old, Health, .{ .hp = 1 }) catch {};
    try testing.expect(!world.hasComponent(new, Health));
    // and the live handle still works
    try world.addComponent(new, Health, .{ .hp = 2 });
    try testing.expectEqual(@as(i32, 2), (world.getComponent(new, Health).?).hp);
}

test "removeComponent on a stale handle does not touch the recycled occupant" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const old = try world.createEntity();
    world.destroyEntity(old);
    const new = try world.createEntity(); // same slot
    try world.addComponent(new, Health, .{ .hp = 5 });

    world.removeComponent(old, Health); // stale: must be a no-op
    try testing.expect(world.hasComponent(new, Health));
}

test "multiple destroys recycle every id without loss or duplication" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // create a known batch
    var batch: [5]Entity = undefined;
    for (&batch) |*slot| slot.* = try world.createEntity();
    var original_ids: [5]usize = undefined;
    for (batch, 0..) |e, i| original_ids[i] = e.id;

    // destroy all of them (LIFO into the free list)
    for (batch) |e| world.destroyEntity(e);

    // recreate the same count — every id must come back exactly once, all live,
    // all distinct, and all drawn from the freed set (no growth, no loss).
    var reborn: [5]Entity = undefined;
    for (&reborn) |*slot| slot.* = try world.createEntity();
    try assertNoLiveIdAliases(&world, &reborn);
    for (reborn) |e| {
        var found = false;
        for (original_ids) |oid| {
            if (e.id == oid) found = true;
        }
        try testing.expect(found); // recycled, not a brand-new id
    }
}

test "destroyAllExcept keeps an entity whose own slot was recycled (non-zero gen)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // make the entity we keep live on a recycled, non-zero-gen slot
    const throwaway = try world.createEntity();
    world.destroyEntity(throwaway);
    const keep = try world.createEntity(); // keep.gen >= 1, keep.id == throwaway.id
    try testing.expect(keep.gen != 0);
    try world.addComponent(keep, Health, .{ .hp = 42 });

    const other = try world.createEntity();
    try world.addComponent(other, Health, .{ .hp = 7 });

    world.destroyAllExcept(keep);

    try testing.expect(world.isAlive(keep)); // not swept despite non-zero gen
    try testing.expectEqual(@as(i32, 42), (world.getComponent(keep, Health).?).hp);
    try testing.expect(!world.isAlive(other));
}

test "sweeping an empty or already-swept world is a safe no-op" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const keep = try world.createEntity();

    world.destroyAllExcept(keep); // nothing else to clear
    try testing.expect(world.isAlive(keep));

    world.destroyAllExcept(keep); // again, idempotent
    try testing.expect(world.isAlive(keep));

    // fresh allocations afterward are still sound
    var fresh: [3]Entity = undefined;
    for (&fresh) |*slot| slot.* = try world.createEntity();
    try assertNoLiveIdAliases(&world, &fresh);
}

test "a recycled entity may re-add the component type its predecessor held" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const first = try world.createEntity();
    try world.addComponent(first, Health, .{ .hp = 1 });
    world.destroyEntity(first); // Health removed from the slot

    const second = try world.createEntity(); // same slot
    // must be able to add Health again — the slot's storage entry was cleared,
    // not left occupied (which would error ComponentAlreadyExists).
    try world.addComponent(second, Health, .{ .hp = 2 });
    try testing.expectEqual(@as(i32, 2), (world.getComponent(second, Health).?).hp);
}
