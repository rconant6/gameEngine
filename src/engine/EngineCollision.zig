const Engine = @import("../engine.zig").Engine;
const core = @import("math");
const Collision = core.Collision;

pub fn clearCollisionEvents(self: *Engine) void {
    self.collision_events.clearRetainingCapacity();
}

pub fn getCollisionEvents(self: *Engine) []const Collision {
    return self.collision_events.items;
}
