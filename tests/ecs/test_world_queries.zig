const std = @import("std");
const testing = std.testing;
const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Tag = ecs.Tag;

// Test: findEntityByTag - single entity with exact tag match
test "World - findEntityByTag with single match" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // Create entity with "player" tag
    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player" });

    // Create entity with different tag
    const enemy = try world.createEntity();
    try world.addComponent(enemy, Tag, .{ .tags = "enemy" });

    // Find player entity
    const found = world.findEntityByTag("player");
    try testing.expect(found != null);
    try testing.expectEqual(player.id, found.?.id);

    // Find enemy entity
    const found_enemy = world.findEntityByTag("enemy");
    try testing.expect(found_enemy != null);
    try testing.expectEqual(enemy.id, found_enemy.?.id);
}

// Test: findEntityByTag - no match
test "World - findEntityByTag with no match" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Tag, .{ .tags = "npc" });

    const found = world.findEntityByTag("player");
    try testing.expect(found == null);
}

// Test: findEntityByTag - multiple tags on entity
test "World - findEntityByTag with multiple tags on entity" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player,controllable,visible" });

    // Should find by any of the tags
    const found1 = world.findEntityByTag("player");
    try testing.expect(found1 != null);
    try testing.expectEqual(player.id, found1.?.id);

    const found2 = world.findEntityByTag("controllable");
    try testing.expect(found2 != null);
    try testing.expectEqual(player.id, found2.?.id);

    const found3 = world.findEntityByTag("visible");
    try testing.expect(found3 != null);
    try testing.expectEqual(player.id, found3.?.id);
}

// Test: findEntityByTag - returns first match when multiple entities have same tag
test "World - findEntityByTag returns first match" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const enemy1 = try world.createEntity();
    try world.addComponent(enemy1, Tag, .{ .tags = "enemy" });

    const enemy2 = try world.createEntity();
    try world.addComponent(enemy2, Tag, .{ .tags = "enemy" });

    // Should return one of the enemies (likely the first created)
    const found = world.findEntityByTag("enemy");
    try testing.expect(found != null);
    // The found entity should be one of our enemies
    try testing.expect(found.?.id == enemy1.id or found.?.id == enemy2.id);
}

// Test: findEntityByTag - entities without Tag component are ignored
test "World - findEntityByTag ignores entities without Tag component" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // Create entity without Tag component
    _ = try world.createEntity();

    // Create entity with Tag
    const tagged = try world.createEntity();
    try world.addComponent(tagged, Tag, .{ .tags = "tagged" });

    const found = world.findEntityByTag("tagged");
    try testing.expect(found != null);
    try testing.expectEqual(tagged.id, found.?.id);
}

// Test: findEntitiesByTag - multiple entities with same tag
test "World - findEntitiesByTag with multiple matches" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const enemy1 = try world.createEntity();
    try world.addComponent(enemy1, Tag, .{ .tags = "enemy" });

    const enemy2 = try world.createEntity();
    try world.addComponent(enemy2, Tag, .{ .tags = "enemy,grunt" });

    const enemy3 = try world.createEntity();
    try world.addComponent(enemy3, Tag, .{ .tags = "enemy,boss" });

    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player" });

    const entities = world.findEntitiesByTag("enemy");
    defer testing.allocator.free(entities);

    try testing.expectEqual(3, entities.len);

    // Verify all found entities are enemies
    var found_enemy1 = false;
    var found_enemy2 = false;
    var found_enemy3 = false;

    for (entities) |entity| {
        if (entity.id == enemy1.id) found_enemy1 = true;
        if (entity.id == enemy2.id) found_enemy2 = true;
        if (entity.id == enemy3.id) found_enemy3 = true;
    }

    try testing.expect(found_enemy1);
    try testing.expect(found_enemy2);
    try testing.expect(found_enemy3);
}

// Test: findEntitiesByTag - no matches returns empty slice
test "World - findEntitiesByTag with no matches" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Tag, .{ .tags = "npc" });

    const entities = world.findEntitiesByTag("player");
    defer testing.allocator.free(entities);

    try testing.expectEqual(0, entities.len);
}

// Test: findEntitiesByTag - single match
test "World - findEntitiesByTag with single match" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player" });

    const enemy = try world.createEntity();
    try world.addComponent(enemy, Tag, .{ .tags = "enemy" });

    const entities = world.findEntitiesByTag("player");
    defer testing.allocator.free(entities);

    try testing.expectEqual(1, entities.len);
    try testing.expectEqual(player.id, entities[0].id);
}

// Test: findEntitiesByPattern - prefix wildcard
test "World - findEntitiesByPattern with prefix wildcard" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const grunt = try world.createEntity();
    try world.addComponent(grunt, Tag, .{ .tags = "enemy_grunt" });

    const boss = try world.createEntity();
    try world.addComponent(boss, Tag, .{ .tags = "enemy_boss" });

    const flyer = try world.createEntity();
    try world.addComponent(flyer, Tag, .{ .tags = "enemy_flying" });

    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player" });

    const entities = world.findEntitiesByPattern("enemy*");
    defer testing.allocator.free(entities);

    try testing.expectEqual(3, entities.len);

    // Verify we found all enemy types
    var found_grunt = false;
    var found_boss = false;
    var found_flyer = false;

    for (entities) |entity| {
        if (entity.id == grunt.id) found_grunt = true;
        if (entity.id == boss.id) found_boss = true;
        if (entity.id == flyer.id) found_flyer = true;
    }

    try testing.expect(found_grunt);
    try testing.expect(found_boss);
    try testing.expect(found_flyer);
}

