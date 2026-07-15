//! Physics Brain — forces (F=ma + damping) and collision RESPONSE (restitution).
//!
//! Sibling of test_solid_resolution: solid-resolution does separation only; the
//! physics response does the VELOCITY reflection too, plus mass-weighted split.
//!
//! Detection convention (load-bearing, same as solid-resolution): Collision.normal
//! is ALWAYS entity_a -> b. A moves INTO B when v_a·n > 0; B moves into A when
//! v_b·n < 0. A sign error reflects the body the WRONG way (ball tunnels through /
//! fights the surface) — tests here catch each direction. This file exists because
//! the first response impl inverted every sign (copied from the old `bounce` action
//! whose normal was oriented toward-self, opposite to A->B), and it compiled clean
//! and only showed in play. These lock the correct signs at `zig build test`.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Physics = ecs.Physics;
const Collision = ecs.Collision;

const math = @import("math");
const V2 = math.V2;

const systems = @import("systems");
const physics = systems.physicsSystem; // module: .forces(world, dt, gravity) / .response(world, events)

const eps = 0.001;

// A body with a Transform, Velocity, and Physics. mass 0 = static/immovable.
fn spawn(world: *World, pos: V2, vel: V2, mass: f32, restitution: f32) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = pos, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Velocity, .{ .linear = vel, .angular = 0 });
    try world.addComponent(e, Physics, .{ .mass = mass, .restitution = restitution });
    return e;
}

fn spawnGravity(world: *World, pos: V2, mass: f32, gravity_scale: f32) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = pos, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Velocity, .{ .linear = V2.ZERO, .angular = 0 });
    try world.addComponent(e, Physics, .{ .mass = mass, .gravity_scale = gravity_scale });
    return e;
}

fn velOf(world: *World, e: Entity) V2 {
    return world.getComponent(e, Velocity).?.linear;
}
fn posOf(world: *World, e: Entity) V2 {
    return world.getComponent(e, Transform).?.position;
}
fn mkCollision(a: Entity, b: Entity, normal: V2, pen: f32) Collision {
    return .{ .entity_a = a, .entity_b = b, .point = V2.ZERO, .normal = normal, .penetration = pen };
}

// MARK: collision response — velocity reflection (the sign-critical part)

test "ball moving INTO a static wall reflects away (A->B normal, d>0)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // ball A moving +y (up) into ceiling B; normal A->B = +y. v·n = +5 > 0 → reflect.
    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 3, .y = 5 }, 1.0, 1.0);
    const wall = try spawn(&world, .{ .x = 0, .y = 1 }, V2.ZERO, 0.0, 1.0);

    const events = [_]Collision{mkCollision(ball, wall, .{ .x = 0, .y = 1 }, 0.0)};
    physics.response(&world, &events);

    // v - (1+e)(v·n)n, v=(3,5), n=(0,1), e=1 → (3, -5): y flips, x untouched.
    const v = velOf(&world, ball);
    try testing.expectApproxEqAbs(@as(f32, 3.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -5.0), v.y, eps);
    // static wall velocity unchanged
    try testing.expectApproxEqAbs(@as(f32, 0.0), velOf(&world, wall).y, eps);
}

test "ball already moving AWAY from the wall is left alone (d<=0, no re-flip)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // ball A moving -y (down, away) while overlapping ceiling B (normal +y). v·n = -5 < 0.
    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 3, .y = -5 }, 1.0, 1.0);
    const wall = try spawn(&world, .{ .x = 0, .y = 1 }, V2.ZERO, 0.0, 1.0);

    const events = [_]Collision{mkCollision(ball, wall, .{ .x = 0, .y = 1 }, 0.0)};
    physics.response(&world, &events);

    // must NOT flip (already separating) — else the ball sticks/jitters on the surface.
    const v = velOf(&world, ball);
    try testing.expectApproxEqAbs(@as(f32, 3.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -5.0), v.y, eps);
}

test "restitution scales the bounce (product combine)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // ball e=0.5 into wall e=0.5 → combined 0.25. v·n=+10, reflected = v - (1+0.25)*10*n.
    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 10 }, 1.0, 0.5);
    const wall = try spawn(&world, .{ .x = 0, .y = 1 }, V2.ZERO, 0.0, 0.5);

    const events = [_]Collision{mkCollision(ball, wall, .{ .x = 0, .y = 1 }, 0.0)};
    physics.response(&world, &events);

    // vy: 10 - (1+0.25)*10 = 10 - 12.5 = -2.5 (bounces back at 25% speed)
    try testing.expectApproxEqAbs(@as(f32, -2.5), velOf(&world, ball).y, eps);
}

test "restitution 0 kills the normal velocity (no bounce)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 4, .y = 6 }, 1.0, 0.0);
    const wall = try spawn(&world, .{ .x = 0, .y = 1 }, V2.ZERO, 0.0, 0.0);

    const events = [_]Collision{mkCollision(ball, wall, .{ .x = 0, .y = 1 }, 0.0)};
    physics.response(&world, &events);

    // e=0: v -= (1+0)(v·n)n → normal component zeroed, tangential kept.
    const v = velOf(&world, ball);
    try testing.expectApproxEqAbs(@as(f32, 4.0), v.x, eps); // tangential kept
    try testing.expectApproxEqAbs(@as(f32, 0.0), v.y, eps); // normal killed
}

