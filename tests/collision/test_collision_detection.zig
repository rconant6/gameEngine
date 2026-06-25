const std = @import("std");
const testing = std.testing;
const math = @import("math");
const V2 = math.V2;
const ecs = @import("ecs");
const ColliderData = ecs.ColliderData;
const World = ecs.World;
const Transform = ecs.Transform;
const Collider = ecs.Collider;
const Collision = ecs.Collision;
const CircleCollider = ecs.CircleCollider;
const RectangleCollider = ecs.RectangleCollider;
const systems = @import("systems");
const CollisionDetectionSys = systems.CollisionDetectionSys;

// MARK: Circle-Circle Collision Tests

test "CollisionDetection: circle-circle no collision (far apart)" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 20, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-circle touching (edge case)" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 10, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle overlapping" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle fully overlapping (same position)" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle with scale" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 2.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 15, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle diagonal collision" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 7 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-circle different sizes" {
    const circle_a = CircleCollider{ .radius = 10.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 2.0 };
    const transform_b = Transform{ .position = V2{ .x = 11, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderCircleCollider(circle_a, transform_a, circle_b, transform_b);
    try testing.expect(result != null);
}

// MARK: Circle-Rectangle Collision Tests

test "CollisionDetection: circle-rect no collision (far apart)" {
    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 30, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result == null);
}

test "CollisionDetection: circle-rect center overlap" {
    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-rect edge collision" {
    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 12, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: circle-rect corner collision" {
    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 13, .y = 13 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

// MARK: Rectangle-Circle Collision Tests (reverse order)

test "CollisionDetection: rect-circle no collision (far apart)" {
    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 30, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result == null);
}

test "CollisionDetection: rect-circle center overlap" {
    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-circle edge collision" {
    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 12, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-circle corner collision" {
    const rect = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle = CircleCollider{ .radius = 5.0 };
    const transform_circle = Transform{ .position = V2{ .x = 13, .y = 13 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideCircleColliderRectangleCollider(circle, transform_circle, rect, transform_rect);
    try testing.expect(result != null);
}

// MARK: Rectangle-Rectangle Collision Tests

test "CollisionDetection: rect-rect no collision (far apart)" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 20, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result == null);
}

test "CollisionDetection: rect-rect overlapping" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect fully overlapping (same position)" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect edge touching" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 10, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect different sizes" {
    const rect_a = RectangleCollider{ .half_width = 10.0, .half_height = 10.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 2.0, .half_height = 2.0 };
    const transform_b = Transform{ .position = V2{ .x = 11, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

test "CollisionDetection: rect-rect with scale" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 2.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 15, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const result = CollisionDetectionSys.collideRectangleColliderRectangleCollider(rect_a, transform_a, rect_b, transform_b);
    try testing.expect(result != null);
}

// MARK: World Integration Tests

test "CollisionDetection: detect collisions in world with two circles" {
    const gpa = testing.allocator;
    var world = try World.init(gpa);
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

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 1), collisions.items.len);
    const collision = collisions.items[0];
    try testing.expect(
        (collision.entity_a.id == entity_a.id and collision.entity_b.id == entity_b.id) or
            (collision.entity_a.id == entity_b.id and collision.entity_b.id == entity_a.id),
    );
}

test "CollisionDetection: detect no collisions when circles far apart" {
    const gpa = testing.allocator;
    var world = try World.init(gpa);
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

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 0), collisions.items.len);
}

test "CollisionDetection: detect multiple collisions" {
    const gpa = testing.allocator;
    var world = try World.init(gpa);
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

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 2), collisions.items.len);
}

test "CollisionDetection: ignore entities without collider" {
    const gpa = testing.allocator;
    var world = try World.init(gpa);
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

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 0), collisions.items.len);
}

// MARK: Normal Convention Tests
//
// Convention (brickles-readiness-plan Phase 2A): the collision normal points
// from the first collider (A / entity_a) toward the second (B / entity_b).
//
// circle-circle and rect-rect already comply — those tests guard against
// overcorrection. The circle-rect cases are RED until
// collideCircleColliderRectangleCollider negates its normal (it currently
// returns B→A, the odd one out).

const eps = 0.0001;

test "CollisionDetection: circle-circle normal points from A toward B" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideCircleColliderCircleCollider(
        circle_a,
        transform_a,
        circle_b,
        transform_b,
    ) orelse return error.ExpectedCollision;

    // B is to the right of A: A→B is +x
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.normal.y, eps);
    try testing.expectApproxEqAbs(@as(f32, 3.0), hit.penetration, eps);
}

