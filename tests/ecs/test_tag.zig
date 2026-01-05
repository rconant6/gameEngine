const std = @import("std");
const testing = std.testing;
const Tag = @import("Tag");

test "Tag - hasTag exact match" {
    const tag = Tag{
        .names = &[_][]const u8{ "player", "controllable", "visible" },
    };

    try testing.expect(tag.hasTag("player"));
    try testing.expect(tag.hasTag("controllable"));
    try testing.expect(tag.hasTag("visible"));
    try testing.expect(!tag.hasTag("enemy"));
    try testing.expect(!tag.hasTag(""));
}

test "Tag - matchesPattern exact match" {
    const tag = Tag{
        .names = &[_][]const u8{ "brick", "destructible" },
    };

    try testing.expect(tag.matchesPattern("brick"));
    try testing.expect(tag.matchesPattern("destructible"));
    try testing.expect(!tag.matchesPattern("player"));
    try testing.expect(!tag.matchesPattern(""));
}

test "Tag - matchesPattern prefix wildcard" {
    const tag = Tag{
        .names = &[_][]const u8{ "enemy_grunt", "enemy_boss", "powerup" },
    };

    // Prefix wildcard should match
    try testing.expect(tag.matchesPattern("enemy*"));
    try testing.expect(tag.matchesPattern("enemy_*"));
    try testing.expect(tag.matchesPattern("powerup*"));

    // Should not match
    try testing.expect(!tag.matchesPattern("player*"));
    try testing.expect(!tag.matchesPattern("boss*"));
}

test "Tag - matchesPattern suffix wildcard" {
    const tag = Tag{
        .names = &[_][]const u8{ "mini_boss", "final_boss", "player" },
    };

    // Suffix wildcard should match
    try testing.expect(tag.matchesPattern("*_boss"));
    try testing.expect(tag.matchesPattern("*boss"));
    try testing.expect(tag.matchesPattern("*player"));

    // Should not match
    try testing.expect(!tag.matchesPattern("*enemy"));
    try testing.expect(!tag.matchesPattern("*grunt"));
}

test "Tag - matchesPattern mixed scenarios" {
    const tag = Tag{
        .names = &[_][]const u8{ "enemy_flying_boss", "collectible_coin" },
    };

    // Exact matches
    try testing.expect(tag.matchesPattern("enemy_flying_boss"));
    try testing.expect(tag.matchesPattern("collectible_coin"));

    // Prefix wildcards
    try testing.expect(tag.matchesPattern("enemy*"));
    try testing.expect(tag.matchesPattern("collectible*"));

    // Suffix wildcards
    try testing.expect(tag.matchesPattern("*_boss"));
    try testing.expect(tag.matchesPattern("*_coin"));

    // Should not match
    try testing.expect(!tag.matchesPattern("player*"));
    try testing.expect(!tag.matchesPattern("*brick"));
}

test "Tag - empty tag list" {
    const tag = Tag{
        .names = &[_][]const u8{},
    };

    try testing.expect(!tag.hasTag("anything"));
    try testing.expect(!tag.matchesPattern("anything"));
    try testing.expect(!tag.matchesPattern("*wildcard"));
    try testing.expect(!tag.matchesPattern("wildcard*"));
}

test "Tag - single tag" {
    const tag = Tag{
        .names = &[_][]const u8{"solo"},
    };

    try testing.expect(tag.hasTag("solo"));
    try testing.expect(tag.matchesPattern("solo"));
    try testing.expect(tag.matchesPattern("sol*"));
    try testing.expect(tag.matchesPattern("*olo"));
    try testing.expect(!tag.hasTag("other"));
}