test "B is the dynamic body moving into static A (mirror sign, d<0)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // static wall A, dynamic ball B moving -y (toward A); normal A->B = +y, v_b·n = -5 < 0.
    const wall = try spawn(&world, .{ .x = 0, .y = 1 }, V2.ZERO, 0.0, 1.0);
    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 2, .y = -5 }, 1.0, 1.0);

    const events = [_]Collision{mkCollision(wall, ball, .{ .x = 0, .y = 1 }, 0.0)};
    physics.response(&world, &events);

    // B reflects: v - (1+1)(v·n)n = (2,-5) - 2*(-5)*(0,1) = (2, 5). (catches the
    // entity_a-instead-of-entity_b copy-paste in the B branch.)
    const v = velOf(&world, ball);
    try testing.expectApproxEqAbs(@as(f32, 2.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 5.0), v.y, eps);
}

// MARK: collision response — separation (dynamic pushed OUT, static stays)

test "separation pushes the dynamic body out along -n; static stays" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // ball A overlapping ceiling B by 0.5, normal A->B = +y → A pushed -y (down, out).
    const ball = try spawn(&world, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 3 }, 1.0, 1.0);
    const wall = try spawn(&world, .{ .x = 0, .y = 0.4 }, V2.ZERO, 0.0, 1.0);

    const events = [_]Collision{mkCollision(ball, wall, .{ .x = 0, .y = 1 }, 0.5)};
    physics.response(&world, &events);

    // dynamic ball pushed out by penetration (+eps) along -n → y ≈ -0.5
    try testing.expectApproxEqAbs(@as(f32, -0.5), posOf(&world, ball).y, 0.01);
    // static wall did not move
    try testing.expectApproxEqAbs(@as(f32, 0.4), posOf(&world, wall).y, eps);
}

test "two dynamic bodies split separation by inverse mass" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // equal-mass A and B overlapping by 0.6, normal A->B = +x. Each moves 0.3(+eps):
    // A along -x, B along +x.
    const a = try spawn(&world, .{ .x = 0, .y = 0 }, V2.ZERO, 1.0, 1.0);
    const b = try spawn(&world, .{ .x = 0.4, .y = 0 }, V2.ZERO, 1.0, 1.0);

    const events = [_]Collision{mkCollision(a, b, .{ .x = 1, .y = 0 }, 0.6)};
    physics.response(&world, &events);

    // half each (+ half the eps): A ≈ -0.3, B ≈ 0.7
    try testing.expectApproxEqAbs(@as(f32, -0.3), posOf(&world, a).x, 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.7), posOf(&world, b).x, 0.01);
}

test "both bodies static: nothing moves (inv_sum == 0 guard)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const a = try spawn(&world, .{ .x = 0, .y = 0 }, V2.ZERO, 0.0, 1.0);
    const b = try spawn(&world, .{ .x = 0.5, .y = 0 }, V2.ZERO, 0.0, 1.0);

    const events = [_]Collision{mkCollision(a, b, .{ .x = 1, .y = 0 }, 0.5)};
    physics.response(&world, &events);

    try testing.expectApproxEqAbs(@as(f32, 0.0), posOf(&world, a).x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.5), posOf(&world, b).x, eps);
}

// MARK: forces — gravity integration + damping

test "gravity accelerates a dynamic body (v += g*scale*dt)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // gravity (0,-10), scale 1, dt 0.1 → v gains -1.0 in y per call.
    const body = try spawnGravity(&world, V2.ZERO, 1.0, 1.0);
    physics.forces(&world, 0.1, .{ .x = 0, .y = -10 });
    try testing.expectApproxEqAbs(@as(f32, -1.0), velOf(&world, body).y, eps);

    physics.forces(&world, 0.1, .{ .x = 0, .y = -10 });
    try testing.expectApproxEqAbs(@as(f32, -2.0), velOf(&world, body).y, eps); // accumulates
}

test "gravity_scale 0 means gravity is ignored" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const body = try spawnGravity(&world, V2.ZERO, 1.0, 0.0);
    physics.forces(&world, 0.1, .{ .x = 0, .y = -10 });
    try testing.expectApproxEqAbs(@as(f32, 0.0), velOf(&world, body).y, eps);
}

test "static body (mass 0) is unaffected by forces" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const body = try spawnGravity(&world, V2.ZERO, 0.0, 1.0); // mass 0 + gravity
    physics.forces(&world, 0.1, .{ .x = 0, .y = -10 });
    try testing.expectApproxEqAbs(@as(f32, 0.0), velOf(&world, body).y, eps); // did not fall
}

test "friction damps velocity (v *= 1 - friction*dt)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Velocity, .{ .linear = .{ .x = 10, .y = 0 }, .angular = 0 });
    try world.addComponent(e, Physics, .{ .mass = 1.0, .friction = 2.0 });

    // dt 0.1, friction 2.0 → damp = 1 - 0.2 = 0.8 → vx: 10*0.8 = 8.
    physics.forces(&world, 0.1, V2.ZERO);
    try testing.expectApproxEqAbs(@as(f32, 8.0), velOf(&world, e).x, eps);
}
