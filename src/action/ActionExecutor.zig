const std = @import("std");
const ecs = @import("ecs");
const World = ecs.World;
const Destroy = ecs.Destroy;
const Velocity = ecs.Velocity;
const Action = ecs.Action;
const ActionType = ecs.ActionType;
const ActionTarget = ecs.ActionTarget;
const ActionQueue = @import("ActionQueue.zig").ActionQueue;
const scene = @import("scene");
const Template = scene.Template;

pub fn executeActions(world: *World, action_queue: *ActionQueue) void {
    action_queue.sortByPriority();

    for (action_queue.actions.items) |queued| {
        const action = queued.action;
        switch (action.action_type) {
            .destroy_self => {
                world.addComponent(queued.context.self_ent, Destroy, .{}) catch |err| {
                    std.log.err(
                        "destroy_self failed on entity-id: {d}    {any}",
                        .{ queued.context.self_ent.id, err },
                    );
                };
            },
            .destroy_other => {
                if (queued.context.other_ent) |other| {
                    world.addComponent(other, Destroy, .{}) catch |err| {
                        std.log.err(
                            "destroy_self failed on entity-id: {d}   {any}",
                            .{ queued.context.self_ent.id, err },
                        );
                    };
                } else {
                    std.log.warn("destroy_other action has no other_entity", .{});
                }
            },
            .spawn_entity => |spawn_data| {
                const name = spawn_data.template_name;
                const offset = spawn_data.offset;
                //BUG: this is wrong...need transform and sprite
                const location = if (queued.context.collision_loc) |loc| blk: {
                    break :blk loc.add(offset);
                } else offset;

                const entity = world.createEntityFromTemplate(
                    name,
                    location,
                ) catch |err| {
                    std.log.err("Unable to find template: {s} {any}", .{ name, err });
                    continue;
                };
                std.log.info("Created entity: {d} from {s} at {any}", .{
                    entity.id,
                    name,
                    location,
                });
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
            .debug_print => |t| std.debug.print("{s}", .{t}),
            .play_sound => |s| std.debug.print("play sound {s}", .{s}),
        }
    }

    action_queue.clear();
}
