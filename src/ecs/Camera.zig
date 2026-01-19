const Self = @This();
const core = @import("math");
const WorldPoint = core.WorldPoint;
const comps = @import("Components.zig");
const Transform = comps.Transform;
const CameraTracking = comps.CameraTracking;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Rect = rend.Shapes.Rectangle;
const World = @import("World.zig");
const Entity = @import("Entity.zig");

const zoom_scale: f32 = 0.10;
const min_zoom: f32 = 1.0;
const max_zoom: f32 = 1000.0;

ortho_size: f32, // vertical half_height in WORLDSPACE
viewport: Rect,
priority: i32,
rotation: f32 = 0,
background: ?Color = Colors.CLEAR,

pub fn setPosition(world: *World, entity: Entity, x: f32, y: f32) void {
    const xform = world.getComponentMut(entity, Transform) orelse return; // TODO: Log Error move on
    xform.position.x = x;
    xform.position.y = y;
}
pub fn getPosition(world: *World, entity: Entity) WorldPoint {
    const xform = world.getComponent(entity, Transform) orelse return .{}; // TODO: Log Error move on
    return xform.position;
}
pub fn translate(world: *World, entity: Entity, dx: f32, dy: f32) void {
    const xform = world.getComponentMut(entity, Transform) orelse return; // TODO: Log Error move on
    xform.position = xform.position.add(.{ .x = dx, .y = dy });
}
pub fn setOrthoSize(world: *World, entity: Entity, size: f32) void {
    const cam = world.getComponentMut(entity, Self) orelse return; // TODO: Log error
    if (size <= 0) {
        cam.ortho_size = 0.1;
        return;
    }
    cam.ortho_size = size;
}
pub fn getOrthoSize(world: *World, entity: Entity) f32 {
    const cam = world.getComponent(entity, Self) orelse return 10.0;
    return cam.ortho_size;
}
/// zoom steps incrementally
/// factor > 1.0 = zoom out (see more)
/// factor < 1.0 = zoom in (see less)
/// factor = 0.5 = half orthosize = zoom * 2.0
pub fn zoom(world: *World, entity: Entity, factor: f32) void {
    if (factor <= 0) return;
    const cam = world.getComponentMut(entity, Self) orelse return;
    const new_size = cam.ortho_size * factor;
    if (new_size <= 0) return; // TODO: Log error
    cam.ortho_size = new_size;
}
pub fn smoothZoom(world: *World, entity: Entity, delta: f32) void {
    const cam = world.getComponentMut(entity, Self) orelse return;
    var new_size = cam.ortho_size + delta * zoom_scale * -1.0;
    new_size = if (new_size <= min_zoom) min_zoom else new_size;
    new_size = if (new_size >= max_zoom) max_zoom else new_size;
    cam.ortho_size = new_size;
}
pub fn getViewBounds(world: *World, entity: Entity) Rect {
    const cam = world.getComponent(entity, Self) orelse return; // TODO: Log error
    const transform = world.getComponent(entity, Transform) orelse return;
    const aspect = cam.viewport.half_width / cam.viewport.half_height;
    return .{
        .center = transform.position,
        .half_height = cam.ortho_size,
        .half_width = cam.ortho_size * aspect,
    };
}

pub fn enableCameraTracking(world: *World, camera: Entity) void {
    if (!world.hasComponent(camera, CameraTracking)) {
        world.addComponent(camera, CameraTracking, .{}) catch {
            //TODO: proper logging/handling
        };
    }
    const camera_tracking = world.getComponentMut(camera, CameraTracking).?;
    camera_tracking.mode.enabled = true;
}
pub fn disableCameraTracking(world: *World, camera: Entity) void {
    const camera_tracking = world.getComponentMut(camera, CameraTracking) orelse return;
    camera_tracking.mode.enabled = false;
}

pub fn setCameraFollowStiffness(world: *World, camera: Entity, x: f32, y: f32) void {
    var camera_tracking = world.getComponentMut(camera, CameraTracking) orelse return; // TODO: Log error
    camera_tracking.follow_stiffness.x = x;
    camera_tracking.follow_stiffness.y = y;
}
pub fn setCameraFollowDamping(world: *World, camera: Entity, x: f32, y: f32) void {
    var camera_tracking = world.getComponentMut(camera, CameraTracking) orelse return; // TODO: Log error
    camera_tracking.follow_damping.x = x;
    camera_tracking.follow_damping.y = y;
}
pub fn setTrackingTarget(world: *World, camera: Entity, target: Entity) void {
    var camera_tracking = world.getComponentMut(camera, CameraTracking) orelse return; // TODO: Log error
    camera_tracking.target = target;
}
