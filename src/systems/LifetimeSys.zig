const ecs = @import("entity");
const World = ecs.World;
const Lifetime = ecs.Lifetime;
const Destroy = ecs.Destroy;

fn cleanup(world: *World) void {
    var query = world.query(.{Destroy});
    while (query.next()) |entry| {
        world.destroyEntity(entry.entity);
    }
}

pub fn lifetimeSystem(world: *World, dt: f32) void {
    var query = world.query(.{Lifetime});

    while (query.next()) |entry| {
        const lifetime = entry.get(0);

        lifetime.remaining -= dt;

        if (lifetime.remaining <= 0) {
            world.addComponent(entry.entity, Destroy, .{}) catch {
                // TODO: add proper logging
            };
        }
    }
    cleanup(world);
}
