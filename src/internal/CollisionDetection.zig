const std = @import("std");
const ArrayList = std.ArrayList;
const V2 = @import("core").V2;
const entity = @import("entity");
const World = entity.World;
const Entity = entity.Entity;
const Collision = entity.Collision;
const Transform = entity.Transform;
const Collider = entity.Collider;
const ColliderShape = entity.ColliderShape;

pub const CollisionData = struct {
    point: V2,
    normal: V2,
    penetration: f32,
};

pub const TransformedCollider = struct {
    position: V2,
    scale: f32,
    rotation: f32,
    shape: ColliderShape,
};

// MARK: Collision detection functions
pub fn collideCircleCircle(
    a: TransformedCollider,
    b: TransformedCollider,
) ?CollisionData {
    const radius_a = a.shape.circle.radius * a.scale;
    const radius_b = b.shape.circle.radius * b.scale;

    const delta = b.position.sub(a.position);
    const dist_sq = (delta.x * delta.x) + (delta.y * delta.y);
    const radii_sum = radius_a + radius_b;

    if (dist_sq > radii_sum * radii_sum) return null;

    const dist = delta.magnitude();

    if (dist < 0.00001) {
        return .{
            .point = a.position,
            .normal = .{ .x = 1.0, .y = 0.0 },
            .penetration = radii_sum,
        };
    }

    const normal = delta.div(dist);

    const hit_point = a.position.add(normal.mul(radius_a));

    return .{ .point = hit_point, .normal = normal, .penetration = radii_sum - dist };
}
pub fn collideCircleRect(a: TransformedCollider, b: TransformedCollider) ?CollisionData {
    const radius_a = a.shape.circle.radius * a.scale;

    const left_x = b.position.x - b.shape.rectangle.half_w;
    const right_x = b.position.x + b.shape.rectangle.half_w;
    const top = b.position.y + b.shape.rectangle.half_h;
    const bottom = b.position.y - b.shape.rectangle.half_h;

    const closest_x = @max(left_x, @min(a.position.x, right_x));
    const closest_y = @max(bottom, @min(a.position.y, top));

    const dx = a.position.x - closest_x;
    const dy = a.position.y - closest_y;

    const dist_sq = (dx * dx) + (dy * dy);
    const radii_sq = radius_a * radius_a;

    if (dist_sq > radii_sq) return null;

    const dist = @sqrt(dist_sq);

    const normal = if (dist > 0.00001)
        V2{ .x = dx / dist, .y = dy / dist }
    else blk: {
        const dl = @abs(a.position.x - left_x);
        const dr = @abs(a.position.x - right_x);
        const dt = @abs(a.position.y - top);
        const db = @abs(a.position.y - bottom);
        const min = @min(dl, @min(dr, @min(dt, db)));

        if (min == dl) break :blk V2{ .x = -1, .y = 0 };
        if (min == dr) break :blk V2{ .x = 1, .y = 0 };
        if (min == dt) break :blk V2{ .x = 0, .y = 1 };
        break :blk V2{ .x = 0, .y = -1 };
    };

    return .{
        .point = .{ .x = closest_x, .y = closest_y },
        .normal = normal,
        .penetration = radius_a - dist,
    };
}
pub fn collideRectRect(
    a: TransformedCollider,
    b: TransformedCollider,
) ?CollisionData {
    _ = a;
    _ = b;
    return null;
}

// MARK: dispatch table
const CollisionFn = *const fn (TransformedCollider, TransformedCollider) ?CollisionData;
const table_size = @typeInfo(ColliderShape).@"union".fields.len;
const dispatch_table: [table_size][table_size]CollisionFn = .{
    // Rows: Circle, Rect, etc..
    [_]CollisionFn{ collideCircleCircle, collideCircleRect }, // Circle collisions
    [_]CollisionFn{ undefined, collideRectRect }, // Rectangle collisions
};
comptime {
    if (dispatch_table.len != table_size) {
        @compileError("Dispatch table row count does not match ShapeType count");
    }
}
// MARK: Main collisiton detector
pub fn detectCollisions(
    world: *World,
    collision_events: *ArrayList(Collision),
) !void {
    var query = world.query(.{ Transform, Collider });
    const QueryType = @TypeOf(query);
    const Entry = QueryType.Entry;
    var entities: ArrayList(Entry) = .empty;
    defer entities.deinit(world.allocator);
    while (query.next()) |entry| {
        try entities.append(world.allocator, entry);
    }

    for (entities.items, 0..) |entity_a, i| {
        for (entities.items[i + 1 ..]) |entity_b| {
            const transform_a = entity_a.get(0);
            const transform_b = entity_b.get(0);
            const collider_a = entity_a.get(1);
            const collider_b = entity_b.get(1);

            const shape_a = collider_a.shape orelse continue;
            const shape_b = collider_b.shape orelse continue;

            const shape_a_idx = @intFromEnum(shape_a);
            const shape_b_idx = @intFromEnum(shape_b);
            const row = if (shape_a_idx <= shape_b_idx) shape_a_idx else shape_b_idx;
            const col = if (shape_a_idx <= shape_b_idx) shape_b_idx else shape_a_idx;
            const collision_fn = dispatch_table[row][col];
            const collision_data =
                if (shape_a_idx < shape_b_idx) blk: {
                    break :blk collision_fn(
                        .{
                            .position = transform_a.position,
                            .scale = transform_a.scale,
                            .rotation = transform_a.rotation,
                            .shape = shape_a,
                        },
                        .{
                            .position = transform_b.position,
                            .scale = transform_b.scale,
                            .rotation = transform_b.rotation,
                            .shape = shape_b,
                        },
                    );
                } else blk: {
                    break :blk collision_fn(
                        .{
                            .position = transform_b.position,
                            .scale = transform_b.scale,
                            .rotation = transform_b.rotation,
                            .shape = shape_b,
                        },
                        .{
                            .position = transform_a.position,
                            .scale = transform_a.scale,
                            .rotation = transform_a.rotation,
                            .shape = shape_a,
                        },
                    );
                };

            if (collision_data) |data| {
                try collision_events.append(world.allocator, .{
                    .entity_a = entity_a.entity,
                    .entity_b = entity_b.entity,
                    .point = data.point,
                    .normal = data.normal,
                    .penetration = data.penetration,
                });
            }
        }
    }
}
