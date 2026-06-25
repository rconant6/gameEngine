const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ecs = @import("ecs");
const Destroy = ecs.Destroy;
const Entity = ecs.Entity;
const Lifetime = ecs.Lifetime;
const World = ecs.World;

fn cleanup(world: *World, frame: Allocator) void {
    var doomed: ArrayList(Entity) = .empty;
    defer doomed.deinit(frame);
    var query = world.query(.{Destroy});
    while (query.next()) |entry| {
        doomed.append(frame, entry.entity) catch {};
    }
    for (doomed.items) |e| world.destroyEntity(e);
}

pub fn run(world: *World, dt: f32, frame: Allocator) void {
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
    cleanup(world, frame);
}