test "CollisionDetection: circle-circle diagonal normal is normalized A toward B" {
    const circle_a = CircleCollider{ .radius = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const circle_b = CircleCollider{ .radius = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 3, .y = 4 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideCircleColliderCircleCollider(
        circle_a,
        transform_a,
        circle_b,
        transform_b,
    ) orelse return error.ExpectedCollision;

    // B offset (3,4) from A, dist 5: A→B is (0.6, 0.8), unit length
    try testing.expectApproxEqAbs(@as(f32, 0.6), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.8), hit.normal.y, eps);
}

test "CollisionDetection: rect-rect horizontal normal points from A toward B" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect_b = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_b = Transform{ .position = V2{ .x = 7, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideRectangleColliderRectangleCollider(
        rect_a,
        transform_a,
        rect_b,
        transform_b,
    ) orelse return error.ExpectedCollision;

    // B is to the right of A: A→B is +x
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.normal.y, eps);
    try testing.expectApproxEqAbs(@as(f32, 3.0), hit.penetration, eps);
}

test "CollisionDetection: rect-rect vertical normals point from A toward B" {
    const rect_a = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_a = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    // B above A: A→B is +y
    const rect_above = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_above = Transform{ .position = V2{ .x = 0, .y = 7 }, .scale = 1.0, .rotation = 0 };

    const hit_above = CollisionDetectionSys.collideRectangleColliderRectangleCollider(
        rect_a,
        transform_a,
        rect_above,
        transform_above,
    ) orelse return error.ExpectedCollision;
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit_above.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit_above.normal.y, eps);

    // B below A: A→B is -y
    const rect_below = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_below = Transform{ .position = V2{ .x = 0, .y = -7 }, .scale = 1.0, .rotation = 0 };

    const hit_below = CollisionDetectionSys.collideRectangleColliderRectangleCollider(
        rect_a,
        transform_a,
        rect_below,
        transform_below,
    ) orelse return error.ExpectedCollision;
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit_below.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -1.0), hit_below.normal.y, eps);
}

test "CollisionDetection: circle-rect side approach normal points from A toward B" {
    // circle (A) sits left of the rect (B), overlapping its left face
    const circle = CircleCollider{ .radius = 2.0 };
    const transform_circle = Transform{ .position = V2{ .x = -6, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideCircleColliderRectangleCollider(
        circle,
        transform_circle,
        rect,
        transform_rect,
    ) orelse return error.ExpectedCollision;

    // RED until Phase 2A: current code returns B→A (-x)
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.normal.y, eps);

    // contact point on the rect's left face; penetration = radius - distance
    try testing.expectApproxEqAbs(@as(f32, -5.0), hit.point.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.point.y, eps);
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit.penetration, eps);
}

test "CollisionDetection: circle-rect top approach normal points from A toward B" {
    // circle (A) sits above the rect (B), overlapping its top face
    const circle = CircleCollider{ .radius = 2.0 };
    const transform_circle = Transform{ .position = V2{ .x = 0, .y = 6.5 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideCircleColliderRectangleCollider(
        circle,
        transform_circle,
        rect,
        transform_rect,
    ) orelse return error.ExpectedCollision;

    // RED until Phase 2A: current code returns B→A (+y)
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -1.0), hit.normal.y, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.5), hit.penetration, eps);
}

test "CollisionDetection: circle-rect deep overlap normal points from A toward B" {
    // circle center (A) is INSIDE the rect (B), nearest to its left face —
    // exercises the degenerate dist≈0 branch
    const circle = CircleCollider{ .radius = 1.0 };
    const transform_circle = Transform{ .position = V2{ .x = -4, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const rect = RectangleCollider{ .half_width = 5.0, .half_height = 5.0 };
    const transform_rect = Transform{ .position = V2{ .x = 0, .y = 0 }, .scale = 1.0, .rotation = 0 };

    const hit = CollisionDetectionSys.collideCircleColliderRectangleCollider(
        circle,
        transform_circle,
        rect,
        transform_rect,
    ) orelse return error.ExpectedCollision;

    // RED until Phase 2A: current code returns the outward face normal (-x);
    // under the A→B convention it must point into the rect (+x)
    try testing.expectApproxEqAbs(@as(f32, 1.0), hit.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), hit.normal.y, eps);
}

test "CollisionDetection: rect-circle reverse dispatch keeps A toward B convention" {
    // rect created FIRST so it becomes entity_a; circle overlaps its right face.
    // Exercises the tryCallCollision reverse path (rect-circle has no direct
    // function, so it calls circle-rect and flips the normal back).
    const gpa = testing.allocator;
    var world = try World.init(gpa);
    defer world.deinit();

    const rect_entity = try world.createEntity();
    try world.addComponent(rect_entity, Transform, Transform{
        .position = V2{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(rect_entity, Collider, Collider{
        .collider = ColliderData{ .RectangleCollider = .{ .half_width = 5.0, .half_height = 5.0 } },
    });

    const circle_entity = try world.createEntity();
    try world.addComponent(circle_entity, Transform, Transform{
        .position = V2{ .x = 6, .y = 0 },
        .rotation = 0,
        .scale = 1.0,
    });
    try world.addComponent(circle_entity, Collider, Collider{
        .collider = ColliderData{ .CircleCollider = .{ .radius = 2.0 } },
    });

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 1), collisions.items.len);
    const collision = collisions.items[0];

    // insertion order makes the rect entity_a
    try testing.expectEqual(rect_entity.id, collision.entity_a.id);
    try testing.expectEqual(circle_entity.id, collision.entity_b.id);

    // RED until Phase 2A: A(rect)→B(circle) is +x toward the circle on the right
    try testing.expectApproxEqAbs(@as(f32, 1.0), collision.normal.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 0.0), collision.normal.y, eps);
}

test "CollisionDetection: collision events contain correct entity IDs" {
    const gpa = testing.allocator;
    var world = try World.init(gpa);
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

    var collisions: std.ArrayList(CollisionDetectionSys.Collision) = .empty;
    defer collisions.deinit(gpa);

    try CollisionDetectionSys.detectCollisions(&world, &collisions, testing.allocator);

    try testing.expectEqual(@as(usize, 1), collisions.items.len);
    const collision = collisions.items[0];

    const found_a = collision.entity_a.id == entity_a.id or collision.entity_b.id == entity_a.id;
    const found_b = collision.entity_a.id == entity_b.id or collision.entity_b.id == entity_b.id;
    try testing.expect(found_a);
    try testing.expect(found_b);
}
