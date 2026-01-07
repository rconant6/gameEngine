const std = @import("std");
const testing = std.testing;
const core = @import("core");
const V2 = core.V2;
const ColliderData = core.ColliderData;
const ecs = @import("entity");
const World = ecs.World;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Collider = ecs.Collider;
const Collision = ecs.Collision;
const CollisionDetection = core.CollisionDetection;

// MARK: End-to-End Integration Tests

test "E2E: create world, add entities, detect collisions" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Create two overlapping circles
    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 6, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 1), collision_events.items.len);
    try testing.expectApproxEqAbs(@as(f32, 4.0), collision_events.items[0].penetration, 0.001);
}

test "E2E: physics simulation with collisions" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Create moving ball
    const ball = try world.createEntity();
    try world.addComponent(ball, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(ball, Velocity, Velocity{
        .linear = V2{ .x = 5.0, .y = 0 },
        .angular = 0,
    });
    try world.addComponent(ball, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 2.0 } },
    });

    // Create static wall
    const wall = try world.createEntity();
    try world.addComponent(wall, Transform, Transform{
        .position = V2{ .x = 10, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(wall, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 2.0 } },
    });

    // Simulate movement
    const dt: f32 = 0.1;
    {
        var query = world.query(.{ Transform, Velocity });
        while (query.next()) |*entry| {
            const transform = entry.get(0);
            const velocity = entry.get(1);
            transform.position = transform.position.add(velocity.linear.mul(dt));
        }
    }

    // Check for collisions
    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Ball should not be colliding yet (moved 0.5 units, gap is 10 - 4 = 6)
    try testing.expectEqual(@as(usize, 0), collision_events.items.len);

    // Simulate more movement (move ball 5.5 more units)
    var i: usize = 0;
    while (i < 11) : (i += 1) {
        var query = world.query(.{ Transform, Velocity });
        while (query.next()) |*entry| {
            const transform = entry.get(0);
            const velocity = entry.get(1);
            transform.position = transform.position.add(velocity.linear.mul(dt));
        }
    }

    // Now check for collision
    collision_events.clearRetainingCapacity();
    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Should now be colliding
    try testing.expect(collision_events.items.len > 0);
}

test "E2E: multiple entities with different collision shapes" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Circle 1
    const circle1 = try world.createEntity();
    try world.addComponent(circle1, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(circle1, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 3.0 } },
    });

    // Circle 2
    const circle2 = try world.createEntity();
    try world.addComponent(circle2, Transform, Transform{
        .position = V2{ .x = 5, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(circle2, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 3.0 } },
    });

    // Rectangle
    const rect = try world.createEntity();
    try world.addComponent(rect, Transform, Transform{
        .position = V2{ .x = 10, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(rect, Collider, Collider{
        .collider = ColliderData{ .RectangleCollider = .{ .half_w = 2.0, .half_h = 2.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Circle1 and Circle2 should be colliding (distance 5, radii sum 6)
    try testing.expect(collision_events.items.len >= 1);
}

test "E2E: scale affects collision detection" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Small scaled circle
    const small = try world.createEntity();
    try world.addComponent(small, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 0.5, // Half scale
    });
    try world.addComponent(small, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 4.0 } }, // Effective radius: 2.0
    });

    // Large scaled circle
    const large = try world.createEntity();
    try world.addComponent(large, Transform, Transform{
        .position = V2{ .x = 10, .y = 0 },
        .rotation = 0,
        .scale = 2.0, // Double scale
    });
    try world.addComponent(large, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 4.0 } }, // Effective radius: 8.0
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Distance: 10, effective radii: 2.0 + 8.0 = 10.0, so touching
    try testing.expect(collision_events.items.len >= 1);
}

