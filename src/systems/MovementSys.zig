const ecs = @import("entity");
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const World = ecs.World;
const rend = @import("renderer");
const Colors = rend.Colors;
const db = @import("debug");
const DebugCategory = db.DebugCategory;
const Debugger = db.DebugManager;

pub fn movementSystem(world: *World, dt: f32, debug: *Debugger) void {
    var query = world.query(.{ Transform, Velocity });

    while (query.next()) |entry| {
        const transform = entry.get(0);
        const velocity = entry.get(1);

        transform.position.x += velocity.linear.x * dt;
        transform.position.y += velocity.linear.y * dt;
        transform.rotation += velocity.angular * dt;

        if (velocity.linear.x != 0 and velocity.linear.y != 0) {
            const end = transform.position.add(velocity.linear.mul(velocity.linear.magnitude()).mul(0.12));
            debug.draw.addArrow(.{
                .start = transform.position,
                .end = end,
                .color = Colors.NEON_ORANGE,
                .head_size = 0.2,
                .duration = null,
                .cat = DebugCategory.single(.velocity),
            });
        }
    }
}
