const World = @import("ecs").World;
const ActionSystem = @import("action").ActionSystem;
const TriggerContext = @import("action").TriggerContext;
const ActionExecutor = @import("action").ActionExecutor;

pub fn run(
    world: *World,
    action_system: *ActionSystem,
    ctx: TriggerContext,
) !void {
    // Process all triggers
    for (action_system.trigger_systems.items) |system| {
        try system.processFn(system.sys, world, ctx);
    }

    // Execute queued actions
    ActionExecutor.executeActions(world, &action_system.action_queue);

    // Clear queue for next frame
    action_system.action_queue.clear();
}
