const std = @import("std");
const testing = std.testing;

const scene = @import("scene-format");
const Parser = scene.Parser;
const SceneFile = scene.SceneFile;
const Declaration = scene.Declaration;
const Value = scene.Value;

fn parseSource(allocator: std.mem.Allocator, src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(allocator, src, "test.scene");
    return try parser.parse();
}

fn freeSceneFile(scene_file: *SceneFile, allocator: std.mem.Allocator) void {
    scene_file.deinit(allocator);
}

// MARK: Nested Block Tests for Entities

test "parser - entity with OnCollision nested blocks" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Ball:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [OnCollision]
        \\      [Trigger]
        \\        other_tag_pattern:string "brick"
        \\        [Action]
        \\          type:action destroy_other
        \\          priority:i32 0
        \\        [Action]
        \\          type:action play_sound
        \\          sound_name:string "hit"
        \\          priority:i32 1
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const scene_decl = result.decls[0].scene;
    try testing.expectEqual(@as(usize, 1), scene_decl.decls.len);

    const entity_decl = scene_decl.decls[0].entity;
    try testing.expectEqualStrings("Ball", entity_decl.name);

    // Find OnCollision component
    var has_oncollision = false;
    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnCollision")) {
                    has_oncollision = true;

                    // Should have 1 Trigger nested block
                    try testing.expect(g.nested_blocks != null);
                    try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                    const trigger = g.nested_blocks.?[0];
                    try testing.expectEqualStrings("Trigger", trigger.name);

                    // Trigger should have 2 Action nested blocks
                    try testing.expect(trigger.nested_blocks != null);
                    try testing.expectEqual(@as(usize, 2), trigger.nested_blocks.?.len);

                    try testing.expectEqualStrings("Action", trigger.nested_blocks.?[0].name);
                    try testing.expectEqualStrings("Action", trigger.nested_blocks.?[1].name);
                }
            },
            else => {},
        }
    }
    try testing.expect(has_oncollision);
}

test "parser - entity with OnInput nested blocks" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Paddle:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [OnInput]
        \\      [Trigger]
        \\        input:key Left
        \\        [Action]
        \\          type:action set_velocity
        \\          target:action_target self
        \\          velocity:vec2 {-300.0, 0.0}
        \\          priority:i32 0
        \\      [Trigger]
        \\        input:key Right
        \\        [Action]
        \\          type:action set_velocity
        \\          target:action_target self
        \\          velocity:vec2 {300.0, 0.0}
        \\          priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    // Find OnInput component
    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnInput")) {
                    // Should have 2 Trigger blocks
                    try testing.expect(g.nested_blocks != null);
                    try testing.expectEqual(@as(usize, 2), g.nested_blocks.?.len);

                    // Each trigger should have 1 Action
                    for (g.nested_blocks.?) |trigger| {
                        try testing.expectEqualStrings("Trigger", trigger.name);
                        try testing.expect(trigger.nested_blocks != null);
                        try testing.expectEqual(@as(usize, 1), trigger.nested_blocks.?.len);
                        try testing.expectEqualStrings("Action", trigger.nested_blocks.?[0].name);
                    }
                }
            },
            else => {},
        }
    }
}

test "parser - entity with multiple OnCollision triggers" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Ball:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [OnCollision]
        \\      [Trigger]
        \\        other_tag_pattern:string "brick"
        \\        [Action]
        \\          type:action destroy_other
        \\          priority:i32 0
        \\      [Trigger]
        \\        other_tag_pattern:string "paddle"
        \\        [Action]
        \\          type:action set_velocity
        \\          target:action_target self
        \\          velocity:vec2 {200.0, -200.0}
        \\          priority:i32 0
        \\      [Trigger]
        \\        other_tag_pattern:string "wall"
        \\        [Action]
        \\          type:action set_velocity
        \\          target:action_target self
        \\          velocity:vec2 {-100.0, 100.0}
        \\          priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    // Find OnCollision component
    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnCollision")) {
                    // Should have 3 Trigger blocks
                    try testing.expect(g.nested_blocks != null);
                    try testing.expectEqual(@as(usize, 3), g.nested_blocks.?.len);

                    // Verify all are Trigger blocks
                    for (g.nested_blocks.?) |trigger| {
                        try testing.expectEqualStrings("Trigger", trigger.name);
                    }
                }
            },
            else => {},
        }
    }
}

