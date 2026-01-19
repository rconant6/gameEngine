const ecs = @import("ecs");
const World = ecs.World;
const Transform = ecs.Transform;
const ActiveCamera = ecs.ActiveCamera;
const CameraTracking = ecs.CameraTracking;
const CameraTarget = ecs.CameraTarget;

pub fn run(world: *World, dt: f32) void {
    var targetQuery = world.query(.{CameraTarget});
    _ = targetQuery;
    _ = dt;
}
