const triggers = @import("Triggers.zig");

pub fn ActionBindings(comptime TriggerType: type) type {
    return struct {
        triggers: []const TriggerType,

        const Self = @This();

        pub fn hasTriggers(self: Self) bool {
            return self.triggers.len > 0;
        }
    };
}

const CollisionTrigger = triggers.CollisionTrigger;
const InputTrigger = triggers.InputTrigger;

pub const OnCollision = ActionBindings(CollisionTrigger);
pub const OnInput = ActionBindings(InputTrigger);