test "E2E: query system with transforms and velocities" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Create multiple entities with different components
    const e1 = try world.createEntity();
    try world.addComponent(e1, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e1, Velocity, Velocity{
        .linear = V2{ .x = 1.0, .y = 1.0 },
        .angular = 0,
    });

    const e2 = try world.createEntity();
    try world.addComponent(e2, Transform, Transform{
        .position = V2{ .x = 5, .y = 5 },
        .rotation = 0,
        .scale = 1.0,
    });

    const e3 = try world.createEntity();
    try world.addComponent(e3, Transform, Transform{
        .position = V2{ .x = 10, .y = 10 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e3, Velocity, Velocity{
        .linear = V2{ .x = -1.0, .y = -1.0 },
        .angular = 0,
    });

    // Query for entities with both Transform and Velocity
    var count: usize = 0;
    {
        var query = world.query(.{ Transform, Velocity });
        while (query.next()) |_| {
            count += 1;
        }
    }

    // Should find e1 and e3 (e2 has no Velocity)
    try testing.expectEqual(@as(usize, 2), count);
}

test "E2E: component removal and collision detection" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    try world.addComponent(e1, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e1, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const e2 = try world.createEntity();
    try world.addComponent(e2, Transform, Transform{
        .position = V2{ .x = 6, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e2, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    // Should have collision
    try CollisionDetection.detectCollisions(&world, &collision_events);
    try testing.expect(collision_events.items.len > 0);

    // Remove collider from e2
    world.removeComponent(e2, Collider);

    // Clear and recheck
    collision_events.clearRetainingCapacity();
    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Should have no collision
    try testing.expectEqual(@as(usize, 0), collision_events.items.len);
}

test "E2E: entity destruction and collision detection" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    try world.addComponent(e1, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e1, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const e2 = try world.createEntity();
    try world.addComponent(e2, Transform, Transform{
        .position = V2{ .x = 6, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e2, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    // Should have collision
    try CollisionDetection.detectCollisions(&world, &collision_events);
    try testing.expect(collision_events.items.len > 0);

    // Destroy entity
    world.destroyEntity(e2);

    // Clear and recheck
    collision_events.clearRetainingCapacity();
    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Should have no collision
    try testing.expectEqual(@as(usize, 0), collision_events.items.len);
}

test "E2E: V2 math in transform updates" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const e = try world.createEntity();
    try world.addComponent(e, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e, Velocity, Velocity{
        .linear = V2{ .x = 3.0, .y = 4.0 },
        .angular = 0,
    });

    // Update position using V2 math
    {
        var query = world.query(.{ Transform, Velocity });
        while (query.next()) |*entry| {
            const transform = entry.get(0);
            const velocity = entry.get(1);

            // Test V2 operations
            const displacement = velocity.linear.mul(1.0);
            transform.position = transform.position.add(displacement);
        }
    }

    // Verify position
    {
        var query = world.query(.{Transform});
        while (query.next()) |entry| {
            const transform = entry.get(0);
            try testing.expectApproxEqAbs(@as(f32, 3.0), transform.position.x, 0.001);
            try testing.expectApproxEqAbs(@as(f32, 4.0), transform.position.y, 0.001);

            // Test magnitude
            const mag = transform.position.magnitude();
            try testing.expectApproxEqAbs(@as(f32, 5.0), mag, 0.001);
        }
    }
}

test "E2E: collision normal calculation with V2" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    try world.addComponent(e1, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e1, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const e2 = try world.createEntity();
    try world.addComponent(e2, Transform, Transform{
        .position = V2{ .x = 6, .y = 8 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(e2, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expect(collision_events.items.len > 0);

    const collision = collision_events.items[0];
    // Normal should be normalized (magnitude 1.0)
    const normal_mag = collision.normal.magnitude();
    try testing.expectApproxEqAbs(@as(f32, 1.0), normal_mag, 0.01);

    // Normal should point either from e1 to e2 OR from e2 to e1 (both are valid)
    const temp = V2{ .x = 6, .y = 8 };
    const expected_dir = temp.normalize();
    const matches_forward = @abs(collision.normal.x - expected_dir.x) < 0.01 and
        @abs(collision.normal.y - expected_dir.y) < 0.01;
    const matches_backward = @abs(collision.normal.x + expected_dir.x) < 0.01 and
        @abs(collision.normal.y + expected_dir.y) < 0.01;
    try testing.expect(matches_forward or matches_backward);
}

test "E2E: stress test with many entities" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Create 20 entities
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const e = try world.createEntity();
        const x = @as(f32, @floatFromInt(i)) * 2.0;
        try world.addComponent(e, Transform, Transform{
            .position = V2{ .x = x, .y = 0 },
            .rotation = 0,
            .scale = 1.0,
        });
        try world.addComponent(e, Collider, Collider{
            .collider = ColliderData{ .CircleCollider = .{ .radius = 1.5 } },
        });
    }

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    // With spacing of 2.0 and radius 1.5, adjacent circles overlap
    // Should have many collisions
    try testing.expect(collision_events.items.len > 0);
}
