const Engine = @import("../Engine.zig").Engine;
const ecs = @import("ecs");
const Collision = ecs.Collision;

pub fn clearCollisionEvents(self: *Engine) void {
    self.collision_events = &.{};
}

pub fn getCollisionEvents(self: *Engine) []const Collision {
    return self.collision_events;
}
