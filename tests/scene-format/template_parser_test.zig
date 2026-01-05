const std = @import("std");
const testing = std.testing;

const scene = @import("scene-format");
const Parser = scene.Parser;
const SceneFile = scene.SceneFile;
const Declaration = scene.Declaration;
const Value = scene.Value;

fn parseSource(allocator: std.mem.Allocator, src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(allocator, src, "test.template");
    return try parser.parse();
}

fn freeSceneFile(scene_file: *SceneFile, allocator: std.mem.Allocator) void {
    scene_file.deinit(allocator);
}

// MARK: Template Declaration Tests

test "parser - parse template declaration" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    // Template should be parsed as a special declaration type
    // This will fail until template support is added to parser
    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("Missile", template_decl.name);
            try testing.expectEqual(@as(usize, 1), template_decl.components.len);
        },
        else => try testing.expect(false), // Will fail - templates not implemented yet
    }
}

test "parser - parse template with multiple components" {
    const src: [:0]const u8 =
        \\[LargeAsteroid:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    scale:f32 35.0
        \\  [Velocity]
        \\    linear:vec2 {0.5, 0.15}
        \\    angular:f32 0.2
        \\  [Sprite:polygon]
        \\    points:vec2[] {{0.2, 0.9}, {0.7, 0.5}}
        \\    fill_color:color #8B4513
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("LargeAsteroid", template_decl.name);
            try testing.expectEqual(@as(usize, 3), template_decl.components.len);
        },
        else => try testing.expect(false),
    }
}

test "parser - parse template with collider and tag" {
    const src: [:0]const u8 =
        \\[Enemy:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Sprite:circle]
        \\    radius:f32 1.0
        \\    fill_color:color #FF0000
        \\  [Collider:circle]
        \\    radius:f32 1.0
        \\  [Tag]
        \\    names:string[] {"enemy", "hostile"}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("Enemy", template_decl.name);
            try testing.expect(template_decl.components.len >= 4);
        },
        else => try testing.expect(false),
    }
}

test "parser - parse template with lifetime component" {
    const src: [:0]const u8 =
        \\[ExplosionParticle:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Sprite:circle]
        \\    radius:f32 0.2
        \\    fill_color:color #FF4500
        \\  [Lifetime]
        \\    remaining:f32 0.5
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("ExplosionParticle", template_decl.name);

            // Should have Lifetime component
            var has_lifetime = false;
            for (template_decl.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "Lifetime")) {
                            has_lifetime = true;
                        }
                    },
                    else => {},
                }
            }
            try testing.expect(has_lifetime);
        },
        else => try testing.expect(false),
    }
}

test "parser - multiple templates in single file" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Velocity]
        \\    linear:vec2 {0.0, -500.0}
        \\
        \\[Bullet:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Velocity]
        \\    linear:vec2 {0.0, -800.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 2), result.decls.len);

    // First template
    switch (result.decls[0]) {
        .template => |t| try testing.expectEqualStrings("Missile", t.name),
        else => try testing.expect(false),
    }

    // Second template
    switch (result.decls[1]) {
        .template => |t| try testing.expectEqualStrings("Bullet", t.name),
        else => try testing.expect(false),
    }
}

test "parser - template with OnCollision nested triggers" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [OnCollision]
        \\    [Trigger]
        \\      other_tag_pattern:string "enemy*"
        \\      [Action]
        \\        type:action destroy_self
        \\        priority:i32 0
        \\      [Action]
        \\        type:action play_sound
        \\        sound_name:string "explosion"
        \\        priority:i32 1
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("Missile", template_decl.name);

            // Should have OnCollision component
            var has_oncollision = false;
            for (template_decl.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnCollision")) {
                            has_oncollision = true;

                            // Should have nested blocks (1 Trigger)
                            try testing.expect(g.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                            const trigger_block = g.nested_blocks.?[0];
                            try testing.expectEqualStrings("Trigger", trigger_block.name);

                            // Trigger should have other_tag_pattern property
                            try testing.expect(trigger_block.properties != null);
                            var has_pattern = false;
                            for (trigger_block.properties.?) |prop| {
                                if (std.mem.eql(u8, prop.name, "other_tag_pattern")) {
                                    has_pattern = true;
                                }
                            }
                            try testing.expect(has_pattern);

                            // Trigger should have 2 nested Action blocks
                            try testing.expect(trigger_block.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 2), trigger_block.nested_blocks.?.len);

                            const action1 = trigger_block.nested_blocks.?[0];
                            const action2 = trigger_block.nested_blocks.?[1];
                            try testing.expectEqualStrings("Action", action1.name);
                            try testing.expectEqualStrings("Action", action2.name);
                        }
                    },
                    else => {},
                }
            }
            try testing.expect(has_oncollision);
        },
        else => try testing.expect(false),
    }
}

