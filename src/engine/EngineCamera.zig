const std = @import("std");
const Engine = @import("../engine.zig").Engine;
const ecs = @import("ecs");
const Entity = ecs.Entity;
const Camera = ecs.Camera;
const CameraTracking = ecs.CameraTracking;
const Transform = ecs.Transform;
const ActiveCamera = ecs.ActiveCamera;
const core = @import("math");
const V2 = core.V2;
const renderer = @import("renderer");
const Rectangle = renderer.Rectangle;

pub fn createCamera(self: *Engine) !Entity {
    const camera = try self.world.createEntity();
    try self.world.addComponent(camera, ActiveCamera, ActiveCamera{});
    try self.world.addComponent(camera, Transform, Transform{});
    try self.world.addComponent(camera, Camera, Camera{
        .ortho_size = 10.0,
        .viewport = .{
            .center = V2.ZERO,
            .half_width = @floatFromInt(self.getGameWidth() / 2),
            .half_height = @floatFromInt(self.getGameHeight() / 2),
        },
        .priority = 1,
    });
    return camera;
}

pub fn setActiveCamera(self: *Engine, camera: Entity) void {
    self.active_camera_entity = camera;
}

pub fn getActiveCamera(self: *const Engine) ?Entity {
    return self.active_camera_entity;
}

pub fn getActiveCameraTransform(self: *const Engine) ?*const Transform {
    return self.world.getComponent(self.active_camera_entity.?, Transform);
}

pub fn setCameraPosition(self: *Engine, camera: Entity, location: V2) void {
    Camera.setPosition(&self.world, camera, location.x, location.y);
}

pub fn setActiveCameraPosition(self: *Engine, location: V2) void {
    const camera = self.active_camera_entity;
    Camera.setPosition(&self.world, camera, location.x, location.y);
}

pub fn translateCamera(self: *Engine, camera: Entity, dxy: V2) void {
    Camera.translate(&self.world, camera, dxy.x, dxy.y);
}

pub fn translateActiveCamera(self: *Engine, dxy: V2) void {
    const camera = self.active_camera_entity;
    Camera.translate(&self.world, camera, dxy.x, dxy.y);
}

pub fn setCameraOrthoSize(self: *Engine, camera: Entity, new_size: f32) void {
    Camera.setOrthoSize(&self.world, camera, new_size);
}

pub fn setActiveCameraOrthoSize(self: *Engine, new_size: f32) void {
    const camera = self.active_camera_entity;
    Camera.setOrthoSize(&self.world, camera, new_size);
}

pub fn zoomCameraInc(self: *Engine, camera: Entity, factor: f32) void {
    Camera.zoom(&self.world, camera, factor);
}

pub fn zoomActiveCameraInc(self: *Engine, factor: f32) void {
    const camera = self.active_camera_entity;
    Camera.zoom(&self.world, camera, factor);
}

pub fn zoomCameraSmooth(self: *Engine, camera: Entity, delta: f32) void {
    Camera.smoothZoom(&self.world, camera, delta);
}

pub fn zoomActiveCameraSmooth(self: *Engine, factor: f32) void {
    const camera = self.active_camera_entity;
    Camera.smoothZoom(&self.world, camera, factor);
}

pub fn getCameraViewBounds(self: *Engine, camera: Entity) Rectangle {
    return Camera.getViewBounds(&self.world, camera);
}

pub fn getActiveCameraViewBounds(self: *Engine) Rectangle {
    return Camera.getViewBounds(&self.world, self.active_camera_entity);
}

pub fn setActiveCameraTrackingTarget(self: *Engine, target: Entity) void {
    Camera.setTrackingTarget(&self.world, self.active_camera_entity, target);
}

pub fn enableActiveCameraTracking(self: *Engine) void {
    Camera.enableCameraTracking(&self.world, self.active_camera_entity);
}
pub fn disableActiveCameraTracking(self: *Engine) void {
    Camera.disableCameraTracking(&self.world, self.active_camera_entity);
}

pub fn setActiveCameraFollowStiffness(self: *Engine, x: f32, y: f32) void {
    Camera.setCameraFollowStiffness(&self.world, self.active_camera_entity, x, y);
}

pub fn setActiveCameraFollowDamping(self: *Engine, x: f32, y: f32) void {
    Camera.setCameraFollowDamping(&self.world, self.active_camera_entity, x, y);
}
