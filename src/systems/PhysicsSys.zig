const ecs = @import("ecs");
const World = ecs.World;
const Collision = ecs.Collision;
const Physics = ecs.Physics;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const math = @import("math");
const V2 = math.V2;

pub fn forces(world: *World, dt: f32, gravity: V2) void {
    var query = world.query(.{ Velocity, Physics });
    while (query.next()) |entry| {
        const phys: *const Physics = entry.get(1);
        const vel: *Velocity = entry.get(0);

        if (phys.mass == 0) continue;

        const accel = gravity.mul(phys.gravity_scale);
        vel.linear = vel.linear.add(accel.mul(dt));
        const damp = @max(0.0, 1.0 - phys.friction * dt);
        vel.linear = vel.linear.mul(damp);
    }
}

pub fn response(world: *World, collisions: []const Collision) void {
    for (collisions) |coll| {
        const phys_a = world.getComponent(coll.entity_a, Physics) orelse continue;
        const phys_b = world.getComponent(coll.entity_b, Physics) orelse continue;
        const e = combinedRestitution(phys_a, phys_b);
        const n = coll.normal; // points A -> B

        // A moves INTO B when its velocity aligns with n (d > 0); reflect it.
        if (phys_a.mass != 0) {
            if (world.getComponentMut(coll.entity_a, Velocity)) |v_a| {
                const d = v_a.linear.dot(n);
                if (d > 0)
                    v_a.linear = v_a.linear.sub(n.mul((1.0 + e) * d));
            }
        }

        // B moves INTO A when its velocity opposes n (d < 0); reflect it.
        if (phys_b.mass != 0) {
            if (world.getComponentMut(coll.entity_b, Velocity)) |v_b| {
                const d = v_b.linear.dot(n);
                if (d < 0)
                    v_b.linear = v_b.linear.sub(n.mul((1.0 + e) * d));
            }
        }

        seperate(world, phys_a, phys_b, coll);
    }
}

inline fn seperate(
    world: *World,
    pa: *const Physics,
    pb: *const Physics,
    coll: Collision,
) void {
    const inv_a = if (pa.mass == 0) 0.0 else 1.0 / pa.mass;
    const inv_b = if (pb.mass == 0) 0.0 else 1.0 / pb.mass;
    const inv_sum = inv_a + inv_b;

    if (inv_sum == 0) return; // both static

    const correction = coll.penetration + 0.001;
    const n = coll.normal; // points A -> B

    // A is pushed AWAY from B (along -n); B away from A (along +n), each by its share.
    if (inv_a > 0) {
        if (world.getComponentMut(coll.entity_a, Transform)) |ta| {
            ta.position = ta.position.sub(n.mul(correction * (inv_a / inv_sum)));
        }
    }
    if (inv_b > 0) {
        if (world.getComponentMut(coll.entity_b, Transform)) |tb| {
            tb.position = tb.position.add(n.mul(correction * (inv_b / inv_sum)));
        }
    }
}

inline fn combinedRestitution(a: *const Physics, b: *const Physics) f32 {
    return a.restitution * b.restitution;
}
