const std = @import("std");
const testing = std.testing;
const scene_format = @import("scene-format");
const ecs = @import("entity");
const World = ecs.World;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Sprite = ecs.Sprite;

// These tests document the expected behavior of template instantiation
// They will fail until the template system is implemented

test "TemplateInstantiation: load single template from file" {
    const allocator = testing.allocator;

    // This will fail - TemplateManager doesn't exist yet
    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    try testing.expect(template_manager.hasTemplate("Missile"));
    try testing.expect(template_manager.hasTemplate("Bullet"));
    try testing.expect(template_manager.hasTemplate("Laser"));
}

test "TemplateInstantiation: load all templates from directory" {
    const allocator = testing.allocator;

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplatesFromDirectory("examples/test_game/assets/templates/");

    // Check all template files loaded
    try testing.expect(template_manager.hasTemplate("PlayerShip"));
    try testing.expect(template_manager.hasTemplate("LargeAsteroid"));
    try testing.expect(template_manager.hasTemplate("MediumAsteroid"));
    try testing.expect(template_manager.hasTemplate("SmallAsteroid"));
    try testing.expect(template_manager.hasTemplate("Missile"));
    try testing.expect(template_manager.hasTemplate("BasicEnemy"));
    try testing.expect(template_manager.hasTemplate("ExplosionParticle"));
    try testing.expect(template_manager.hasTemplate("HealthPowerup"));
}

test "TemplateInstantiation: get template by name" {
    const allocator = testing.allocator;

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    const missile_template = template_manager.getTemplate("Missile");
    try testing.expect(missile_template != null);
    try testing.expectEqualStrings("Missile", missile_template.?.name);
}

test "TemplateInstantiation: instantiate entity from template" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Instantiate missile at position (10, 20)
    const missile = try template_manager.instantiate(
        "Missile",
        .{ .x = 10.0, .y = 20.0 },
        &world
    );

    // Verify entity was created
    try testing.expect(missile.id > 0);

    // Verify Transform component exists and position is correct
    const transform = world.getComponent(missile, Transform);
    try testing.expect(transform != null);
    try testing.expectEqual(@as(f32, 10.0), transform.?.position.x);
    try testing.expectEqual(@as(f32, 20.0), transform.?.position.y);

    // Verify Velocity component exists
    const velocity = world.getComponent(missile, Velocity);
    try testing.expect(velocity != null);
    try testing.expectEqual(@as(f32, 0.0), velocity.?.linear.x);
    try testing.expectEqual(@as(f32, -500.0), velocity.?.linear.y);
}

test "TemplateInstantiation: instantiate multiple entities from same template" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/enemies.template");

    // Spawn 3 enemies at different positions
    const enemy1 = try template_manager.instantiate("BasicEnemy", .{ .x = 0.0, .y = 0.0 }, &world);
    const enemy2 = try template_manager.instantiate("BasicEnemy", .{ .x = 10.0, .y = 0.0 }, &world);
    const enemy3 = try template_manager.instantiate("BasicEnemy", .{ .x = 20.0, .y = 0.0 }, &world);

    // All should have different entity IDs
    try testing.expect(enemy1.id != enemy2.id);
    try testing.expect(enemy2.id != enemy3.id);
    try testing.expect(enemy1.id != enemy3.id);

    // All should have Transform at different positions
    const t1 = world.getComponent(enemy1, Transform).?;
    const t2 = world.getComponent(enemy2, Transform).?;
    const t3 = world.getComponent(enemy3, Transform).?;

    try testing.expectEqual(@as(f32, 0.0), t1.position.x);
    try testing.expectEqual(@as(f32, 10.0), t2.position.x);
    try testing.expectEqual(@as(f32, 20.0), t3.position.x);
}

test "TemplateInstantiation: template with polygon sprite" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/asteroids.template");

    const asteroid = try template_manager.instantiate(
        "LargeAsteroid",
        .{ .x = 0.0, .y = 0.0 },
        &world
    );

    // Verify Sprite component with polygon geometry
    const sprite = world.getComponent(asteroid, Sprite);
    try testing.expect(sprite != null);
    try testing.expect(sprite.?.geometry != null);

    switch (sprite.?.geometry.?) {
        .polygon => |poly| {
            // LargeAsteroid has 12 points
            try testing.expectEqual(@as(usize, 12), poly.points.len);
        },
        else => try testing.expect(false),
    }
}

