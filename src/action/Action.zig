const V2 = @import("core").V2;
pub const action_bind = @import("ActionBindings.zig");
pub const ActionBindings = action_bind.ActionBindings;
pub const OnCollision = action_bind.OnCollision;
pub const OnInput = action_bind.OnInput;
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
pub const ActionSystem = @import("ActionSystem.zig");

pub const ActionTarget = enum {
    self,
    other,
};

pub const ActionType = union(enum) {
    destroy_self: void,
    destroy_other: void,
    spawn_entity: struct {
        template_name: []const u8,
        offset: V2,
    },
    set_velocity: struct {
        target: ActionTarget,
        velocity: V2,
    },
    debug_print: []const u8,
    play_sound: []const u8,
};

pub const Action = struct {
    action_type: ActionType,
    priority: i32 = 0,
};
