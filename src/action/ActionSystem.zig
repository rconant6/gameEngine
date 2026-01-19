const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ActionQueue = @import("ActionQueue.zig").ActionQueue;
const World = @import("ecs").World;
const triggers = @import("Triggers.zig");
const TriggerSystem = triggers.TriggerSystem;
const TriggerContext = triggers.TriggerContext;
const InputTrigger = triggers.InputTrigger;
const CollisionTrigger = triggers.CollisionTrigger;
const ActionExecutor = @import("ActionExecutor.zig");

allocator: Allocator,
action_queue: ActionQueue,
trigger_systems: ArrayList(TriggerSystem),

var dummy_state: u8 = 0;

fn collisionTriggerWrapper(
    ptr: *anyopaque,
    world: *World,
    ctx: TriggerContext,
) anyerror!void {
    _ = ptr;
    try CollisionTrigger.process(world, ctx);
}
fn inputTriggerWrapper(
    ptr: *anyopaque,
    world: *World,
    ctx: TriggerContext,
) anyerror!void {
    _ = ptr; // Stateless, don't need the pointer
    try InputTrigger.process(world, ctx);
}

pub fn init(allocator: Allocator) !Self {
    var action_system = Self{
        .allocator = allocator,
        .action_queue = ActionQueue.init(allocator),
        .trigger_systems = .empty,
    };

    try action_system.trigger_systems.append(allocator, .{
        .sys = &dummy_state,
        .processFn = collisionTriggerWrapper,
    });
    try action_system.trigger_systems.append(allocator, .{
        .sys = &dummy_state,
        .processFn = inputTriggerWrapper,
    });

    return action_system;
}
pub fn deinit(self: *Self) void {
    self.trigger_systems.deinit(self.allocator);
    self.action_queue.deinit();
}

pub fn registerTrigger(self: *Self, trigger_system: TriggerSystem) !void {
    try self.trigger_systems.append(self.allocator, trigger_system);
}
