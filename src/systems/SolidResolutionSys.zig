const ecs = @import("ecs");
const Collider = ecs.Collider;
const Entity = ecs.Entity;
const Collision = ecs.Collision;
const Transform = ecs.Transform;
const World = ecs.World;
const V2 = @import("math").V2;

pub fn run(world: *World, events: []const Collision) void {
    for (events) |col| {
        const solid_a = isSolid(world, col.entity_a);
        const solid_b = isSolid(world, col.entity_b);

        if (solid_a == solid_b) continue; // both solid or non-solid (dont' care)

        // push the non-solid out along the normal by dist of penetration
        if (solid_b) {
            push(world, col.entity_a, col.normal.negate(), col.penetration);
        } else {
            push(world, col.entity_b, col.normal, col.penetration);
        }
    }
}

fn push(world: *World, e: Entity, dir: V2, penetration: f32) void {
    if (world.getComponentMut(e, Transform)) |t| {
        t.position = t.position.add(dir.mul(penetration + 0.001));
    }
}

fn isSolid(world: *World, e: Entity) bool {
    return if (world.getComponent(e, Collider)) |c| c.solid else return false;
}