test "TemplateInstantiation: template with tag component" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/enemies.template");

    const enemy = try template_manager.instantiate(
        "BasicEnemy",
        .{ .x = 0.0, .y = 0.0 },
        &world
    );

    const tag = world.getComponent(enemy, ecs.Tag);
    try testing.expect(tag != null);
    try testing.expect(tag.?.hasTag("enemy"));
    try testing.expect(tag.?.hasTag("basic_enemy"));
    try testing.expect(tag.?.hasTag("hostile"));
}

test "TemplateInstantiation: template with lifetime component" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/effects.template");

    const particle = try template_manager.instantiate(
        "ExplosionParticle",
        .{ .x = 0.0, .y = 0.0 },
        &world
    );

    const lifetime = world.getComponent(particle, ecs.Lifetime);
    try testing.expect(lifetime != null);
    try testing.expectEqual(@as(f32, 0.5), lifetime.?.remaining);
}

test "TemplateInstantiation: template not found error" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Try to instantiate non-existent template
    const result = template_manager.instantiate(
        "NonExistentTemplate",
        .{ .x = 0.0, .y = 0.0 },
        &world
    );

    try testing.expectError(error.TemplateNotFound, result);
}

test "TemplateInstantiation: spawn with offset from action" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Simulate spawning from paddle at (0, 500) with offset (0, -30)
    const paddle_pos = .{ .x = 0.0, .y = 500.0 };
    const spawn_offset = .{ .x = 0.0, .y = -30.0 };

    const missile = try template_manager.instantiate(
        "Missile",
        .{
            .x = paddle_pos.x + spawn_offset.x,
            .y = paddle_pos.y + spawn_offset.y
        },
        &world
    );

    const transform = world.getComponent(missile, Transform).?;
    try testing.expectEqual(@as(f32, 0.0), transform.position.x);
    try testing.expectEqual(@as(f32, 470.0), transform.position.y);
}

test "TemplateInstantiation: asteroid break into smaller asteroids" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const template_manager = try TemplateManager.init(allocator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/asteroids.template");

    // Large asteroid gets destroyed at position (100, 100)
    const large_pos = .{ .x = 100.0, .y = 100.0 };

    // Spawn two medium asteroids with offsets
    const medium1 = try template_manager.instantiate(
        "MediumAsteroid",
        .{ .x = large_pos.x + 10.0, .y = large_pos.y },
        &world
    );
    const medium2 = try template_manager.instantiate(
        "MediumAsteroid",
        .{ .x = large_pos.x - 10.0, .y = large_pos.y },
        &world
    );

    // Both should exist with correct scales
    const t1 = world.getComponent(medium1, Transform).?;
    const t2 = world.getComponent(medium2, Transform).?;

    try testing.expectEqual(@as(f32, 28.0), t1.scale); // Medium scale
    try testing.expectEqual(@as(f32, 28.0), t2.scale);
    try testing.expectEqual(@as(f32, 110.0), t1.position.x);
    try testing.expectEqual(@as(f32, 90.0), t2.position.x);
}

// Mock TemplateManager for tests (will be replaced with real implementation)
const TemplateManager = struct {
    // This is a placeholder - will fail to compile
    pub fn init(allocator: std.mem.Allocator) !TemplateManager {
        _ = allocator;
        return error.NotImplemented;
    }

    pub fn deinit(self: *TemplateManager) void {
        _ = self;
    }

    pub fn loadTemplateFile(self: *TemplateManager, path: []const u8) !void {
        _ = self;
        _ = path;
        return error.NotImplemented;
    }

    pub fn loadTemplatesFromDirectory(self: *TemplateManager, dir_path: []const u8) !void {
        _ = self;
        _ = dir_path;
        return error.NotImplemented;
    }

    pub fn hasTemplate(self: *TemplateManager, name: []const u8) bool {
        _ = self;
        _ = name;
        return false;
    }

    pub fn getTemplate(self: *TemplateManager, name: []const u8) ?*const Template {
        _ = self;
        _ = name;
        return null;
    }

    pub fn instantiate(
        self: *TemplateManager,
        name: []const u8,
        position: struct { x: f32, y: f32 },
        world: *World
    ) !ecs.Entity {
        _ = self;
        _ = name;
        _ = position;
        _ = world;
        return error.NotImplemented;
    }
};

const Template = struct {
    name: []const u8,
};