test "parser - template with multiple actions in trigger" {
    const src: [:0]const u8 =
        \\[Ball:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [OnCollision]
        \\    [Trigger]
        \\      other_tag_pattern:string "brick"
        \\      [Action]
        \\        type:action destroy_other
        \\        priority:i32 0
        \\      [Action]
        \\        type:action play_sound
        \\        sound_name:string "brick_break"
        \\        priority:i32 1
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("Ball", template_decl.name);

            // Find OnCollision component
            for (template_decl.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnCollision")) {
                            // Should have nested blocks (1 Trigger)
                            try testing.expect(g.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                            const trigger = g.nested_blocks.?[0];
                            try testing.expectEqualStrings("Trigger", trigger.name);

                            // Trigger should have 2 nested Action blocks
                            try testing.expect(trigger.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 2), trigger.nested_blocks.?.len);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

test "parser - template with OnInput nested trigger and action" {
    const src: [:0]const u8 =
        \\[Paddle:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [OnInput]
        \\    [Trigger]
        \\      input:key Space
        \\      [Action]
        \\        type:action spawn_entity
        \\        template_name:string "missile"
        \\        offset:vec2 {0.0, -30.0}
        \\        priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("Paddle", template_decl.name);

            // Find OnInput component
            for (template_decl.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnInput")) {
                            // Should have nested blocks (1 Trigger)
                            try testing.expect(g.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                            const trigger = g.nested_blocks.?[0];
                            try testing.expectEqualStrings("Trigger", trigger.name);

                            // Trigger should have exactly 1 action
                            try testing.expect(trigger.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), trigger.nested_blocks.?.len);
                            try testing.expectEqualStrings("Action", trigger.nested_blocks.?[0].name);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

test "parser - template with complex polygon sprite" {
    const src: [:0]const u8 =
        \\[LargeAsteroid:template]
        \\  [Sprite:polygon]
        \\    points:vec2[] {{0.2, 0.9}, {0.7, 0.5}, {0.9, 0.0}, {0.6, -0.5}, {0.8, -0.8}, {0.4, -0.9}, {-0.2, -0.7}, {-0.6, -0.8}, {-0.9, -0.3}, {-0.7, 0.2}, {-0.9, 0.5}, {-0.3, 0.8}}
        \\    fill_color:color #8B4513
        \\    stroke_color:color #B87333
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);

    const decl = result.decls[0];
    switch (decl) {
        .template => |template_decl| {
            try testing.expectEqualStrings("LargeAsteroid", template_decl.name);

            // Verify polygon points
            const sprite_comp = template_decl.components[0];
            switch (sprite_comp) {
                .sprite => |sprite| {
                    // Check that we have the polygon shape with 12 points
                    if (sprite.properties) |props| {
                        for (props) |prop| {
                            if (std.mem.eql(u8, prop.name, "points")) {
                                switch (prop.value) {
                                    .array => |arr| {
                                        try testing.expectEqual(@as(usize, 12), arr.len);
                                    },
                                    else => try testing.expect(false),
                                }
                            }
                        }
                    }
                },
                else => try testing.expect(false),
            }
        },
        else => try testing.expect(false),
    }
}

test "parser - template with ScreenWrap component" {
    const src: [:0]const u8 =
        \\[WrappingEntity:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [ScreenWrap]
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
}

test "parser - template vs entity vs scene distinction" {
    const src: [:0]const u8 =
        \\[TestTemplate:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\
        \\[TestScene:scene]
        \\  [TestEntity:entity]
        \\    [Transform]
        \\      position:vec2 {1.0, 1.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 2), result.decls.len);

    // First should be template
    switch (result.decls[0]) {
        .template => {},
        else => try testing.expect(false),
    }

    // Second should be scene
    switch (result.decls[1]) {
        .scene => {},
        else => try testing.expect(false),
    }
}
