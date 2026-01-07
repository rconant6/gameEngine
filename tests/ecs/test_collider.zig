const std = @import("std");
const testing = std.testing;
const core = @import("core");
const ColliderData = core.ColliderData;
const ColliderRegistry = core.ColliderRegistry;
const ecs = @import("entity");
const Collider = ecs.Collider;
const CircleCollider = ecs.colliders.CircleCollider;
const RectangleCollider = ecs.colliders.RectangleCollider;

test "ColliderData: circle creation" {
    const circle = CircleCollider{ .radius = 5.0 };
    const shape = ColliderRegistry.createColliderUnion(CircleCollider, circle);

    switch (shape) {
        .CircleCollider => |c| try testing.expectEqual(@as(f32, 5.0), c.radius),
        .RectangleCollider => try testing.expect(false),
    }
}

test "ColliderData: circle with zero radius" {
    const circle = CircleCollider{ .radius = 0.0 };
    const shape = ColliderRegistry.createColliderUnion(CircleCollider, circle);

    switch (shape) {
        .CircleCollider => |c| try testing.expectEqual(@as(f32, 0.0), c.radius),
        .RectangleCollider => try testing.expect(false),
    }
}

test "ColliderData: circle with large radius" {
    const circle = CircleCollider{ .radius = 1000.0 };
    const shape = ColliderRegistry.createColliderUnion(CircleCollider, circle);

    switch (shape) {
        .CircleCollider => |c| try testing.expectEqual(@as(f32, 1000.0), c.radius),
        .RectangleCollider => try testing.expect(false),
    }
}

test "ColliderData: rectangle creation" {
    const rect = RectangleCollider{ .half_w = 10.0, .half_h = 20.0 };
    const shape = ColliderRegistry.createColliderUnion(RectangleCollider, rect);

    switch (shape) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |r| {
            try testing.expectEqual(@as(f32, 10.0), r.half_w);
            try testing.expectEqual(@as(f32, 20.0), r.half_h);
        },
    }
}

test "ColliderData: rectangle with equal dimensions (square)" {
    const rect = RectangleCollider{ .half_w = 15.0, .half_h = 15.0 };
    const shape = ColliderRegistry.createColliderUnion(RectangleCollider, rect);

    switch (shape) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |r| {
            try testing.expectEqual(@as(f32, 15.0), r.half_w);
            try testing.expectEqual(@as(f32, 15.0), r.half_h);
        },
    }
}

test "ColliderData: rectangle with zero dimensions" {
    const rect = RectangleCollider{ .half_w = 0.0, .half_h = 0.0 };
    const shape = ColliderRegistry.createColliderUnion(RectangleCollider, rect);

    switch (shape) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |r| {
            try testing.expectEqual(@as(f32, 0.0), r.half_w);
            try testing.expectEqual(@as(f32, 0.0), r.half_h);
        },
    }
}

test "ColliderData: rectangle with asymmetric dimensions" {
    const rect = RectangleCollider{ .half_w = 5.0, .half_h = 50.0 };
    const shape = ColliderRegistry.createColliderUnion(RectangleCollider, rect);

    switch (shape) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |r| {
            try testing.expectEqual(@as(f32, 5.0), r.half_w);
            try testing.expectEqual(@as(f32, 50.0), r.half_h);
        },
    }
}

test "Collider: creation with circle shape" {
    const circle = CircleCollider{ .radius = 5.0 };
    const shape_data = ColliderRegistry.createColliderUnion(CircleCollider, circle);
    const c = Collider{ .collider = shape_data };

    switch (c.collider) {
        .CircleCollider => |circ| try testing.expectEqual(@as(f32, 5.0), circ.radius),
        .RectangleCollider => try testing.expect(false),
    }
}

test "Collider: creation with rectangle shape" {
    const rect = RectangleCollider{ .half_w = 10.0, .half_h = 15.0 };
    const shape_data = ColliderRegistry.createColliderUnion(RectangleCollider, rect);
    const c = Collider{ .collider = shape_data };

    switch (c.collider) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |rectangle| {
            try testing.expectEqual(@as(f32, 10.0), rectangle.half_w);
            try testing.expectEqual(@as(f32, 15.0), rectangle.half_h);
        },
    }
}

test "Collider: shape modification from circle to rectangle" {
    const circle = CircleCollider{ .radius = 5.0 };
    var c = Collider{ .collider = ColliderRegistry.createColliderUnion(CircleCollider, circle) };

    const rect = RectangleCollider{ .half_w = 8.0, .half_h = 12.0 };
    c.collider = ColliderRegistry.createColliderUnion(RectangleCollider, rect);

    switch (c.collider) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |rectangle| {
            try testing.expectEqual(@as(f32, 8.0), rectangle.half_w);
            try testing.expectEqual(@as(f32, 12.0), rectangle.half_h);
        },
    }
}

test "ColliderData: union size" {
    // Verify the union is reasonably sized
    const size = @sizeOf(ColliderData);
    std.debug.print("size: {d}\n", .{size});
    // Should be tag + largest variant
    try testing.expect(size > 0);
    try testing.expect(size <= 24); // Reasonable upper bound
}

test "Collider: array of colliders with different shapes" {
    const circle1 = CircleCollider{ .radius = 1.0 };
    const rect1 = RectangleCollider{ .half_w = 2.0, .half_h = 3.0 };
    const circle2 = CircleCollider{ .radius = 4.0 };

    const colliders = [_]Collider{
        Collider{ .collider = ColliderRegistry.createColliderUnion(CircleCollider, circle1) },
        Collider{ .collider = ColliderRegistry.createColliderUnion(RectangleCollider, rect1) },
        Collider{ .collider = ColliderRegistry.createColliderUnion(CircleCollider, circle2) },
    };

    try testing.expectEqual(@as(usize, 3), colliders.len);

    // Verify first is circle
    switch (colliders[0].collider) {
        .CircleCollider => |c| try testing.expectEqual(@as(f32, 1.0), c.radius),
        .RectangleCollider => try testing.expect(false),
    }

    // Verify second is rectangle
    switch (colliders[1].collider) {
        .CircleCollider => try testing.expect(false),
        .RectangleCollider => |r| {
            try testing.expectEqual(@as(f32, 2.0), r.half_w);
            try testing.expectEqual(@as(f32, 3.0), r.half_h);
        },
    }

    // Verify third is circle
    switch (colliders[2].collider) {
        .CircleCollider => |c| try testing.expectEqual(@as(f32, 4.0), c.radius),
        .RectangleCollider => try testing.expect(false),
    }
}

test "ColliderRegistry: get collider index" {
    const circle_idx = ColliderRegistry.getColliderIndex("CircleCollider");
    const rect_idx = ColliderRegistry.getColliderIndex("RectangleCollider");

    try testing.expect(circle_idx != null);
    try testing.expect(rect_idx != null);
    try testing.expect(circle_idx.? != rect_idx.?);
}

test "ColliderRegistry: get collider index case insensitive" {
    const idx1 = ColliderRegistry.getColliderIndex("CircleCollider");
    const idx2 = ColliderRegistry.getColliderIndex("circlecollider");
    const idx3 = ColliderRegistry.getColliderIndex("CIRCLECOLLIDER");

    try testing.expect(idx1 != null);
    try testing.expectEqual(idx1.?, idx2.?);
    try testing.expectEqual(idx1.?, idx3.?);
}
