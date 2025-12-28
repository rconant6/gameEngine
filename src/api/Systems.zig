const self = @This();
const std = @import("std");
const rend = @import("renderer");
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
const Engine = @import("engine.zig").Engine;

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
    }
}
pub fn renderSystem(engine: *Engine) void {
    var world = &engine.world;
    var renderer = &engine.renderer;
    var query = world.query(.{ Transform, Sprite });

    while (query.next()) |entry| {
        const transform = entry.get(0);
        const sprite = entry.get(1);

        if (sprite.visible) {
            renderer.drawGeometry(
                sprite.geometry,
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

    var assets = &engine.assets;
    var text_query = world.query(.{ Transform, Text });
    while (text_query.next()) |entry| {
        const transform = entry.get(0);
        const text = entry.get(1);

        const font = assets.fonts.getFont(text.font);

        if (font) |f| {
            renderer.drawText(
                f,
                text.text,
                transform.position,
                text.scale,
                text.color,
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
                std.log.err(
                    "Failed to add 'Destroy' to entity {d} at lifetime expiration {}",
                    .{ entry.entity.id, err },
                );
            };
        }
    }
}
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

pub fn cleanupSystem(engine: *Engine) void {
    var world = engine.world;
    const allocator = world.allocator;

    var to_destroy: std.ArrayList(Entity) = .empty;
    defer to_destroy.deinit(world.allocator);

    var query = world.query(.{Destroy});
    while (query.next()) |entry| {
        to_destroy.append(allocator, entry.entity) catch continue;
    }

    for (to_destroy.items) |entity| {
        world.destroyEntity(entity);
    }
}
