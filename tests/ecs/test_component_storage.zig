const std = @import("std");
const testing = std.testing;

// Mock the ecs.zig import for testing
const ComponentStorage = @import("ComponentStorage").ComponentStorage;

// Simple test components
const Position = struct {
    x: f32,
    y: f32,
};

const Velocity = struct {
    dx: f32,
    dy: f32,
};

test "ComponentStorage - basic add and get" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    // Add component for entity 0
    try storage.add(0, .{ .x = 1.0, .y = 2.0 });

    // Get it back
    const pos = storage.get(0);
    try testing.expect(pos != null);
    try testing.expectEqual(@as(f32, 1.0), pos.?.x);
    try testing.expectEqual(@as(f32, 2.0), pos.?.y);

    // Entity without component returns null
    try testing.expect(storage.get(999) == null);
}

test "ComponentStorage - add duplicate should error" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try storage.add(5, .{ .x = 1.0, .y = 2.0 });

    // Adding again should error
    const result = storage.add(5, .{ .x = 3.0, .y = 4.0 });
    try testing.expectError(error.ComponentAlreadyExists, result);
}

test "ComponentStorage - set overwrites existing" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try storage.add(10, .{ .x = 1.0, .y = 2.0 });

    // Set should overwrite
    try storage.set(10, .{ .x = 5.0, .y = 6.0 });

    const pos = storage.get(10);
    try testing.expectEqual(@as(f32, 5.0), pos.?.x);
    try testing.expectEqual(@as(f32, 6.0), pos.?.y);
}

test "ComponentStorage - set on non-existent entity adds it" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    // Set on entity that doesn't exist should add it
    try storage.set(42, .{ .x = 7.0, .y = 8.0 });

    const pos = storage.get(42);
    try testing.expect(pos != null);
    try testing.expectEqual(@as(f32, 7.0), pos.?.x);
}

test "ComponentStorage - getMutable and modify" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try storage.add(0, .{ .x = 1.0, .y = 2.0 });

    // Get mutable reference and modify
    if (storage.getMut(0)) |pos| {
        pos.x = 99.0;
        pos.y = 100.0;
    }

    // Verify modification
    const pos = storage.get(0);
    try testing.expectEqual(@as(f32, 99.0), pos.?.x);
    try testing.expectEqual(@as(f32, 100.0), pos.?.y);
}

test "ComponentStorage - has" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try testing.expect(!storage.has(5));

    try storage.add(5, .{ .x = 1.0, .y = 2.0 });

    try testing.expect(storage.has(5));
    try testing.expect(!storage.has(999));
}

test "ComponentStorage - remove" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try storage.add(0, .{ .x = 1.0, .y = 2.0 });
    try storage.add(1, .{ .x = 3.0, .y = 4.0 });
    try storage.add(2, .{ .x = 5.0, .y = 6.0 });

    try testing.expect(storage.has(1));

    // Remove middle entity
    storage.remove(1);

    try testing.expect(!storage.has(1));
    try testing.expect(storage.has(0));
    try testing.expect(storage.has(2));

    // Removing again should error
    // try testing.expectError(error.EntityNotFound, storage.remove(1));
}

test "ComponentStorage - remove with swap" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    // Add multiple entities
    try storage.add(10, .{ .x = 10.0, .y = 10.0 });
    try storage.add(20, .{ .x = 20.0, .y = 20.0 });
    try storage.add(30, .{ .x = 30.0, .y = 30.0 });

    // Remove first one (should swap with last)
    storage.remove(10);

    // Verify others still exist and are correct
    const pos20 = storage.get(20);
    const pos30 = storage.get(30);
    try testing.expect(pos20 != null);
    try testing.expect(pos30 != null);
    try testing.expectEqual(@as(f32, 20.0), pos20.?.x);
    try testing.expectEqual(@as(f32, 30.0), pos30.?.x);
}

test "ComponentStorage - clear" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    try storage.add(0, .{ .x = 1.0, .y = 2.0 });
    try storage.add(1, .{ .x = 3.0, .y = 4.0 });

    storage.clear();

    try testing.expect(!storage.has(0));
    try testing.expect(!storage.has(1));
}

test "ComponentStorage - sparse array grows" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    // Add entity with ID beyond initial capacity (1024)
    const big_id = 2000;
    try storage.add(big_id, .{ .x = 99.0, .y = 100.0 });

    const pos = storage.get(big_id);
    try testing.expect(pos != null);
    try testing.expectEqual(@as(f32, 99.0), pos.?.x);
}

test "ComponentStorage - iterator basic" {
    var storage = try ComponentStorage(Velocity).init(testing.allocator);
    defer storage.deinit();

    // Add some components
    try storage.add(5, .{ .dx = 1.0, .dy = 2.0 });
    try storage.add(10, .{ .dx = 3.0, .dy = 4.0 });
    try storage.add(15, .{ .dx = 5.0, .dy = 6.0 });

    var count: usize = 0;
    var iter = storage.iterator();
    while (iter.next()) |entry| {
        count += 1;

        // Verify we can access both entity and component
        try testing.expect(entry.entity.id == 5 or entry.entity.id == 10 or entry.entity.id == 15);
        try testing.expect(entry.component.dx > 0);
        try testing.expect(entry.component.dy > 0);
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "ComponentStorage - iterator order matches insertion" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    // Add in specific order
    try storage.add(100, .{ .x = 1.0, .y = 0.0 });
    try storage.add(200, .{ .x = 2.0, .y = 0.0 });
    try storage.add(300, .{ .x = 3.0, .y = 0.0 });

    var iter = storage.iterator();

    const first = iter.next().?;
    try testing.expectEqual(@as(usize, 100), first.entity.id);
    try testing.expectEqual(@as(f32, 1.0), first.component.x);

    const second = iter.next().?;
    try testing.expectEqual(@as(usize, 200), second.entity.id);
    try testing.expectEqual(@as(f32, 2.0), second.component.x);

    const third = iter.next().?;
    try testing.expectEqual(@as(usize, 300), third.entity.id);
    try testing.expectEqual(@as(f32, 3.0), third.component.x);

    try testing.expect(iter.next() == null);
}

test "ComponentStorage - iterator empty storage" {
    var storage = try ComponentStorage(Position).init(testing.allocator);
    defer storage.deinit();

    var iter = storage.iterator();
    try testing.expect(iter.next() == null);
}

test "ComponentStorage - multiple component types" {
    var positions = try ComponentStorage(Position).init(testing.allocator);
    defer positions.deinit();

    var velocities = try ComponentStorage(Velocity).init(testing.allocator);
    defer velocities.deinit();

    // Entity 0 has both
    try positions.add(0, .{ .x = 10.0, .y = 20.0 });
    try velocities.add(0, .{ .dx = 1.0, .dy = 2.0 });

    // Entity 1 has only position
    try positions.add(1, .{ .x = 30.0, .y = 40.0 });

    // Entity 2 has only velocity
    try velocities.add(2, .{ .dx = 3.0, .dy = 4.0 });

    // Verify
    try testing.expect(positions.has(0));
    try testing.expect(velocities.has(0));
    try testing.expect(positions.has(1));
    try testing.expect(!velocities.has(1));
    try testing.expect(!positions.has(2));
    try testing.expect(velocities.has(2));
}
