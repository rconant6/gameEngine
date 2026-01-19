const std = @import("std");
const ecs = @import("ecs");
const World = ecs.World;
const Transform = ecs.Transform;
const ActiveCamera = ecs.ActiveCamera;
const CameraTracking = ecs.CameraTracking;
const CameraTarget = ecs.CameraTarget;
const Camera = ecs.Camera;

pub fn run(world: *World, dt: f32) void {
    var query = world.query(.{ CameraTracking, ActiveCamera });
    if (query.next()) |entry| {
        const tracking = entry.get(0); // Need mutable access to update velocity
        if (!tracking.mode.enabled) return;

        const camera = entry.entity;
        const camera_xform = world.getComponent(camera, Transform) orelse return;
        const camera_pos = camera_xform.position;
        const target = tracking.target orelse return;
        const target_xform = world.getComponent(target, Transform) orelse return;
        const target_pos = target_xform.position;

        if (tracking.mode.immediate) {
            // Immediate mode - snap directly to target
            Camera.setPosition(
                world,
                camera,
                target_pos.x,
                target_pos.y,
            );
            tracking.velocity_tracker = .ZERO;
        } else if (tracking.mode.smooth) {
            // Smooth mode - spring-damper system
            const displacement_x = target_pos.x - camera_pos.x;
            const displacement_y = target_pos.y - camera_pos.y;

            const spring_force_x = displacement_x * tracking.follow_stiffness.x;
            const spring_force_y = displacement_y * tracking.follow_stiffness.y;

            const damping_force_x = tracking.velocity_tracker.x * tracking.follow_damping.x;
            const damping_force_y = tracking.velocity_tracker.y * tracking.follow_damping.y;

            const accel_x = spring_force_x - damping_force_x;
            const accel_y = spring_force_y - damping_force_y;

            tracking.velocity_tracker.x += accel_x * dt;
            tracking.velocity_tracker.y += accel_y * dt;

            const new_x = camera_pos.x + tracking.velocity_tracker.x * dt;
            const new_y = camera_pos.y + tracking.velocity_tracker.y * dt;

            Camera.setPosition(world, camera, new_x, new_y);
        }

        tracking.last_target_position = target_pos;
    }
}
