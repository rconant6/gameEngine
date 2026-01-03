const std = @import("std");
const testing = std.testing;

const entity = @import("entity");
const ComponentStorage = entity.ComponentStorage;
const Query = entity.Query;

// Test components
const Position = struct {
    x: f32,
    y: f32,
};

const Velocity = struct {
    dx: f32,
    dy: f32,
};

const Health = struct {
    current: i32,
    max: i32,
};

test "Query - basic two component query" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    // Entity 0: has both
    try positions.add(0, .{ .x = 1.0, .y = 2.0 });
    try velocities.add(0, .{ .dx = 0.1, .dy = 0.2 });

    // Entity 1: has only position
    try positions.add(1, .{ .x = 3.0, .y = 4.0 });

    // Entity 2: has both
    try positions.add(2, .{ .x = 5.0, .y = 6.0 });
    try velocities.add(2, .{ .dx = 0.3, .dy = 0.4 });

    // Entity 3: has only velocity
    try velocities.add(3, .{ .dx = 0.5, .dy = 0.6 });

    // Query for entities with BOTH Position and Velocity
    const storages = .{ &positions, &velocities };
    var query = Query(@TypeOf(storages)).init(storages);

    var count: usize = 0;
    var found_0 = false;
    var found_2 = false;

    while (query.next()) |entry| {
        count += 1;

        // Should only find entities 0 and 2
        try testing.expect(entry.entity.id == 0 or entry.entity.id == 2);

        // Verify we can access both components
        const pos = entry.get(0); // *const Position
        const vel = entry.get(1); // *const Velocity

        try testing.expect(pos.x > 0);
        try testing.expect(vel.dx > 0);

        if (entry.entity.id == 0) found_0 = true;
        if (entry.entity.id == 2) found_2 = true;
    }

    try testing.expectEqual(@as(usize, 2), count);
    try testing.expect(found_0);
    try testing.expect(found_2);
}

test "Query - single component query" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    try positions.add(5, .{ .x = 10.0, .y = 20.0 });
    try positions.add(10, .{ .x = 30.0, .y = 40.0 });
    try positions.add(15, .{ .x = 50.0, .y = 60.0 });

    // Query with just one component type
    const storages = .{&positions};
    var query = Query(@TypeOf(storages)).init(storages);

    var count: usize = 0;
    while (query.next()) |entry| {
        count += 1;
        const pos = entry.get(0);
        try testing.expect(pos.x > 0);
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "Query - three component query" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    var healths = try ComponentStorage(Health).init(testing.allocator);
    defer healths.deinit();

    // Entity 0: has all three
    try positions.add(0, .{ .x = 1.0, .y = 2.0 });
    try velocities.add(0, .{ .dx = 0.1, .dy = 0.2 });
    try healths.add(0, .{ .current = 100, .max = 100 });

    // Entity 1: missing health
    try positions.add(1, .{ .x = 3.0, .y = 4.0 });
    try velocities.add(1, .{ .dx = 0.3, .dy = 0.4 });

    // Entity 2: missing velocity
    try positions.add(2, .{ .x = 5.0, .y = 6.0 });
    try healths.add(2, .{ .current = 50, .max = 100 });

    // Entity 3: has all three
    try positions.add(3, .{ .x = 7.0, .y = 8.0 });
    try velocities.add(3, .{ .dx = 0.5, .dy = 0.6 });
    try healths.add(3, .{ .current = 75, .max = 100 });

    // Query for all three components
    const storages = .{ &positions, &velocities, &healths };
    var query = Query(@TypeOf(storages)).init(storages);

    var count: usize = 0;
    while (query.next()) |entry| {
        count += 1;

        // Should only find entities 0 and 3
        try testing.expect(entry.entity.id == 0 or entry.entity.id == 3);

        const pos = entry.get(0);
        const vel = entry.get(1);
        const health = entry.get(2);

        try testing.expect(pos.x > 0);
        try testing.expect(vel.dx > 0);
        try testing.expect(health.current > 0);
    }

    try testing.expectEqual(@as(usize, 2), count);
}

test "Query - no matching entities" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    // Add components but no entity has both
    try positions.add(0, .{ .x = 1.0, .y = 2.0 });
    try velocities.add(1, .{ .dx = 0.1, .dy = 0.2 });

    const storages = .{ &positions, &velocities };
    var query = Query(@TypeOf(storages)).init(storages);

    var count: usize = 0;
    while (query.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 0), count);
}

test "Query - empty storages" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    // No components added at all
    const storages = .{ &positions, &velocities };
    var query = Query(@TypeOf(storages)).init(storages);

    try testing.expect(query.next() == null);
}

test "Query - iterates smallest storage first" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    // Add many positions
    for (0..100) |i| {
        try positions.add(i, .{ .x = @floatFromInt(i), .y = 0.0 });
    }

    // But only a few velocities (should iterate this one)
    try velocities.add(5, .{ .dx = 1.0, .dy = 1.0 });
    try velocities.add(50, .{ .dx = 2.0, .dy = 2.0 });
    try velocities.add(99, .{ .dx = 3.0, .dy = 3.0 });

    const storages = .{ &positions, &velocities };
    var query = Query(@TypeOf(storages)).init(storages);

    // Should only iterate 3 times (checking velocities, not positions)
    var count: usize = 0;
    while (query.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "Query - component values are correct" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    try positions.add(42, .{ .x = 123.0, .y = 456.0 });
    try velocities.add(42, .{ .dx = 7.0, .dy = 8.0 });

    const storages = .{ &positions, &velocities };
    var query = Query(@TypeOf(storages)).init(storages);

    if (query.next()) |entry| {
        try testing.expectEqual(@as(usize, 42), entry.entity.id);
        try testing.expectEqual(@as(f32, 123.0), entry.get(0).x);
        try testing.expectEqual(@as(f32, 456.0), entry.get(0).y);
        try testing.expectEqual(@as(f32, 7.0), entry.get(1).dx);
        try testing.expectEqual(@as(f32, 8.0), entry.get(1).dy);
    } else {
        try testing.expect(false); // Should have found entity
    }
}

test "Query - multiple iterations" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    try positions.add(0, .{ .x = 1.0, .y = 2.0 });
    try velocities.add(0, .{ .dx = 0.1, .dy = 0.2 });

    const storages = .{ &positions, &velocities };

    // First iteration
    var query1 = Query(@TypeOf(storages)).init(storages);
    var count1: usize = 0;
    while (query1.next()) |_| count1 += 1;

    // Second iteration (should work independently)
    var query2 = Query(@TypeOf(storages)).init(storages);
    var count2: usize = 0;
    while (query2.next()) |_| count2 += 1;

    try testing.expectEqual(count1, count2);
}

test "Query - order independence" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    try positions.add(0, .{ .x = 1.0, .y = 2.0 });
    try velocities.add(0, .{ .dx = 0.1, .dy = 0.2 });

    // Query in different order - should still work
    const storages_a = .{ &positions, &velocities };
    const storages_b = .{ &velocities, &positions };

    var query_a = Query(@TypeOf(storages_a)).init(storages_a);
    var query_b = Query(@TypeOf(storages_b)).init(storages_b);

    const result_a = query_a.next();
    const result_b = query_b.next();

    try testing.expect(result_a != null);
    try testing.expect(result_b != null);
    try testing.expectEqual(result_a.?.entity, result_b.?.entity);
}
