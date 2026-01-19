const std = @import("std");
const ArrayList = std.ArrayList;
const ecs = @import("ecs");
const Collider = ecs.Collider;
const Transform = ecs.Transform;
const World = ecs.World;
const CircleCollider = ecs.CircleCollider;
const RectangleCollider = ecs.RectangleCollider;

// Re-export Collision for test convenience
pub const Collision = ecs.Collision;
const db = @import("debug");
const DebugCategory = db.DebugCategory;
const DebugManager = db.DebugManager;
const rend = @import("renderer");
const Colors = rend.Colors;
const math = @import("math");
const V2 = math.V2;

pub const CollisionData = struct {
    point: V2,
    normal: V2,
    penetration: f32,
};

pub fn run(
    world: *World,
    collisions: anytype,
    debugger: *DebugManager,
) void {
    collisions.clearRetainingCapacity();
    detectCollisions(world, collisions) catch {
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

// MARK: Collision Detection Functions
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

            switch (collider_a.collider) {
                inline else => |shape_a| {
                    switch (collider_b.collider) {
                        inline else => |shape_b| {
                            if (tryCallCollision(
                                shape_a,
                                transform_a.*,
                                shape_b,
                                transform_b.*,
                            )) |hit| {
                                try collision_events.append(world.allocator, .{
                                    .entity_a = entity_a.entity,
                                    .entity_b = entity_b.entity,
                                    .point = hit.point,
                                    .normal = hit.normal,
                                    .penetration = hit.penetration,
                                });
                            }
                        },
                    }
                },
            }
        }
    }
}

fn stripModulePrefix(comptime full_name: []const u8) []const u8 {
    comptime {
        if (std.mem.lastIndexOf(u8, full_name, ".")) |idx| {
            return full_name[idx + 1 ..];
        }
        return full_name;
    }
}

fn tryCallCollision(a: anytype, ta: Transform, b: anytype, tb: Transform) ?CollisionData {
    const T1 = @TypeOf(a);
    const T2 = @TypeOf(b);
    const name1 = comptime stripModulePrefix(@typeName(T1));
    const name2 = comptime stripModulePrefix(@typeName(T2));
    const name = "collide" ++ name1 ++ name2;

    if (@hasDecl(@This(), name)) {
        return @call(.auto, @field(@This(), name), .{ a, ta, b, tb });
    }

    // NOTE: reverse (RectangleVsCircle) but flip the normal back
    const rev_name = "collide" ++ name2 ++ name1;
    if (@hasDecl(@This(), rev_name)) {
        if (@call(.auto, @field(@This(), rev_name), .{ b, tb, a, ta })) |hit| {
            var flipped = hit;
            flipped.normal = flipped.normal.negate();
            return flipped;
        }
    }

    return null;
}

pub fn collideCircleColliderCircleCollider(
    a: CircleCollider,
    ta: Transform,
    b: CircleCollider,
    tb: Transform,
) ?CollisionData {
    const radius_a = a.radius * ta.scale;
    const radius_b = b.radius * tb.scale;
    const pos_a = a.origin.add(ta.position);
    const pos_b = b.origin.add(tb.position);

    const delta = pos_b.sub(pos_a);
    const dist_sq = (delta.x * delta.x) + (delta.y * delta.y);
    const radii_sum = radius_a + radius_b;

    if (dist_sq > radii_sum * radii_sum) return null;

    const dist = delta.magnitude();

    if (dist < 0.00001) {
        return .{
            .point = pos_a,
            .normal = .{ .x = 1.0, .y = 0.0 },
            .penetration = radii_sum,
        };
    }

    const normal = delta.div(dist);

    const hit_point = pos_a.add(normal.mul(radius_a));

    return .{ .point = hit_point, .normal = normal, .penetration = radii_sum - dist };
}

