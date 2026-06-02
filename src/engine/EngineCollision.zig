const Engine = @import("../Engine.zig").Engine;
const core = @import("math");
const Collision = core.Collision;

pub fn clearCollisionEvents(self: *Engine) void {
    self.collision_events = &.{};
}

pub fn getCollisionEvents(self: *Engine) []const Collision {
    return self.collision_events;
}
