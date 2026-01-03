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

const CollisionData = struct {
    point: V2,
    normal: V2,
    penetration: f32,
};

const TransformedCollider = struct { position: V2, scale: f32, shape: ColliderShape };

// MARK: Collision detection functions
pub fn collideCircleCircle(
    a: TransformedCollider,
    b: TransformedCollider,
) ?CollisionData {
    const radius_a = a.shape.circle.radius * a.scale;
    const radius_b = b.shape.circle.radius * b.scale;

    const delta = b.position.sub(a.position);
    const dist = delta.magnitude();
    const radii_sum = radius_a + radius_b;

    if (dist > radii_sum) return null;
    const penetration = radii_sum - dist;
    const normal = delta.normalize();
    if (dist < 0.00001) return .{
        .point = a.position,
        .normal = .{ .x = radius_b, .y = 0 },
        .penetration = radius_a,
    };
    const hit_point = a.position.add(normal.mul(a.shape.circle.radius));

    return .{ .point = hit_point, .normal = normal, .penetration = penetration };
}

// MARK: dispatch table
const CollisionFn = *const fn (TransformedCollider, TransformedCollider) ?CollisionData;
const table_size = @typeInfo(ColliderShape).@"union".fields.len;
const dispatch_table: [table_size][table_size]CollisionFn = .{
    // Rows: Circle, Rect, etc..
    [_]CollisionFn{collideCircleCircle}, // Circle collisions
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

            // Skip if either collider has no shape
            const shape_a = collider_a.shape orelse continue;
            const shape_b = collider_b.shape orelse continue;

            const shape_a_idx = @intFromEnum(shape_a);
            const shape_b_idx = @intFromEnum(shape_b);
            const row = if (shape_a_idx < shape_b_idx) shape_a_idx else shape_b_idx;
            const col = if (shape_a_idx < shape_b_idx) shape_b_idx else shape_a_idx;
            const collision_fn = dispatch_table[row][col];
            const collision_data = collision_fn(
                .{
                    .position = transform_a.position,
                    .scale = transform_a.scale,
                    .shape = shape_a,
                },
                .{
                    .position = transform_b.position,
                    .scale = transform_b.scale,
                    .shape = shape_b,
                },
            );

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
