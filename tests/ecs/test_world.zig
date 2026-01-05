const std = @import("std");
const testing = std.testing;
const World = @import("World");
const Entity = @import("entity");

// Test component types
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

test "World - init and deinit" {
    var world = try World.init(testing.allocator);
    defer world.deinit();
}

test "World - create entity" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try testing.expect(entity.id == 1);

    const entity2 = try world.createEntity();
    try testing.expect(entity2.id == 2);
}

test "World - add component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();

    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });
    try testing.expect(world.hasComponent(entity, Position));
}

test "World - get component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });

    const pos = world.getComponent(entity, Position);
    try testing.expect(pos != null);
    try testing.expectEqual(@as(f32, 10.0), pos.?.x);
    try testing.expectEqual(@as(f32, 20.0), pos.?.y);
}

test "World - get mutable component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });

    const pos = world.getComponentMut(entity, Position);
    try testing.expect(pos != null);
    pos.?.x = 100.0;

    const pos2 = world.getComponent(entity, Position);
    try testing.expectEqual(@as(f32, 100.0), pos2.?.x);
}

test "World - has component returns false for missing component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try testing.expect(!world.hasComponent(entity, Position));
}

test "World - get component returns null for missing component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    const pos = world.getComponent(entity, Position);
    try testing.expect(pos == null);
}

test "World - add multiple components to same entity" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });
    try world.addComponent(entity, Velocity, .{ .dx = 1.0, .dy = 2.0 });

    try testing.expect(world.hasComponent(entity, Position));
    try testing.expect(world.hasComponent(entity, Velocity));
}

test "World - remove component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });

    try testing.expect(world.hasComponent(entity, Position));
    world.removeComponent(entity, Position);
    try testing.expect(!world.hasComponent(entity, Position));
}

test "World - multiple entities with same component type" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });
    try world.addComponent(e2, Position, .{ .x = 2.0, .y = 2.0 });
    try world.addComponent(e3, Position, .{ .x = 3.0, .y = 3.0 });

    const p1 = world.getComponent(e1, Position).?;
    const p2 = world.getComponent(e2, Position).?;
    const p3 = world.getComponent(e3, Position).?;

    try testing.expectEqual(@as(f32, 1.0), p1.x);
    try testing.expectEqual(@as(f32, 2.0), p2.x);
    try testing.expectEqual(@as(f32, 3.0), p3.x);
}

test "World - query single component type" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });
    try world.addComponent(e2, Position, .{ .x = 2.0, .y = 2.0 });
    // e3 has no Position
    _ = e3;

    var query = world.query(.{Position});
    var count: usize = 0;

    while (query.next()) |entry| {
        const pos = entry.get(0);
        try testing.expect(pos.x > 0.0);
        count += 1;
    }

    try testing.expectEqual(@as(usize, 2), count);
}

test "World - query multiple component types" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });
    try world.addComponent(e1, Velocity, .{ .dx = 10.0, .dy = 10.0 });

    try world.addComponent(e2, Position, .{ .x = 2.0, .y = 2.0 });
    try world.addComponent(e2, Velocity, .{ .dx = 20.0, .dy = 20.0 });

    try world.addComponent(e3, Position, .{ .x = 3.0, .y = 3.0 });
    // e3 has Position but not Velocity

    var query = world.query(.{ Position, Velocity });
    var count: usize = 0;

    while (query.next()) |entry| {
        const pos = entry.get(0);
        const vel = entry.get(1);
        try testing.expect(pos.x > 0.0);
        try testing.expect(vel.dx > 0.0);
        count += 1;
    }

    try testing.expectEqual(@as(usize, 2), count); // Only e1 and e2
}

test "World - query with three component types" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });
    try world.addComponent(e1, Velocity, .{ .dx = 10.0, .dy = 10.0 });
    try world.addComponent(e1, Health, .{ .current = 100, .max = 100 });

    try world.addComponent(e2, Position, .{ .x = 2.0, .y = 2.0 });
    try world.addComponent(e2, Velocity, .{ .dx = 20.0, .dy = 20.0 });
    // e2 missing Health

    var query = world.query(.{ Position, Velocity, Health });
    var count: usize = 0;

    while (query.next()) |entry| {
        const pos = entry.get(0);
        const vel = entry.get(1);
        const health = entry.get(2);
        try testing.expect(pos.x > 0.0);
        try testing.expect(vel.dx > 0.0);
        try testing.expect(health.current > 0);
        count += 1;
    }

    try testing.expectEqual(@as(usize, 1), count); // Only e1
}

test "World - modify components through query" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 0.0, .y = 0.0 });
    try world.addComponent(e1, Velocity, .{ .dx = 1.0, .dy = 2.0 });

    try world.addComponent(e2, Position, .{ .x = 10.0, .y = 10.0 });
    try world.addComponent(e2, Velocity, .{ .dx = -1.0, .dy = -2.0 });

    // Simulate movement system
    var query = world.query(.{ Position, Velocity });
    while (query.next()) |*entry| {
        const pos = entry.get(0); // *Position (mutable)
        const vel = entry.get(1); // *const Velocity
        pos.x += vel.dx;
        pos.y += vel.dy;
    }

    const p1 = world.getComponent(e1, Position).?;
    const p2 = world.getComponent(e2, Position).?;

    try testing.expectEqual(@as(f32, 1.0), p1.x);
    try testing.expectEqual(@as(f32, 2.0), p1.y);
    try testing.expectEqual(@as(f32, 9.0), p2.x);
    try testing.expectEqual(@as(f32, 8.0), p2.y);
}

test "World - destroy entity removes all components" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });
    try world.addComponent(entity, Velocity, .{ .dx = 1.0, .dy = 2.0 });
    try world.addComponent(entity, Health, .{ .current = 100, .max = 100 });

    try testing.expect(world.hasComponent(entity, Position));
    try testing.expect(world.hasComponent(entity, Velocity));
    try testing.expect(world.hasComponent(entity, Health));

    world.destroyEntity(entity);

    try testing.expect(!world.hasComponent(entity, Position));
    try testing.expect(!world.hasComponent(entity, Velocity));
    try testing.expect(!world.hasComponent(entity, Health));
}

test "World - query after entity destruction" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    const e2 = try world.createEntity();
    const e3 = try world.createEntity();

    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });
    try world.addComponent(e2, Position, .{ .x = 2.0, .y = 2.0 });
    try world.addComponent(e3, Position, .{ .x = 3.0, .y = 3.0 });

    world.destroyEntity(e2);

    var query = world.query(.{Position});
    var count: usize = 0;
    while (query.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 2), count);
}

test "World - add duplicate component returns error" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Position, .{ .x = 10.0, .y = 20.0 });

    const result = world.addComponent(entity, Position, .{ .x = 30.0, .y = 40.0 });
    try testing.expectError(error.ComponentAlreadyExists, result);
}

test "World - empty query returns nothing" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const e1 = try world.createEntity();
    try world.addComponent(e1, Position, .{ .x = 1.0, .y = 1.0 });

    var query = world.query(.{Velocity}); // No entities have Velocity
    var count: usize = 0;
    while (query.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 0), count);
}
