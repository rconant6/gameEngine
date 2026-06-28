const ecs = @import("ecs");
pub const ActiveCamera = ecs.ActiveCamera;
pub const Box = ecs.Box;
pub const Camera = ecs.Camera;
pub const CameraTracking = ecs.CameraTracking;
pub const Collider = ecs.Collider;
pub const ColliderShape = ecs.ColliderShape;
pub const Destroy = ecs.Destroy;
pub const Entity = ecs.Entity;
pub const Lifetime = ecs.Lifetime;
pub const OnCollision = ecs.OnCollision;
pub const OnInput = ecs.OnInput;
pub const Physics = ecs.Physics;
pub const RenderLayer = ecs.RenderLayer;
pub const Sprite = ecs.Sprite;
pub const Tag = ecs.Tag;
pub const Text = ecs.Text;
pub const TrackingMode = ecs.TrackingMode;
pub const Transform = ecs.Transform;
pub const Velocity = ecs.Velocity;
pub const World = ecs.World;
const Engine = @import("../Engine.zig").Engine;
const log = @import("debug").log;

pub fn createEntity(self: *Engine) Entity {
    // OOMing here means we need to fail loudly
    return self.world.createEntity() catch |e| Engine.fatal("createEntity", e);
}

pub fn destroyEntity(self: *Engine, entity: Entity) void {
    self.world.destroyEntity(entity);
}

pub fn addComponent(
    self: *Engine,
    entity: Entity,
    comptime T: type,
    value: T,
) void {
    self.world.addComponent(entity, T, value) catch |e| switch (e) {
        error.EntityDoesNotExist => log.warn(
            .ecs,
            "addComponent({s}) on a non-live entity {d} — ignored",
            .{ @typeName(T), entity.id },
        ),
        else => Engine.fatal("addComponent", e),
    };
}

pub fn findEntityByTag(self: *Engine, tag: []const u8) ?Entity {
    return self.world.findEntityByTag(tag);
}

pub fn findEntitiesByTag(self: *Engine, tag: []const u8) []Entity {
    return self.world.findEntitiesByTag(tag, self.mem.frame);
}
pub fn findEntitiesByPattern(self: *Engine, pattern: []const u8) []Entity {
    return self.world.findEntitiesByPattern(pattern, self.mem.frame);
}

pub fn clearEntitiesByTag(self: *Engine, tag: []const u8) void {
    for (self.world.findEntitiesByTag(tag, self.mem.frame)) |e| {
        self.world.destroyEntity(e);
    }
}
