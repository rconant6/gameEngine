const self = @This();
const std = @import("std");
const rend = @import("renderer");
const Colors = rend.Colors;
const ecs = @import("entity");
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const ScreenWrap = ecs.ScreenWrap;
const ScreenClamp = ecs.ScreenClamp;
const Sprite = ecs.Sprite;
const Velocity = ecs.Velocity;
const World = ecs.World;
const Text = ecs.Text;
const LifeTime = ecs.Lifetime;
const Destroy = ecs.Destroy;
const Box = ecs.Box;
const Collider = ecs.Collider;
const Engine = @import("engine.zig").Engine;
const core = @import("core");
const shapes = core.Shapes;
const CollisionDetection = core.CollisionDetection;
const ShapeRegistry = core.ShapeRegistry;
const db = @import("debug");
const DebugCategory = db.DebugCategory;

const Renderer = rend.Renderer;
pub fn movementSystem(engine: *Engine, dt: f32) void {
    var world = engine.world;
    var query = world.query(.{ Transform, Velocity });

    while (query.next()) |entry| {
        const transform = entry.get(0);
        const velocity = entry.get(1);

        transform.position.x += velocity.linear.x * dt;
        transform.position.y += velocity.linear.y * dt;
        transform.rotation += velocity.angular * dt;

        if (velocity.linear.x != 0 and velocity.linear.y != 0) {
            const end = transform.position.add(velocity.linear.mul(velocity.linear.magnitude()).mul(0.12));
            engine.debugger.draw.addArrow(.{
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
pub fn physicsSystem(engine: *Engine, dt: f32) void {
    // TODO: Implement
    _ = engine;
    _ = dt;
}
pub fn renderSystem(engine: *Engine) void {
    var world = &engine.world;
    var renderer = &engine.renderer;

    var box_query = world.query(.{ Transform, Box });
    while (box_query.next()) |entry| {
        const transform = entry.get(0);
        const box = entry.get(1);
        const geo = shapes.Rectangle.initFromCenter(
            .{ .x = 0, .y = 0 },
            box.size.x,
            box.size.y,
        );

        if (box.filled) {
            renderer.drawGeometry(ShapeRegistry.createShapeUnion(shapes.Rectangle, geo), .{
                .offset = transform.position,
                .rotation = transform.rotation,
                .scale = transform.scale,
            }, box.fill_color, null, 1.0);
        } else {
            renderer.drawGeometry(ShapeRegistry.createShapeUnion(shapes.Rectangle, geo), .{
                .offset = transform.position,
                .rotation = transform.rotation,
                .scale = transform.scale,
            }, null, box.fill_color, 1.0);
        }
    }

    var assets = &engine.assets;
    var text_query = world.query(.{ Transform, Text });
    while (text_query.next()) |entry| {
        const transform = entry.get(0);
        const text = entry.get(1);

        const font = assets.getFont(text.font_asset) orelse continue;

        renderer.drawText(
            font,
            text.text,
            transform.position,
            text.size,
            text.text_color,
        );
    }
    var query = world.query(.{ Transform, Sprite });
    while (query.next()) |entry| {
        const transform = entry.get(0);
        const sprite = entry.get(1);
        const geo = sprite.geometry orelse continue;

        if (sprite.visible) {
            renderer.drawGeometry(
                geo,
                .{
                    .offset = transform.position,
                    .rotation = transform.rotation,
                    .scale = transform.scale,
                },
                sprite.fill_color,
                sprite.stroke_color,
                sprite.stroke_width,
            );
        }
    }
}

pub fn lifetimeSystem(engine: *Engine, dt: f32) void {
    var world = &engine.world;
    var query = world.query(.{LifeTime});

    while (query.next()) |entry| {
        const lifetime = entry.get(0);

        lifetime.remaining -= dt;

        if (lifetime.remaining <= 0) {
            world.addComponent(entry.entity, Destroy, .{}) catch |err| {
                engine.logError(
                    .ecs,
                    "Failed to add 'Destroy' to entity {d} at lifetime expiration: {any}",
                    .{ entry.entity.id, err },
                );
            };
        }
    }
    cleanupSystem(engine);
}

// TODO: This needs work to 'split'?
pub fn screenWrapSystem(engine: *Engine) void {
    var world = &engine.world;
    var query = world.query(.{ Transform, ScreenWrap });

    while (query.next()) |entry| {
        const transform = entry.get(0);

        const left = engine.getLeftEdge();
        const right = engine.getRightEdge();
        const top = engine.getTopEdge();
        const bottom = engine.getBottomEdge();

        if (transform.position.x > right) {
            transform.position.x = left;
        } else if (transform.position.x < left) {
            transform.position.x = right;
        }

        if (transform.position.y > top) {
            transform.position.y = bottom;
        } else if (transform.position.y < bottom) {
            transform.position.y = top;
        }
    }
}

// TODO: This needs to work based on shapes and the sizes
// do a better job of bouncing when edge hits (bounding boxes)
// once collisionTriggers work
pub fn screenClampSystem(engine: *Engine) void {
    var world = &engine.world;
    var query = world.query(.{ Transform, Velocity, ScreenClamp });

    while (query.next()) |entry| {
        const transform = entry.get(0);
        const velocity = entry.get(1);

        const left = engine.getLeftEdge();
        const right = engine.getRightEdge();
        const top = engine.getTopEdge();
        const bottom = engine.getBottomEdge();

        if (transform.position.x <= left or transform.position.x >= right) {
            velocity.linear.x *= -1.0;
            transform.position.x = std.math.clamp(transform.position.x, left, right);
        }

        if (transform.position.y <= bottom or transform.position.y >= top) {
            velocity.linear.y *= -1.0;
            transform.position.y = std.math.clamp(transform.position.y, bottom, top);
        }
    }
}

pub fn collisionDetectionSystem(engine: *Engine) void {
    engine.clearCollisionEvents();
    CollisionDetection.detectCollisions(&engine.world, &engine.collision_events) catch |err| {
        engine.logError(.engine, "Failed to run detection system: {any}", .{err});
    };

    // DEBUG
    var query = engine.world.query(.{ Transform, Collider });
    while (query.next()) |entry| {
        const transform = entry.get(0);
        const collider = entry.get(1);

        switch (collider.collider) {
            .CircleCollider => |circle| {
                engine.debugger.draw.addCircle(.{
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
                engine.debugger.draw.addRect(.{
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
    for (engine.collision_events.items) |collision| {
        engine.debugger.draw.addCircle(.{
            .origin = collision.point,
            .radius = 0.1,
            .color = Colors.RED,
            .filled = true,
            .duration = null,
            .cat = DebugCategory.single(.collision),
        });
        const normal_end = collision.point.add(collision.normal.mul(2.0));
        engine.debugger.draw.addArrow(.{
            .start = collision.point,
            .end = normal_end,
            .color = Colors.NEON_YELLOW,
            .head_size = 0.5,
            .duration = null,
            .cat = DebugCategory.single(.collision),
        });
    }
}

pub fn cleanupSystem(engine: *Engine) void {
    var world = &engine.world;

    var query = world.query(.{Destroy});
    while (query.next()) |entry| {
        world.destroyEntity(entry.entity);
    }
}