test "parser - nested blocks with properties at same level" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Entity:entity]
        \\    [OnInput]
        \\      some_property:f32 123.0
        \\      [Trigger]
        \\        input:key Space
        \\        [Action]
        \\          type:action spawn_entity
        \\          template_name:string "missile"
        \\          offset:vec2 {0.0, -30.0}
        \\          priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    // Find OnInput component
    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnInput")) {
                    // Should have both properties and nested blocks
                    try testing.expect(g.properties != null);
                    try testing.expect(g.properties.?.len > 0);
                    try testing.expect(g.nested_blocks != null);
                    try testing.expect(g.nested_blocks.?.len > 0);

                    // Verify property
                    try testing.expectEqualStrings("some_property", g.properties.?[0].name);

                    // Verify nested block
                    try testing.expectEqualStrings("Trigger", g.nested_blocks.?[0].name);
                }
            },
            else => {},
        }
    }
}

test "parser - action with spawn_entity type" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Entity:entity]
        \\    [OnInput]
        \\      [Trigger]
        \\        input:key Space
        \\        [Action]
        \\          type:action spawn_entity
        \\          template_name:string "missile"
        \\          offset:vec2 {0.0, -30.0}
        \\          priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnInput")) {
                    const trigger = g.nested_blocks.?[0];
                    const action = trigger.nested_blocks.?[0];

                    // Verify action has all spawn_entity properties
                    var has_type = false;
                    var has_template = false;
                    var has_offset = false;
                    var has_priority = false;

                    if (action.properties) |props| {
                        for (props) |prop| {
                            if (std.mem.eql(u8, prop.name, "type")) has_type = true;
                            if (std.mem.eql(u8, prop.name, "template_name")) has_template = true;
                            if (std.mem.eql(u8, prop.name, "offset")) has_offset = true;
                            if (std.mem.eql(u8, prop.name, "priority")) has_priority = true;
                        }
                    }

                    try testing.expect(has_type);
                    try testing.expect(has_template);
                    try testing.expect(has_offset);
                    try testing.expect(has_priority);
                }
            },
            else => {},
        }
    }
}

test "parser - action with set_velocity type" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Entity:entity]
        \\    [OnCollision]
        \\      [Trigger]
        \\        other_tag_pattern:string "wall"
        \\        [Action]
        \\          type:action set_velocity
        \\          target:action_target self
        \\          velocity:vec2 {100.0, -100.0}
        \\          priority:i32 5
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "OnCollision")) {
                    const trigger = g.nested_blocks.?[0];
                    const action = trigger.nested_blocks.?[0];

                    // Verify action has all set_velocity properties
                    var has_type = false;
                    var has_target = false;
                    var has_velocity = false;

                    if (action.properties) |props| {
                        for (props) |prop| {
                            if (std.mem.eql(u8, prop.name, "type")) has_type = true;
                            if (std.mem.eql(u8, prop.name, "target")) has_target = true;
                            if (std.mem.eql(u8, prop.name, "velocity")) has_velocity = true;
                        }
                    }

                    try testing.expect(has_type);
                    try testing.expect(has_target);
                    try testing.expect(has_velocity);
                }
            },
            else => {},
        }
    }
}

test "parser - mixed regular and nested components" {
    const src: [:0]const u8 =
        \\[TestScene:scene]
        \\  [Entity:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Velocity]
        \\      linear:vec2 {100.0, 0.0}
        \\      angular:f32 0.5
        \\    [OnCollision]
        \\      [Trigger]
        \\        other_tag_pattern:string "enemy"
        \\        [Action]
        \\          type:action destroy_self
        \\          priority:i32 0
        \\    [Sprite:circle]
        \\      radius:f32 1.0
        \\      fill_color:color #FF0000
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const scene_decl = result.decls[0].scene;
    const entity_decl = scene_decl.decls[0].entity;

    // Should have 4 components
    try testing.expectEqual(@as(usize, 4), entity_decl.components.len);

    // Verify we have both regular components and ones with nested blocks
    var has_transform = false;
    var has_velocity = false;
    var has_sprite = false;
    var has_oncollision_with_nested = false;

    for (entity_decl.components) |comp| {
        switch (comp) {
            .generic => |g| {
                if (std.mem.eql(u8, g.name, "Transform")) has_transform = true;
                if (std.mem.eql(u8, g.name, "Velocity")) has_velocity = true;
                if (std.mem.eql(u8, g.name, "OnCollision")) {
                    if (g.nested_blocks) |blocks| {
                        if (blocks.len > 0) {
                            has_oncollision_with_nested = true;
                        }
                    }
                }
            },
            .sprite => {
                has_sprite = true;
            },
            else => {},
        }
    }

    try testing.expect(has_transform);
    try testing.expect(has_velocity);
    try testing.expect(has_sprite);
    try testing.expect(has_oncollision_with_nested);
}
