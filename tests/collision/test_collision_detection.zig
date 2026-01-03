const std = @import("std");
const testing = std.testing;
const V2 = @import("core").V2;
const ecs = @import("entity");
const World = ecs.World;
const Transform = ecs.Transform;
const Collider = ecs.Collider;
const ColliderShape = ecs.ColliderShape;
const Collision = ecs.Collision;
const CollisionDetection = @import("CollisionDetection");
const TransformedCollider = CollisionDetection.TransformedCollider;

// MARK: Circle-Circle Collision Tests

test "CollisionDetection: circle-circle no collision (far apart)" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 20, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-circle touching (edge case)" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 10, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    // Exactly touching should register as a collision
    try testing.expect(result != null);
    if (result) |collision| {
        try testing.expectApproxEqAbs(@as(f32, 0.0), collision.penetration, 0.001);
    }
}

test "CollisionDetection: circle-circle overlapping" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 7, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    try testing.expect(result != null);
    if (result) |collision| {
        // Penetration should be (5 + 5) - 7 = 3
        try testing.expectApproxEqAbs(@as(f32, 3.0), collision.penetration, 0.001);
        // Normal should point from a to b (positive x direction)
        try testing.expectApproxEqAbs(@as(f32, 1.0), collision.normal.x, 0.001);
        try testing.expectApproxEqAbs(@as(f32, 0.0), collision.normal.y, 0.001);
    }
}

test "CollisionDetection: circle-circle fully overlapping (same position)" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 3.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    try testing.expect(result != null);
    if (result) |collision| {
        // When circles are at same position, penetration should be sum of radii
        try testing.expectApproxEqAbs(@as(f32, 8.0), collision.penetration, 0.001);
    }
}

test "CollisionDetection: circle-circle with scale" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 2.0, // Doubled radius: 5 * 2 = 10
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 15, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    // Effective radii: 10 + 5 = 15, distance = 15, so touching
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle diagonal collision" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 6, .y = 8 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    // Distance: sqrt(6^2 + 8^2) = 10, radii sum: 10, so touching
    try testing.expect(result != null);
    if (result) |collision| {
        // Normal should be normalized direction from a to b
        const temp = V2{ .x = 6, .y = 8 };
        const expected_normal = temp.normalize();
        try testing.expectApproxEqAbs(expected_normal.x, collision.normal.x, 0.001);
        try testing.expectApproxEqAbs(expected_normal.y, collision.normal.y, 0.001);
    }
}

test "CollisionDetection: circle-circle different sizes" {
    const a = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 10.0 } },
    };
    const b = TransformedCollider{
        .position = V2{ .x = 8, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 2.0 } },
    };

    const result = CollisionDetection.collideCircleCircle(a, b);
    try testing.expect(result != null);
    if (result) |collision| {
        // Penetration: (10 + 2) - 8 = 4
        try testing.expectApproxEqAbs(@as(f32, 4.0), collision.penetration, 0.001);
    }
}

// MARK: Circle-Rectangle Collision Tests

test "CollisionDetection: circle-rect no collision (far apart)" {
    const circle = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const rect = TransformedCollider{
        .position = V2{ .x = 50, .y = 50 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 10.0 } },
    };

    const result = CollisionDetection.collideCircleRect(circle, rect);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-rect center overlap" {
    const circle = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const rect = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 10.0 } },
    };

    const result = CollisionDetection.collideCircleRect(circle, rect);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-rect edge collision" {
    const circle = TransformedCollider{
        .position = V2{ .x = 16, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const rect = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 10.0 } },
    };

    const result = CollisionDetection.collideCircleRect(circle, rect);
    // Circle at x=16, rect right edge at x=10, distance = 6, radius = 5
    // No collision since 6 > 5
    try testing.expect(result == null);
}

test "CollisionDetection: circle-rect corner collision" {
    const circle = TransformedCollider{
        .position = V2{ .x = 13, .y = 13 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    };
    const rect = TransformedCollider{
        .position = V2{ .x = 0, .y = 0 },
        .scale = 1.0,
        .rotation = 0,
        .shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 10.0 } },
    };

    const result = CollisionDetection.collideCircleRect(circle, rect);
    // Corner at (10, 10), circle at (13, 13)
    // Distance: sqrt((13-10)^2 + (13-10)^2) = sqrt(18) ≈ 4.24
    // Since 4.24 < 5, there should be a collision
    try testing.expect(result != null);
}

// MARK: World Integration Tests

test "CollisionDetection: detect collisions in world with two circles" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 7, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 1), collision_events.items.len);

    const collision = collision_events.items[0];
    try testing.expectApproxEqAbs(@as(f32, 3.0), collision.penetration, 0.001);
}

test "CollisionDetection: detect no collisions when circles far apart" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 100, .y = 100 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 0), collision_events.items.len);
}

test "CollisionDetection: detect multiple collisions" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Create three overlapping circles
    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 6, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_c = try world.createEntity();
    try world.addComponent(entity_c, Transform, Transform{
        .position = V2{ .x = 3, .y = 5 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_c, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    // Should detect: a-b, a-c, and possibly b-c
    try testing.expect(collision_events.items.len >= 2);
}

test "CollisionDetection: ignore entities without collider" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    // Entity with collider
    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    // Entity without collider
    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 5, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 0), collision_events.items.len);
}

test "CollisionDetection: ignore entities with null collider shape" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 5, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = null,
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 0), collision_events.items.len);
}

test "CollisionDetection: detect circle-rect collision in world" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 8, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = ColliderShape{ .rectangle = .{ .half_w = 5.0, .half_h = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expect(collision_events.items.len > 0);
}

test "CollisionDetection: collision events contain correct entity IDs" {
    const allocator = testing.allocator;
    var world = try World.init(allocator);
    defer world.deinit();

    const entity_a = try world.createEntity();
    try world.addComponent(entity_a, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_a, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 7, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .shape = ColliderShape{ .circle = .{ .radius = 5.0 } },
    });

    var collision_events: std.ArrayList(Collision) = .empty;
    defer collision_events.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collision_events);

    try testing.expectEqual(@as(usize, 1), collision_events.items.len);

    const collision = collision_events.items[0];
    // Entity IDs should match (order may vary)
    const has_correct_entities = (collision.entity_a.id == entity_a.id and collision.entity_b.id == entity_b.id) or
        (collision.entity_a.id == entity_b.id and collision.entity_b.id == entity_a.id);
    try testing.expect(has_correct_entities);
}
