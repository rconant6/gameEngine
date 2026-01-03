const std = @import("std");
const testing = std.testing;
const collider = @import("collider");
const ColliderShape = collider.ColliderShape;
const Collider = collider.Collider;

test "ColliderShape: circle creation" {
    const shape = ColliderShape{ .circle = .{ .radius = 5.0 } };

    switch (shape) {
        .circle => |c| try testing.expectEqual(@as(f32, 5.0), c.radius),
        .rectangle => try testing.expect(false),
    }
}

test "ColliderShape: circle with zero radius" {
    const shape = ColliderShape{ .circle = .{ .radius = 0.0 } };

    switch (shape) {
        .circle => |c| try testing.expectEqual(@as(f32, 0.0), c.radius),
        .rectangle => try testing.expect(false),
    }
}

test "ColliderShape: circle with large radius" {
    const shape = ColliderShape{ .circle = .{ .radius = 1000.0 } };

    switch (shape) {
        .circle => |c| try testing.expectEqual(@as(f32, 1000.0), c.radius),
        .rectangle => try testing.expect(false),
    }
}

test "ColliderShape: rectangle creation" {
    const shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 20.0 } };

    switch (shape) {
        .circle => try testing.expect(false),
        .rectangle => |r| {
            try testing.expectEqual(@as(f32, 10.0), r.half_w);
            try testing.expectEqual(@as(f32, 20.0), r.half_h);
        },
    }
}

test "ColliderShape: rectangle with equal dimensions (square)" {
    const shape = ColliderShape{ .rectangle = .{ .half_w = 15.0, .half_h = 15.0 } };

    switch (shape) {
        .circle => try testing.expect(false),
        .rectangle => |r| {
            try testing.expectEqual(@as(f32, 15.0), r.half_w);
            try testing.expectEqual(@as(f32, 15.0), r.half_h);
        },
    }
}

test "ColliderShape: rectangle with zero dimensions" {
    const shape = ColliderShape{ .rectangle = .{ .half_w = 0.0, .half_h = 0.0 } };

    switch (shape) {
        .circle => try testing.expect(false),
        .rectangle => |r| {
            try testing.expectEqual(@as(f32, 0.0), r.half_w);
            try testing.expectEqual(@as(f32, 0.0), r.half_h);
        },
    }
}

test "ColliderShape: rectangle with asymmetric dimensions" {
    const shape = ColliderShape{ .rectangle = .{ .half_w = 5.0, .half_h = 50.0 } };

    switch (shape) {
        .circle => try testing.expect(false),
        .rectangle => |r| {
            try testing.expectEqual(@as(f32, 5.0), r.half_w);
            try testing.expectEqual(@as(f32, 50.0), r.half_h);
        },
    }
}

test "Collider: creation with circle shape" {
    const c = Collider{ .shape = ColliderShape{ .circle = .{ .radius = 5.0 } } };

    try testing.expect(c.shape != null);
    if (c.shape) |shape| {
        switch (shape) {
            .circle => |circle| try testing.expectEqual(@as(f32, 5.0), circle.radius),
            .rectangle => try testing.expect(false),
        }
    }
}

test "Collider: creation with rectangle shape" {
    const c = Collider{ .shape = ColliderShape{ .rectangle = .{ .half_w = 10.0, .half_h = 15.0 } } };

    try testing.expect(c.shape != null);
    if (c.shape) |shape| {
        switch (shape) {
            .circle => try testing.expect(false),
            .rectangle => |rect| {
                try testing.expectEqual(@as(f32, 10.0), rect.half_w);
                try testing.expectEqual(@as(f32, 15.0), rect.half_h);
            },
        }
    }
}

test "Collider: creation with null shape" {
    const c = Collider{ .shape = null };
    try testing.expect(c.shape == null);
}

test "Collider: shape modification from null to circle" {
    var c = Collider{ .shape = null };
    try testing.expect(c.shape == null);

    c.shape = ColliderShape{ .circle = .{ .radius = 7.5 } };
    try testing.expect(c.shape != null);

    if (c.shape) |shape| {
        switch (shape) {
            .circle => |circle| try testing.expectEqual(@as(f32, 7.5), circle.radius),
            .rectangle => try testing.expect(false),
        }
    }
}

test "Collider: shape modification from circle to rectangle" {
    var c = Collider{ .shape = ColliderShape{ .circle = .{ .radius = 5.0 } } };

    c.shape = ColliderShape{ .rectangle = .{ .half_w = 8.0, .half_h = 12.0 } };

    if (c.shape) |shape| {
        switch (shape) {
            .circle => try testing.expect(false),
            .rectangle => |rect| {
                try testing.expectEqual(@as(f32, 8.0), rect.half_w);
                try testing.expectEqual(@as(f32, 12.0), rect.half_h);
            },
        }
    }
}

test "ColliderShape: union size" {
    // Verify the union is reasonably sized
    const size = @sizeOf(ColliderShape);
    // Should be tag + largest variant
    try testing.expect(size > 0);
    try testing.expect(size <= 16); // Reasonable upper bound
}

test "Collider: array of colliders with different shapes" {
    const colliders = [_]Collider{
        Collider{ .shape = ColliderShape{ .circle = .{ .radius = 1.0 } } },
        Collider{ .shape = ColliderShape{ .rectangle = .{ .half_w = 2.0, .half_h = 3.0 } } },
        Collider{ .shape = null },
        Collider{ .shape = ColliderShape{ .circle = .{ .radius = 4.0 } } },
    };

    try testing.expectEqual(@as(usize, 4), colliders.len);

    // Verify first is circle
    if (colliders[0].shape) |shape| {
        switch (shape) {
            .circle => |c| try testing.expectEqual(@as(f32, 1.0), c.radius),
            .rectangle => try testing.expect(false),
        }
    }

    // Verify second is rectangle
    if (colliders[1].shape) |shape| {
        switch (shape) {
            .circle => try testing.expect(false),
            .rectangle => |r| {
                try testing.expectEqual(@as(f32, 2.0), r.half_w);
                try testing.expectEqual(@as(f32, 3.0), r.half_h);
            },
        }
    }

    // Verify third is null
    try testing.expect(colliders[2].shape == null);

    // Verify fourth is circle
    if (colliders[3].shape) |shape| {
        switch (shape) {
            .circle => |c| try testing.expectEqual(@as(f32, 4.0), c.radius),
            .rectangle => try testing.expect(false),
        }
    }
}
