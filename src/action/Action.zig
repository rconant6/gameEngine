const std = @import("std");
const Allocator = std.mem.Allocator;
const V2 = @import("math").V2;
pub const action_bind = @import("ActionBindings.zig");
pub const ActionBindings = action_bind.ActionBindings;
pub const OnCollision = action_bind.OnCollision;
pub const OnInput = action_bind.OnInput;
pub const OnTimer = action_bind.OnTimer;
pub const ActionExecutor = @import("ActionExecutor.zig");
const actque = @import("ActionQueue.zig");
pub const ActionContext = actque.ActionContext;
pub const QueuedAction = actque.QueuedAction;
pub const ActionQueue = actque.ActionQueue;
pub const triggers = @import("Triggers.zig");
pub const TriggerComp = triggers.Trigger;
pub const TriggerSystem = triggers.TriggerSystem;
pub const TriggerContext = triggers.TriggerContext;
pub const InputTrigger = triggers.InputTrigger;
pub const CollisionTrigger = triggers.CollisionTrigger;
pub const TimeTrigger = triggers.TimeTrigger;
pub const ActionSystem = @import("ActionSystem.zig");
pub const EngineServices = @import("EngineServices.zig").EngineServices;
pub const ActionRegistry = @import("ActionRegistry.zig").ActionRegistry;
pub const builtins = @import("builtin_actions.zig");
pub const registerBuiltins = builtins.registerBuiltins;
const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

pub const ActionTarget = enum {
    self,
    other,
};

pub const ActionId = u32;

pub const Action = struct {
    id: ActionId, // logging debugging only id
    params: ?*const anyopaque, // decoded param struct, owned by this action owned by the game
    priority: i32 = 0,
};

pub const ActionRunContext = struct {
    world: *World,
    services: *EngineServices,
    self_ent: Entity,
    other_ent: ?Entity = null,
    collision_loc: ?V2 = null,
    collision_normal: ?V2 = null, // always oriented toward self (coll: A -> B)
    collision_penetration: ?f32 = null,
    dt: f32 = 0,
};
