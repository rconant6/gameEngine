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
const Engine = @import("../engine.zig");

pub fn createEntity(self: *Engine) Entity {
    return self.world.createEntity() catch |err| {
        self.logError(.ecs, "Unable to add to create Entity: {any}", .{err});
    };
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
    self.world.addComponent(entity, T, value) catch |err| {
        self.logError(
            .ecs,
            "Unable to add component to Entity: {d} {any}",
            .{ entity.id, err },
        );
    };
}
