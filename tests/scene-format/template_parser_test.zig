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

// ============================================================================
// MARK: Basic Template Structure
// ============================================================================

test "template: minimal - empty template declaration" {
    const src: [:0]const u8 =
        \\[Empty:template]
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Empty", t.name);
            try testing.expectEqual(@as(usize, 0), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: minimal - single component no properties" {
    const src: [:0]const u8 =
        \\[Simple:template]
        \\  [ScreenWrap]
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Simple", t.name);
            try testing.expectEqual(@as(usize, 1), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: minimal - single component with one property" {
    const src: [:0]const u8 =
        \\[Basic:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Basic", t.name);
            try testing.expectEqual(@as(usize, 1), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: basic - single component with multiple properties" {
    const src: [:0]const u8 =
        \\[Projectile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Projectile", t.name);
            try testing.expectEqual(@as(usize, 1), t.components.len);
        },
        else => try testing.expect(false),
    }
}

// ============================================================================
// MARK: Multiple Components
// ============================================================================

test "template: multiple components - two simple components" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Velocity]
        \\    linear:vec2 {0.0, -500.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Missile", t.name);
            try testing.expectEqual(@as(usize, 2), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: multiple components - transform, velocity, and sprite" {
    const src: [:0]const u8 =
        \\[Enemy:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    scale:f32 2.0
        \\  [Velocity]
        \\    linear:vec2 {0.5, 0.15}
        \\    angular:f32 0.2
        \\  [Sprite:circle]
        \\    radius:f32 1.0
        \\    fill_color:color #FF0000
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Enemy", t.name);
            try testing.expectEqual(@as(usize, 3), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: multiple components - with collider and tags" {
    const src: [:0]const u8 =
        \\[Asteroid:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    scale:f32 35.0
        \\  [Sprite:circle]
        \\    radius:f32 1.0
        \\    fill_color:color #8B4513
        \\  [Collider:circle]
        \\    radius:f32 1.0
        \\  [Tag]
        \\    names:string[] {"asteroid", "hostile"}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Asteroid", t.name);
            try testing.expectEqual(@as(usize, 4), t.components.len);
        },
        else => try testing.expect(false),
    }
}

test "template: multiple components - with lifetime component" {
    const src: [:0]const u8 =
        \\[Particle:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Sprite:circle]
        \\    radius:f32 0.2
        \\    fill_color:color #FF4500
        \\  [Velocity]
        \\    linear:vec2 {1.0, -2.0}
        \\  [Lifetime]
        \\    remaining:f32 0.5
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            try testing.expectEqualStrings("Particle", t.name);
            try testing.expectEqual(@as(usize, 4), t.components.len);

            // Verify Lifetime component exists
            var has_lifetime = false;
            for (t.components) |comp| {
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

// ============================================================================
// MARK: Sprite Variants
// ============================================================================

test "template: sprite - circle variant" {
    const src: [:0]const u8 =
        \\[CircleEntity:template]
        \\  [Sprite:circle]
        \\    radius:f32 1.5
        \\    fill_color:color #00FF00
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            switch (t.components[0]) {
                .sprite => |s| {
                    try testing.expect(std.ascii.eqlIgnoreCase("circle", s.shape_type));
                },
                else => try testing.expect(false),
            }
        },
        else => try testing.expect(false),
    }
}

test "template: sprite - polygon variant with multiple points" {
    const src: [:0]const u8 =
        \\[TriangleEntity:template]
        \\  [Sprite:polygon]
        \\    points:vec2[] {{0.0, 1.0}, {-1.0, -1.0}, {1.0, -1.0}}
        \\    fill_color:color #0000FF
        \\    stroke_color:color #FFFFFF
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            switch (t.components[0]) {
                .sprite => |sprite| {
                    try testing.expect(std.ascii.eqlIgnoreCase("polygon", sprite.shape_type));
                    if (sprite.properties) |props| {
                        for (props) |prop| {
                            if (std.mem.eql(u8, prop.name, "points")) {
                                switch (prop.value) {
                                    .array => |arr| {
                                        try testing.expectEqual(@as(usize, 3), arr.len);
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

test "template: sprite - complex polygon with 12 points" {
    const src: [:0]const u8 =
        \\[ComplexAsteroid:template]
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
    switch (result.decls[0]) {
        .template => |t| {
            switch (t.components[0]) {
                .sprite => |sprite| {
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

// ============================================================================
// MARK: Nested Component Structures (OnCollision)
// ============================================================================

test "template: nested - OnCollision with single trigger and action" {
    const src: [:0]const u8 =
        \\[BasicCollider:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [OnCollision]
        \\    [Trigger]
        \\      other_tag_pattern:string "wall"
        \\      [Action]
        \\        type:action destroy_self
        \\        priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            var has_oncollision = false;
            for (t.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnCollision")) {
                            has_oncollision = true;
                            try testing.expect(g.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                            const trigger = g.nested_blocks.?[0];
                            try testing.expectEqualStrings("Trigger", trigger.name);
                            try testing.expect(trigger.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), trigger.nested_blocks.?.len);
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

test "template: nested - OnCollision with multiple actions" {
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
    switch (result.decls[0]) {
        .template => |t| {
            for (t.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnCollision")) {
                            const trigger = g.nested_blocks.?[0];
                            try testing.expect(trigger.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 2), trigger.nested_blocks.?.len);

                            // Verify both are Actions
                            try testing.expectEqualStrings("Action", trigger.nested_blocks.?[0].name);
                            try testing.expectEqualStrings("Action", trigger.nested_blocks.?[1].name);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

test "template: nested - OnCollision with property verification" {
    const src: [:0]const u8 =
        \\[Ball:template]
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
    switch (result.decls[0]) {
        .template => |t| {
            for (t.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnCollision")) {
                            const trigger = g.nested_blocks.?[0];

                            // Verify trigger has other_tag_pattern property
                            try testing.expect(trigger.properties != null);
                            var has_pattern = false;
                            for (trigger.properties.?) |prop| {
                                if (std.mem.eql(u8, prop.name, "other_tag_pattern")) {
                                    has_pattern = true;
                                    switch (prop.value) {
                                        .string => |s| try testing.expectEqualStrings("brick", s),
                                        else => try testing.expect(false),
                                    }
                                }
                            }
                            try testing.expect(has_pattern);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

// ============================================================================
// MARK: Nested Component Structures (OnInput)
// ============================================================================

test "template: nested - OnInput with keyboard trigger" {
    const src: [:0]const u8 =
        \\[Player:template]
        \\  [OnInput]
        \\    [Trigger]
        \\      input:key Space
        \\      [Action]
        \\        type:action spawn_entity
        \\        template_name:string "bullet"
        \\        priority:i32 0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    switch (result.decls[0]) {
        .template => |t| {
            for (t.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnInput")) {
                            try testing.expect(g.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), g.nested_blocks.?.len);

                            const trigger = g.nested_blocks.?[0];
                            try testing.expectEqualStrings("Trigger", trigger.name);
                            try testing.expect(trigger.nested_blocks != null);
                            try testing.expectEqual(@as(usize, 1), trigger.nested_blocks.?.len);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

test "template: nested - OnInput with spawn_entity action properties" {
    const src: [:0]const u8 =
        \\[Paddle:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 500.0}
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
    switch (result.decls[0]) {
        .template => |t| {
            for (t.components) |comp| {
                switch (comp) {
                    .generic => |g| {
                        if (std.mem.eql(u8, g.name, "OnInput")) {
                            const trigger = g.nested_blocks.?[0];
                            const action = trigger.nested_blocks.?[0];

                            // Verify action properties
                            try testing.expect(action.properties != null);
                            var has_template = false;
                            var has_offset = false;
                            for (action.properties.?) |prop| {
                                if (std.mem.eql(u8, prop.name, "template_name")) has_template = true;
                                if (std.mem.eql(u8, prop.name, "offset")) has_offset = true;
                            }
                            try testing.expect(has_template);
                            try testing.expect(has_offset);
                        }
                    },
                    else => {},
                }
            }
        },
        else => try testing.expect(false),
    }
}

// ============================================================================
// MARK: Multiple Templates in One File
// ============================================================================

test "template: multiple - two simple templates" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\
        \\[Bullet:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 2), result.decls.len);

    switch (result.decls[0]) {
        .template => |t| try testing.expectEqualStrings("Missile", t.name),
        else => try testing.expect(false),
    }

    switch (result.decls[1]) {
        .template => |t| try testing.expectEqualStrings("Bullet", t.name),
        else => try testing.expect(false),
    }
}

test "template: multiple - three projectile templates with different velocities" {
    const src: [:0]const u8 =
        \\[Missile:template]
        \\  [Velocity]
        \\    linear:vec2 {0.0, -500.0}
        \\
        \\[Bullet:template]
        \\  [Velocity]
        \\    linear:vec2 {0.0, -800.0}
        \\
        \\[Laser:template]
        \\  [Velocity]
        \\    linear:vec2 {0.0, -1200.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 3), result.decls.len);

    switch (result.decls[0]) {
        .template => |t| try testing.expectEqualStrings("Missile", t.name),
        else => try testing.expect(false),
    }
    switch (result.decls[1]) {
        .template => |t| try testing.expectEqualStrings("Bullet", t.name),
        else => try testing.expect(false),
    }
    switch (result.decls[2]) {
        .template => |t| try testing.expectEqualStrings("Laser", t.name),
        else => try testing.expect(false),
    }
}

// ============================================================================
// MARK: Declaration Type Distinction
// ============================================================================

test "template: distinction - template vs entity" {
    const src: [:0]const u8 =
        \\[MyTemplate:template]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\
        \\[MyScene:scene]
        \\  [MyEntity:entity]
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
        .template => |t| try testing.expectEqualStrings("MyTemplate", t.name),
        else => try testing.expect(false),
    }

    // Second should be scene
    switch (result.decls[1]) {
        .scene => {},
        else => try testing.expect(false),
    }
}

test "template: distinction - multiple types in one file" {
    const src: [:0]const u8 =
        \\[Font1:asset font]
        \\  path:string "assets/fonts/arial.ttf"
        \\
        \\[EnemyTemplate:template]
        \\  [Transform]
        \\    scale:f32 2.0
        \\
        \\[GameScene:scene]
        \\  [Camera:entity]
        \\    [Transform]
        \\      position:vec2 {0.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 3), result.decls.len);

    // Verify declaration types
    switch (result.decls[0]) {
        .asset => {},
        else => try testing.expect(false),
    }
    switch (result.decls[1]) {
        .template => {},
        else => try testing.expect(false),
    }
    switch (result.decls[2]) {
        .scene => {},
        else => try testing.expect(false),
    }
}
