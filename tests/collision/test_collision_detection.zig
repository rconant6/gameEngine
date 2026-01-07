const std = @import("std");
const testing = std.testing;
const core = @import("core");
const V2 = core.V2;
const ColliderData = core.ColliderData;
const ecs = @import("entity");
const World = ecs.World;
const Transform = ecs.Transform;
const Collider = ecs.Collider;
const Collision = ecs.Collision;
const CircleCollider = ecs.CircleCollider;
const RectangleCollider = ecs.RectangleCollider;
const CollisionDetection = core.CollisionDetection;

// MARK: Circle-Circle Collision Tests

test "CollisionDetection: circle-circle no collision (far apart)" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 20, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-circle touching (edge case)" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 10, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle overlapping" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle fully overlapping (same position)" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle with scale" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 2.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 15, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle diagonal collision" {
    const circle_a = CircleCollider{ .radius =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 7 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle different sizes" {
    const circle_a = CircleCollider{ .radius =10.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius =2.0 };
    const transform_b = Transform{ .position = V2{ .x = 11, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

// MARK: Circle-Rectangle Collision Tests

test "CollisionDetection: circle-rect no collision (far apart)" {
    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 30, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-rect center overlap" {
    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-rect edge collision" {
    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 12, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-rect corner collision" {
    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 13, .y = 13 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

// MARK: Rectangle-Circle Collision Tests (reverse order)

test "CollisionDetection: rect-circle no collision (far apart)" {
    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 30, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderCircleCollider(rect, transform_rect, circle, transform_circle);
    try testing.expect(result == null);
}

test "CollisionDetection: rect-circle center overlap" {
    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderCircleCollider(rect, transform_rect, circle, transform_circle);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-circle edge collision" {
    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 12, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderCircleCollider(rect, transform_rect, circle, transform_circle);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-circle corner collision" {
    const rect = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius =5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 13, .y = 13 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderCircleCollider(rect, transform_rect, circle, transform_circle);
    try testing.expect(result != null);
}

// MARK: Rectangle-Rectangle Collision Tests

test "CollisionDetection: rect-rect no collision (far apart)" {
    const rect_a = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 20, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result == null);
}

test "CollisionDetection: rect-rect overlapping" {
    const rect_a = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect fully overlapping (same position)" {
    const rect_a = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect edge touching" {
    const rect_a = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 10, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect different sizes" {
    const rect_a = RectangleCollider{ .half_w =10.0, .half_h =10.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =2.0, .half_h =2.0 };
    const transform_b = Transform{ .position = V2{ .x = 11, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect with scale" {
    const rect_a = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 2.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_w =5.0, .half_h =5.0 };
    const transform_b = Transform{ .position = V2{ .x = 15, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetection.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
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
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 7, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collisions: std.ArrayList(CollisionDetection.Collision) = .empty;
    defer collisions.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collisions);

    try testing.expectEqual(@as(usize, 1), collisions.items.len);
    const collision = collisions.items[0];
    try testing.expect(
        (collision.entity_a.id == entity_a.id and collision.entity_b.id == entity_b.id) or
            (collision.entity_a.id == entity_b.id and collision.entity_b.id == entity_a.id),
    );
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
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 50, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collisions: std.ArrayList(CollisionDetection.Collision) = .empty;
    defer collisions.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collisions);

    try testing.expectEqual(@as(usize, 0), collisions.items.len);
}

test "CollisionDetection: detect multiple collisions" {
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
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 7, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_c = try world.createEntity();
    try world.addComponent(entity_c, Transform, Transform{
        .position = V2{ .x = 0, .y = 8 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_c, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collisions: std.ArrayList(CollisionDetection.Collision) = .empty;
    defer collisions.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collisions);

    try testing.expectEqual(@as(usize, 2), collisions.items.len);
}

test "CollisionDetection: ignore entities without collider" {
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
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 5, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });

    var collisions: std.ArrayList(CollisionDetection.Collision) = .empty;
    defer collisions.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collisions);

    try testing.expectEqual(@as(usize, 0), collisions.items.len);
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
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    const entity_b = try world.createEntity();
    try world.addComponent(entity_b, Transform, Transform{
        .position = V2{ .x = 7, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(entity_b, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 5.0 } },
    });

    var collisions: std.ArrayList(CollisionDetection.Collision) = .empty;
    defer collisions.deinit(allocator);

    try CollisionDetection.detectCollisions(&world, &collisions);

    try testing.expectEqual(@as(usize, 1), collisions.items.len);
    const collision = collisions.items[0];

    const found_a = collision.entity_a.id == entity_a.id or collision.entity_b.id == entity_a.id;
    const found_b = collision.entity_a.id == entity_b.id or collision.entity_b.id == entity_b.id;
    try testing.expect(found_a);
    try testing.expect(found_b);
}