// Test: findEntitiesByPattern - suffix wildcard
test "World - findEntitiesByPattern with suffix wildcard" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const mini_boss = try world.createEntity();
    try world.addComponent(mini_boss, Tag, .{ .tags = "mini_boss" });

    const final_boss = try world.createEntity();
    try world.addComponent(final_boss, Tag, .{ .tags = "final_boss" });

    const grunt = try world.createEntity();
    try world.addComponent(grunt, Tag, .{ .tags = "enemy_grunt" });

    const entities = world.findEntitiesByPattern("*_boss");
    defer testing.allocator.free(entities);

    try testing.expectEqual(2, entities.len);

    // Verify we found both boss types
    var found_mini = false;
    var found_final = false;

    for (entities) |entity| {
        if (entity.id == mini_boss.id) found_mini = true;
        if (entity.id == final_boss.id) found_final = true;
    }

    try testing.expect(found_mini);
    try testing.expect(found_final);
}

// Test: findEntitiesByPattern - exact match (no wildcard)
test "World - findEntitiesByPattern with exact match" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player" });

    const player2 = try world.createEntity();
    try world.addComponent(player2, Tag, .{ .tags = "player2" });

    const entities = world.findEntitiesByPattern("player");
    defer testing.allocator.free(entities);

    try testing.expectEqual(1, entities.len);
    try testing.expectEqual(player.id, entities[0].id);
}

// Test: findEntitiesByPattern - no matches
test "World - findEntitiesByPattern with no matches" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity = try world.createEntity();
    try world.addComponent(entity, Tag, .{ .tags = "npc" });

    const entities = world.findEntitiesByPattern("enemy*");
    defer testing.allocator.free(entities);

    try testing.expectEqual(0, entities.len);
}

// Test: findEntitiesByPattern - entity with multiple tags, one matches pattern
test "World - findEntitiesByPattern with multiple tags per entity" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const entity1 = try world.createEntity();
    try world.addComponent(entity1, Tag, .{ .tags = "enemy_grunt,hostile,ai_controlled" });

    const entity2 = try world.createEntity();
    try world.addComponent(entity2, Tag, .{ .tags = "enemy_boss,hostile,tough" });

    const entity3 = try world.createEntity();
    try world.addComponent(entity3, Tag, .{ .tags = "player,friendly" });

    // Find all entities with "enemy*" pattern
    const enemies = world.findEntitiesByPattern("enemy*");
    defer testing.allocator.free(enemies);

    try testing.expectEqual(2, enemies.len);

    // Find all entities with "*hostile*" pattern
    const hostiles = world.findEntitiesByPattern("*hostile");
    defer testing.allocator.free(hostiles);

    try testing.expectEqual(2, hostiles.len);
}

// Test: Complex scenario with all three functions
test "World - comprehensive query scenario" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    // Create a player
    const player = try world.createEntity();
    try world.addComponent(player, Tag, .{ .tags = "player,controllable" });

    // Create multiple enemy types
    const grunt1 = try world.createEntity();
    try world.addComponent(grunt1, Tag, .{ .tags = "enemy_grunt,hostile" });

    const grunt2 = try world.createEntity();
    try world.addComponent(grunt2, Tag, .{ .tags = "enemy_grunt,hostile" });

    const boss = try world.createEntity();
    try world.addComponent(boss, Tag, .{ .tags = "enemy_boss,hostile,tough" });

    // Create collectibles
    const coin = try world.createEntity();
    try world.addComponent(coin, Tag, .{ .tags = "collectible_coin" });

    const powerup = try world.createEntity();
    try world.addComponent(powerup, Tag, .{ .tags = "collectible_powerup" });

    // Test findEntityByTag - find the player
    const found_player = world.findEntityByTag("player");
    try testing.expect(found_player != null);
    try testing.expectEqual(player.id, found_player.?.id);

    // Test findEntitiesByTag - find all hostile entities
    const hostiles = world.findEntitiesByTag("hostile");
    defer testing.allocator.free(hostiles);
    try testing.expectEqual(3, hostiles.len);

    // Test findEntitiesByPattern - find all enemies
    const enemies = world.findEntitiesByPattern("enemy*");
    defer testing.allocator.free(enemies);
    try testing.expectEqual(3, enemies.len);

    // Test findEntitiesByPattern - find all collectibles
    const collectibles = world.findEntitiesByPattern("collectible*");
    defer testing.allocator.free(collectibles);
    try testing.expectEqual(2, collectibles.len);

    // Test findEntitiesByTag - find specific enemy type
    const grunts = world.findEntitiesByTag("enemy_grunt");
    defer testing.allocator.free(grunts);
    try testing.expectEqual(2, grunts.len);
}
