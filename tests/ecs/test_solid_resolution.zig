//! Phase F2 — solid colliders: "this wall is solid" blocks movement.
//!
//! Red-first. Targets API that does NOT exist yet:
//!   - Collider gains `solid: bool = false`        (src/ecs/Components.zig)
//!   - systems.solidResolutionSystem(world, events) (src/systems/SolidResolutionSys.zig)
//!
//! Behavior: after collision DETECTION (which only reports events), a resolution
//! pass walks the events; for any pair where exactly ONE side is solid, it pushes
//! the NON-solid entity out along the collision normal by the penetration depth.
//! This is bounce's separation half, minus the velocity flip — reused as an
//! automatic property of the collider instead of a wired action. It replaces the
//! hand-rolled clampPaddleVelocity in pong/brickles.
//!
//! The resolver takes the events as INPUT (we hand-build them here — no real
//! detection needed) and asserts Transform positions after run.
//!
//! Detection convention (load-bearing): Collision.normal is ALWAYS entity_a -> b.
//! To push the non-solid mover OUT of the solid surface:
//!   - if B is solid (A is mover): push A along -normal
//!   - if A is solid (B is mover): push B along +normal
//! A sign error pushes the mover INTO the wall — tests 1 & 2 catch it.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Collider = ecs.Collider;
const ColliderData = ecs.ColliderData;
const Collision = ecs.Collision;

const math = @import("math");
const V2 = math.V2;

const systems = @import("systems");
const solidResolutionSystem = systems.solidResolutionSystem;

const eps = 0.01;

// Spawn an entity with a Transform at (x,y) and a circle collider; `solid` flags
// whether it blocks. Returns the entity.
fn spawn(world: *World, x: f32, y: f32, solid: bool) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = .{ .x = x, .y = y }, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Collider, .{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 1.0 } },
        .solid = solid,
    });
    return e;
}

fn posOf(world: *World, e: Entity) V2 {
    return world.getComponent(e, Transform).?.position;
}

fn mkCollision(a: Entity, b: Entity, normal: V2, pen: f32) Collision {
    return .{ .entity_a = a, .entity_b = b, .point = V2.ZERO, .normal = normal, .penetration = pen };
}

// MARK: the mover gets pushed out of a solid surface

test "non-solid mover is pushed out of a solid wall (B solid)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // mover A at origin overlapping solid wall B; normal A->B is +x, pen 0.5.
    const mover = try spawn(&world, 0, 0, false);
    const wall = try spawn(&world, 0.6, 0, true);

    const events = [_]Collision{mkCollision(mover, wall, .{ .x = 1, .y = 0 }, 0.5)};
    solidResolutionSystem(&world, &events);

    // mover pushed along -normal (away from the wall) by ~penetration → x ≈ -0.5
    try testing.expectApproxEqAbs(@as(f32, -0.5), posOf(&world, mover).x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, mover).y, eps);
    // wall (solid) did not move
    try testing.expectApproxEqAbs(@as(f32, 0.6), posOf(&world, wall).x, eps);
}

test "non-solid mover is pushed out of a solid wall (A solid) — opposite direction" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // wall A is solid at origin; mover B overlaps it; normal A->B is +x, pen 0.5.
    const wall = try spawn(&world, 0, 0, true);
    const mover = try spawn(&world, 0.6, 0, false);

    const events = [_]Collision{mkCollision(wall, mover, .{ .x = 1, .y = 0 }, 0.5)};
    solidResolutionSystem(&world, &events);

    // mover pushed along +normal (away from the wall) by ~penetration → x ≈ 1.1
    try testing.expectApproxEqAbs(@as(f32, 1.1), posOf(&world, mover).x, eps);
    // wall (solid) did not move
    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, wall).x, eps);
}

test "push distance is the penetration depth (not a teleport)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const mover = try spawn(&world, 0, 0, false);
    const wall = try spawn(&world, 0, 0.3, true);

    // normal +y, deep penetration 0.8 → mover pushed to y ≈ -0.8 (just clear)
    const events = [_]Collision{mkCollision(mover, wall, .{ .x = 0, .y = 1 }, 0.8)};
    solidResolutionSystem(&world, &events);

    try testing.expectApproxEqAbs(@as(f32, -0.8), posOf(&world, mover).y, eps);
}

// MARK: no resolution unless exactly one side is solid

test "two non-solid entities: nothing moves" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const a = try spawn(&world, 0, 0, false);
    const b = try spawn(&world, 0.6, 0, false);

    const events = [_]Collision{mkCollision(a, b, .{ .x = 1, .y = 0 }, 0.5)};
    solidResolutionSystem(&world, &events);

    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, a).x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.6), posOf(&world, b).x, eps);
}

test "two solid entities: nothing moves (can't push a wall through a wall)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const a = try spawn(&world, 0, 0, true);
    const b = try spawn(&world, 0.6, 0, true);

    const events = [_]Collision{mkCollision(a, b, .{ .x = 1, .y = 0 }, 0.5)};
    solidResolutionSystem(&world, &events);

    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, a).x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.6), posOf(&world, b).x, eps);
}

// MARK: robustness

test "a solid pair where the mover has no Transform is a safe no-op" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // mover: collider but NO Transform
    const mover = try world.createEntity();
    try world.addComponent(mover, Collider, .{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 1.0 } },
        .solid = false,
    });
    const wall = try spawn(&world, 0.6, 0, true);

    const events = [_]Collision{mkCollision(mover, wall, .{ .x = 1, .y = 0 }, 0.5)};
    solidResolutionSystem(&world, &events); // must not crash

    // wall untouched
    try testing.expectApproxEqAbs(@as(f32, 0.6), posOf(&world, wall).x, eps);
}

test "empty event list is a safe no-op" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const a = try spawn(&world, 0, 0, false);
    const wall = try spawn(&world, 0.6, 0, true);

    solidResolutionSystem(&world, &[_]Collision{});

    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, a).x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.6), posOf(&world, wall).x, eps);
}
