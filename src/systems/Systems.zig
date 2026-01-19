const self = @This();
const std = @import("std");
const db = @import("debug");
const DebugManager = db.DebugManager;
const DebugCategory = db.DebugCategory;
const ecs = @import("ecs");
const ActiveCamera = ecs.ActiveCamera;
const Collider = ecs.Collider;
const Destroy = ecs.Destroy;
const Lifetime = ecs.Lifetime;
const Sprite = ecs.Sprite;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const World = ecs.World;
const rend = @import("renderer");
const Colors = rend.Colors;
const RenderContext = rend.RenderContext;
const Renderer = rend.Renderer;

pub const movementSystem = @import("MovementSys.zig").run;
pub const physicsSystem = @import("PhysicsSys.zig").run;
pub const collisionDetectionSystem = @import("CollisionDetectionSys.zig").run;
pub const actionSystem = @import("ActionSys.zig").run;
pub const lifetimeSystem = @import("LifetimeSys.zig").run;
pub const renderSystem = @import("RenderSys.zig").run;
pub const cameraTrackingSystem = @import("CameraTrackingSys.zig").run;

pub const CollisionDetectionSys = @import("CollisionDetectionSys.zig");

pub fn debugEntityInfoSystem(world: *World, debugger: *DebugManager) void {
    var query = world.query(.{Transform});

    while (query.next()) |entry| {
        const transform = entry.get(0);
        const entity_id = entry.entity.id;

        // Build component indicator string
        var indicators: [32]u8 = undefined;
        var idx: usize = 0;

        // Check for common components and add indicators
        if (world.hasComponent(entry.entity, Velocity)) {
            indicators[idx] = 'V';
            idx += 1;
        }
        if (world.hasComponent(entry.entity, Collider)) {
            indicators[idx] = 'C';
            idx += 1;
        }
        if (world.hasComponent(entry.entity, Lifetime)) {
            indicators[idx] = 'L';
            idx += 1;
        }
        if (world.hasComponent(entry.entity, Sprite)) {
            indicators[idx] = 'S';
            idx += 1;
        }
        if (world.hasComponent(entry.entity, ActiveCamera)) {
            indicators[idx] = 'A';
            idx += 1;
        }
        if (world.hasComponent(entry.entity, ecs.Tag)) {
            const tag = world.getComponent(entry.entity, ecs.Tag) orelse break;
            indicators[idx] = 't';
            idx += 1;
            var buf: [64]u8 = undefined;
            const tags = std.fmt.bufPrint(&buf, "t: {s}", .{tag.tags}) catch "ERROR";
            debugger.draw.addText(.{
                .text = world.allocator.dupe(u8, tags) catch "",
                .position = .{ .x = transform.position.x, .y = transform.position.y + 1.0 },
                .color = Colors.LIGHT_GRAY,
                .size = 0.3,
                .duration = null,
                .cat = DebugCategory.single(.entity_info),
                .owns_text = true,
            });
        }

        // Draw text above entity
        var buf: [64]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "id: {d}  {s}", .{ entity_id, indicators[0..idx] }) catch "ERROR";

        debugger.draw.addCircle(.{
            .filled = true,
            .origin = transform.position,
            .radius = 0.025,
            .color = Colors.YELLOW,
            .cat = DebugCategory.single(.entity_info),
        });
        debugger.draw.addText(.{
            .text = world.allocator.dupe(u8, text) catch "",
            .position = .{ .x = transform.position.x, .y = transform.position.y + 1.5 },
            .color = Colors.WHITE,
            .size = 0.3,
            .duration = null,
            .cat = DebugCategory.single(.entity_info),
            .owns_text = true,
        });
    }
}
