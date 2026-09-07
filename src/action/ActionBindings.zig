const std = @import("std");
const triggers = @import("Triggers.zig");

pub fn ActionBindings(comptime TriggerType: type) type {
    return struct {
        const Self = @This();

        triggers: []TriggerType,

        pub fn hasTriggers(self: Self) bool {
            return self.triggers.len > 0;
        }

        pub fn deinit(self: *Self, persistent: std.mem.Allocator) void {
            for (self.triggers) |*trigger| {
                trigger.deinit(persistent);
            }
            persistent.free(self.triggers);
        }
    };
}

const CollisionTrigger = triggers.CollisionTrigger;
const InputTrigger = triggers.InputTrigger;
const TimeTrigger = triggers.TimeTrigger;

pub const OnCollision = ActionBindings(CollisionTrigger);
pub const OnInput = ActionBindings(InputTrigger);
pub const OnTimer = ActionBindings(TimeTrigger);
