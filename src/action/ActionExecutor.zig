const ecs = @import("ecs");
const World = ecs.World;
const ActionQueue = @import("ActionQueue.zig").ActionQueue;
const ActionRegistry = @import("ActionRegistry.zig").ActionRegistry;
const EngineServices = @import("EngineServices.zig").EngineServices;
const ActionRunContext = @import("Action.zig").ActionRunContext;

pub fn executeActions(
    world: *World,
    action_queue: *ActionQueue,
    registry: *const ActionRegistry,
    services: *EngineServices,
    dt: f32,
) void {
    action_queue.sortByPriority();

    for (action_queue.actions.items) |queued| {
        var ctx = ActionRunContext{
            .world = world,
            .services = services,
            .dt = dt,
            .self_ent = queued.context.self_ent,
            .other_ent = queued.context.other_ent,
            .collision_loc = queued.context.collision_loc,
            .collision_normal = queued.context.collision_normal,
            .collision_penetration = queued.context.collision_penetration,
        };
        const entry = registry.get(queued.action.id);
        entry.execute(queued.action.params, &ctx);
    }

    action_queue.clear();
}
