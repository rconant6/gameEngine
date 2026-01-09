const std = @import("std");
const testing = std.testing;
const scene_format = @import("scene-format");
const ecs = @import("entity");
const World = ecs.World;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Sprite = ecs.Sprite;
const scene = @import("scene");
const TemplateManager = scene.TemplateManager;
const Template = scene.Template;
const Instantiator = scene.Instantiator;
const asset = @import("asset");
const AssetManager = asset.AssetManager;
const core = @import("core");
const V2 = core.V2;

// These tests document the expected behavior of template instantiation
// They will fail until the template system is implemented

test "TemplateInstantiation: load single template from file" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    try testing.expect(template_manager.hasTemplate("Missile"));
    try testing.expect(template_manager.hasTemplate("Bullet"));
    try testing.expect(template_manager.hasTemplate("Laser"));
}

test "TemplateInstantiation: load all templates from directory" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
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

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
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

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Instantiate missile at position (10, 20)
    const missile = try template_manager.instantiate("Missile", V2{ .x = 10.0, .y = 20.0 });

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

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/enemies.template");

    // Spawn 3 enemies at different positions
    const enemy1 = try template_manager.instantiate("BasicEnemy", V2{ .x = 0.0, .y = 0.0 });
    const enemy2 = try template_manager.instantiate("BasicEnemy", V2{ .x = 10.0, .y = 0.0 });
    const enemy3 = try template_manager.instantiate("BasicEnemy", V2{ .x = 20.0, .y = 0.0 });

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

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/asteroids.template");

    const asteroid = try template_manager.instantiate("LargeAsteroid", V2{ .x = 0.0, .y = 0.0 });

    // Verify Sprite component with polygon geometry
    const sprite = world.getComponent(asteroid, Sprite);
    try testing.expect(sprite != null);
    try testing.expect(sprite.?.geometry != null);

    switch (sprite.?.geometry.?) {
        .Polygon => |poly| {
            // LargeAsteroid has 5 points (pentagon)
            try testing.expectEqual(@as(usize, 5), poly.points.len);
        },
        else => try testing.expect(false),
    }
}

test "TemplateInstantiation: template with tag component" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/enemies.template");

    const enemy = try template_manager.instantiate("BasicEnemy", V2{ .x = 0.0, .y = 0.0 });

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

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/effects.template");

    const particle = try template_manager.instantiate("ExplosionParticle", V2{ .x = 0.0, .y = 0.0 });

    const lifetime = world.getComponent(particle, ecs.Lifetime);
    try testing.expect(lifetime != null);
    try testing.expectEqual(@as(f32, 0.5), lifetime.?.remaining);
}

test "TemplateInstantiation: template not found error" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Try to instantiate non-existent template
    const result = template_manager.instantiate("NonExistentTemplate", V2{ .x = 0.0, .y = 0.0 });

    try testing.expectError(error.TemplateNotFound, result);
}

test "TemplateInstantiation: spawn with offset from action" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/projectiles.template");

    // Simulate spawning from paddle at (0, 500) with offset (0, -30)
    const paddle_pos = V2{ .x = 0.0, .y = 500.0 };
    const spawn_offset = V2{ .x = 0.0, .y = -30.0 };

    const missile = try template_manager.instantiate("Missile", paddle_pos.add(spawn_offset));

    const transform = world.getComponent(missile, Transform).?;
    try testing.expectEqual(@as(f32, 0.0), transform.position.x);
    try testing.expectEqual(@as(f32, 470.0), transform.position.y);
}

test "TemplateInstantiation: asteroid break into smaller asteroids" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplateFile("examples/test_game/assets/templates/asteroids.template");

    // Large asteroid gets destroyed at position (100, 100)
    const large_pos = V2{ .x = 100.0, .y = 100.0 };

    // Spawn two medium asteroids with offsets
    const medium1 = try template_manager.instantiate("MediumAsteroid", V2{ .x = large_pos.x + 10.0, .y = large_pos.y });
    const medium2 = try template_manager.instantiate("MediumAsteroid", V2{ .x = large_pos.x - 10.0, .y = large_pos.y });

    // Both should exist with correct scales
    const t1 = world.getComponent(medium1, Transform).?;
    const t2 = world.getComponent(medium2, Transform).?;

    try testing.expectEqual(@as(f32, 28.0), t1.scale); // Medium scale
    try testing.expectEqual(@as(f32, 28.0), t2.scale);
    try testing.expectEqual(@as(f32, 110.0), t1.position.x);
    try testing.expectEqual(@as(f32, 90.0), t2.position.x);
}

test "TemplateInstantiation: directory load includes all files" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplatesFromDirectory("examples/test_game/assets/templates/");

    // Check templates from asteroids.template
    try testing.expect(template_manager.hasTemplate("LargeAsteroid"));
    try testing.expect(template_manager.hasTemplate("MediumAsteroid"));
    try testing.expect(template_manager.hasTemplate("SmallAsteroid"));

    // Check templates from projectiles.template
    try testing.expect(template_manager.hasTemplate("Missile"));
    try testing.expect(template_manager.hasTemplate("Bullet"));
    try testing.expect(template_manager.hasTemplate("Laser"));

    // Check templates from enemies.template
    try testing.expect(template_manager.hasTemplate("BasicEnemy"));

    // Check templates from effects.template
    try testing.expect(template_manager.hasTemplate("ExplosionParticle"));

    // Check templates from powerups.template
    try testing.expect(template_manager.hasTemplate("HealthPowerup"));

    // Check templates from ship.template
    try testing.expect(template_manager.hasTemplate("PlayerShip"));
}

test "TemplateInstantiation: directory load then instantiate from different files" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplatesFromDirectory("examples/test_game/assets/templates/");

    // Instantiate from projectiles.template
    const missile = try template_manager.instantiate("Missile", V2{ .x = 0.0, .y = 0.0 });
    try testing.expect(missile.id > 0);

    // Instantiate from asteroids.template
    const asteroid = try template_manager.instantiate("LargeAsteroid", V2{ .x = 50.0, .y = 50.0 });
    try testing.expect(asteroid.id > 0);

    // Instantiate from ship.template
    const ship = try template_manager.instantiate("PlayerShip", V2{ .x = 100.0, .y = 100.0 });
    try testing.expect(ship.id > 0);

    // All should have different IDs
    try testing.expect(missile.id != asteroid.id);
    try testing.expect(asteroid.id != ship.id);
    try testing.expect(missile.id != ship.id);
}

test "TemplateInstantiation: directory load empty directory does not error" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    // Loading empty directory should succeed but load nothing
    try template_manager.loadTemplatesFromDirectory("examples/test_game/assets/scenes/");

    // Should not have any templates loaded
    try testing.expect(!template_manager.hasTemplate("Missile"));
    try testing.expect(!template_manager.hasTemplate("LargeAsteroid"));
}

test "TemplateInstantiation: directory load skips non-template files" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var assets = try AssetManager.init(allocator);
    defer assets.deinit();

    var instantiator = Instantiator.init(allocator, &world, &assets);
    defer instantiator.deinit();

    var template_manager = TemplateManager.init(allocator, &instantiator);
    defer template_manager.deinit();

    try template_manager.loadTemplatesFromDirectory("examples/test_game/assets/templates/");

    // Should have loaded .template files
    try testing.expect(template_manager.hasTemplate("Missile"));

    // Should not treat README.md as a template file
    try testing.expect(!template_manager.hasTemplate("README"));
}
