const core = @import("core");
const CollisionDetection = core.CollisionDetection;
const db = @import("debug");
const DebugCategory = db.DebugCategory;
const DebugManager = db.DebugManager;
const ecs = @import("entity");
const Collider = ecs.Collider;
const Transform = ecs.Transform;
const World = ecs.World;
const rend = @import("renderer");
const Colors = rend.Colors;

pub fn collisionDetectionSystem(
    world: *World,
    collisions: anytype,
    debugger: *DebugManager,
) void {
    collisions.clearRetainingCapacity();
    CollisionDetection.detectCollisions(world, collisions) catch {
        // TODO: proper logging
    };

    // DEBUG
    var query = world.query(.{ Transform, Collider });
    while (query.next()) |entry| {
        const transform = entry.get(0);
        const collider = entry.get(1);

        switch (collider.collider) {
            .CircleCollider => |circle| {
                debugger.draw.addCircle(.{
                    .origin = circle.origin.add(transform.position),
                    .radius = circle.radius * transform.scale,
                    .color = Colors.GREEN,
                    .filled = false,
                    .duration = null,
                    .cat = DebugCategory.single(.collision),
                });
            },
            .RectangleCollider => |rect| {
                const pos = rect.center.add(transform.position);
                const hw = rect.half_width * transform.scale;
                const hh = rect.half_height * transform.scale;
                debugger.draw.addRect(.{
                    .min = .{ .x = pos.x - hw, .y = pos.y - hh },
                    .max = .{ .x = pos.x + hw, .y = pos.y + hh },
                    .color = Colors.GREEN,
                    .filled = false,
                    .duration = null,
                    .cat = DebugCategory.single(.collision),
                });
            },
        }
    }
    for (collisions.items) |collision| {
        debugger.draw.addCircle(.{
            .origin = collision.point,
            .radius = 0.1,
            .color = Colors.RED,
            .filled = true,
            .duration = null,
            .cat = DebugCategory.single(.collision),
        });
        const normal_end = collision.point.add(collision.normal.mul(2.0));
        debugger.draw.addArrow(.{
            .start = collision.point,
            .end = normal_end,
            .color = Colors.NEON_YELLOW,
            .head_size = 0.5,
            .duration = null,
            .cat = DebugCategory.single(.collision),
        });
    }
}