pub fn collideCircleColliderRectangleCollider(
    a: CircleCollider,
    ta: Transform,
    b: RectangleCollider,
    tb: Transform,
) ?CollisionData {
    const radius_a = a.radius * ta.scale;
    const pos_a = a.origin.add(ta.position);
    const pos_b = b.center.add(tb.position);
    const b_half_w = b.half_width * tb.scale;
    const b_half_h = b.half_height * tb.scale;

    const left_x = pos_b.x - b_half_w;
    const right_x = pos_b.x + b_half_w;
    const top = pos_b.y + b_half_h;
    const bottom = pos_b.y - b_half_h;

    const closest_x = @max(left_x, @min(pos_a.x, right_x));
    const closest_y = @max(bottom, @min(pos_a.y, top));

    const dx = pos_a.x - closest_x;
    const dy = pos_a.y - closest_y;

    const dist_sq = (dx * dx) + (dy * dy);
    const radii_sq = radius_a * radius_a;

    if (dist_sq > radii_sq) return null;

    const dist = @sqrt(dist_sq);

    const normal = if (dist > 0.00001)
        V2{ .x = dx / dist, .y = dy / dist }
    else blk: {
        const dl = @abs(pos_a.x - left_x);
        const dr = @abs(pos_a.x - right_x);
        const dt = @abs(pos_a.y - top);
        const d_bottom = @abs(pos_a.y - bottom);
        const min = @min(dl, @min(dr, @min(dt, d_bottom)));

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

pub fn collideRectangleColliderRectangleCollider(
    a: RectangleCollider,
    ta: Transform,
    b: RectangleCollider,
    tb: Transform,
) ?CollisionData {
    const pos_a = a.center.add(ta.position);
    const a_half_w = a.half_width * ta.scale;
    const a_half_h = a.half_height * ta.scale;
    const a_left_x = pos_a.x - a_half_w;
    const a_right_x = pos_a.x + a_half_w;
    const a_top = pos_a.y + a_half_h;
    const a_bottom = pos_a.y - a_half_h;

    const pos_b = b.center.add(tb.position);
    const b_half_w = b.half_width * tb.scale;
    const b_half_h = b.half_height * tb.scale;
    const b_left_x = pos_b.x - b_half_w;
    const b_right_x = pos_b.x + b_half_w;
    const b_top = pos_b.y + b_half_h;
    const b_bottom = pos_b.y - b_half_h;

    if (a_right_x < b_left_x or a_left_x > b_right_x or
        a_top < b_bottom or a_bottom > b_top)
    {
        return null;
    }

    const overlap_x_left = a_right_x - b_left_x;
    const overlap_x_right = b_right_x - a_left_x;
    const overlap_y_top = a_top - b_bottom;
    const overlap_y_bottom = b_top - a_bottom;

    const overlap_x = @min(overlap_x_left, overlap_x_right);
    const overlap_y = @min(overlap_y_top, overlap_y_bottom);

    if (overlap_x < overlap_y) {
        // Collision from left or right
        const normal = if (overlap_x_left < overlap_x_right)
            V2{ .x = 1.0, .y = 0.0 } // Push right
        else
            V2{ .x = -1.0, .y = 0.0 }; // Push left

        const point_x = if (normal.x > 0) a_right_x else a_left_x;
        const point_y = (a_top + a_bottom) / 2.0;

        return .{
            .point = .{ .x = point_x, .y = point_y },
            .normal = normal,
            .penetration = overlap_x,
        };
    } else {
        // Collision from top or bottom
        const normal = if (overlap_y_top < overlap_y_bottom)
            V2{ .x = 0.0, .y = 1.0 } // Push up
        else
            V2{ .x = 0.0, .y = -1.0 }; // Push down

        const point_x = (a_left_x + a_right_x) / 2.0;
        const point_y = if (normal.y > 0) a_top else a_bottom;

        return .{
            .point = .{ .x = point_x, .y = point_y },
            .normal = normal,
            .penetration = overlap_y,
        };
    }
}
