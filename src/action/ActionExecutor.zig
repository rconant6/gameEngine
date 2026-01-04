const std = @import("std");
const ecs = @import("entity");
const World = ecs.World;
const Destroy = ecs.Destroy;
const Velocity = ecs.Velocity;
const Action = ecs.Action;
const ActionType = ecs.ActionType;
const ActionTarget = ecs.ActionTarget;
const ActionQueue = @import("ActionQueue.zig").ActionQueue;

pub fn executeActions(world: *World, action_queue: *ActionQueue) !void {
    action_queue.sortByPriority();

    for (action_queue.actions.items) |queued| {
        const action = queued.action;
        switch (action.action_type) {
            .destroy_self => {
                try world.addComponent(queued.context.self_ent, Destroy, .{});
            },
            .destroy_other => {
                if (queued.context.other_ent) |other| {
                    try world.addComponent(other, Destroy, .{});
                } else {
                    std.log.warn("destroy_other action has no other_entity", .{});
                }
            },
            .spawn_entity => |spawn_data| {
                // TODO: world.spawnFromTemplate(spawn_data.template_name)
                // TODO: set position based on self_entity + offset
                _ = spawn_data;
                std.log.warn("spawn_entity not yet implemented", .{});
            },
            .set_velocity => |vel_data| {
                const target_entity = switch (vel_data.target) {
                    .self => queued.context.self_ent,
                    .other => queued.context.other_ent orelse {
                        std.log.warn("set_velocity target=other but no other_entity", .{});
                        continue;
                    },
                };

                if (world.getComponentMut(target_entity, Velocity)) |velocity| {
                    velocity.linear = vel_data.velocity;
                } else {
                    std.log.warn("set_velocity: entity {d} has no Velocity component", .{target_entity.id});
                }
            },
            .debug_print => |t| std.debug.print("Key Pressed: {any}", .{t}),
            .play_sound => |sound_name| {
                // TODO: audio_system.play(sound_name)
                _ = sound_name;
                std.log.warn("play_sound not yet implemented", .{});
            },
        }
    }

    action_queue.clear();
}
