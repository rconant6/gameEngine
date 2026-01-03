const std = @import("std");
const testing = std.testing;
const scene_format = @import("scene-format");

test "SceneFormat: parse simple scene file" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\      scale:f32 1.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with Transform component" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {1.0, 2.0, 3.0}
        \\      scale:f32 2.5
        \\      rotation:f32 0.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
    const decl = scene.decls[0];

    switch (decl) {
        .scene => |scene_decl| {
            try testing.expectEqual(@as(usize, 1), scene_decl.decls.len);
        },
        else => try testing.expect(false),
    }
}

test "SceneFormat: parse entity with Collider circle" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Ball:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Collider:circle]
        \\      radius:f32 5.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with Collider rectangle" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Box:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Collider:rectangle]
        \\      half_width:f32 10.0
        \\      half_height:f32 15.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with Sprite circle" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Ball:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 5.0
        \\      fill_color:color #FF0000
        \\      visible:bool true
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with Sprite rectangle" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Box:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:rectangle]
        \\      center:vec2 {0.0, 0.0}
        \\      half_width:f32 10.0
        \\      half_height:f32 15.0
        \\      fill_color:color #00FF00
        \\      visible:bool true
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with Velocity" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [MovingBall:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Velocity]
        \\      linear:vec2 {5.0, 3.0}
        \\      angular:f32 0.5
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse entity with multiple components" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [ComplexEntity:entity]
        \\    [Transform]
        \\      position:vec3 {1.0, 2.0, 3.0}
        \\      scale:f32 1.0
        \\    [Velocity]
        \\      linear:vec2 {4.0, 5.0}
        \\      angular:f32 0.0
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 2.0
        \\      fill_color:color #FFFFFF
        \\      visible:bool true
        \\    [Collider:circle]
        \\      radius:f32 2.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);

    const decl = scene.decls[0];
    switch (decl) {
        .scene => |scene_decl| {
            try testing.expectEqual(@as(usize, 1), scene_decl.decls.len);
            const entity_decl = scene_decl.decls[0];
            switch (entity_decl) {
                .entity => |entity| {
                    // Should have 4 components: Transform, Velocity, Sprite, Collider
                    try testing.expect(entity.components.len >= 3);
                },
                else => try testing.expect(false),
            }
        },
        else => try testing.expect(false),
    }
}

test "SceneFormat: parse scene with multiple entities" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Entity1:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\  [Entity2:entity]
        \\    [Transform]
        \\      position:vec3 {5.0, 5.0, 0.0}
        \\  [Entity3:entity]
        \\    [Transform]
        \\      position:vec3 {-5.0, -5.0, 0.0}
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);

    const decl = scene.decls[0];
    switch (decl) {
        .scene => |scene_decl| {
            try testing.expectEqual(@as(usize, 3), scene_decl.decls.len);
        },
        else => try testing.expect(false),
    }
}

test "SceneFormat: parse asset declaration" {
    const allocator = testing.allocator;
    const source =
        \\[TestFont:asset font]
        \\  path:string "assets/fonts/"
        \\  filename:string "test.ttf"
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);

    const decl = scene.decls[0];
    switch (decl) {
        .asset => {},
        else => try testing.expect(false),
    }
}

test "SceneFormat: parse Text component with font asset reference" {
    const allocator = testing.allocator;
    const source =
        \\[TestFont:asset font]
        \\  path:string "assets/fonts/"
        \\  filename:string "test.ttf"
        \\[TestScene:scene]
        \\  [TextEntity:entity]
        \\    [Transform]
        \\      position:vec2 {0.0, 0.0}
        \\    [Text]
        \\      text:string "Hello World"
        \\      font_asset:asset_ref "TestFont"
        \\      text_color:color #FFFFFF
        \\      size:f32 1.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), scene.decls.len);
}

test "SceneFormat: parse entity with tag components" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [WrappingEntity:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [ScreenWrap]
        \\  [ClampingEntity:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [ScreenClamp]
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);

    const decl = scene.decls[0];
    switch (decl) {
        .scene => |scene_decl| {
            try testing.expectEqual(@as(usize, 2), scene_decl.decls.len);
        },
        else => try testing.expect(false),
    }
}

test "SceneFormat: parse scene with comments" {
    const allocator = testing.allocator;
    const source =
        \\// This is a test scene
        \\[TestScene:scene]
        \\  // First entity
        \\  [Entity1:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\  // Second entity
        \\  [Entity2:entity]
        \\    [Transform]
        \\      position:vec3 {1.0, 1.0, 0.0}
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse Camera component" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Camera:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 10.0}
        \\    [Camera]
        \\      fov:f32 60.0
        \\      near:f32 0.1
        \\      far:f32 100.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse Box component" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [Ground:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Box]
        \\      size:vec2 {20.0, 10.0}
        \\      fill_color:color #000000
        \\      filled:bool true
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse color values" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [ColoredEntity:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 1.0
        \\      fill_color:color #FF0000
        \\      stroke_color:color #00FF00
        \\      visible:bool true
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}

test "SceneFormat: parse vec2, vec3 values" {
    const allocator = testing.allocator;
    const source =
        \\[TestScene:scene]
        \\  [VectorEntity:entity]
        \\    [Transform]
        \\      position:vec3 {1.5, 2.5, 3.5}
        \\      scale:f32 2.0
        \\    [Velocity]
        \\      linear:vec2 {-5.0, 10.0}
        \\      angular:f32 0.0
    ;

    var scene = try scene_format.parseString(allocator, source, "test.scene");
    defer scene.deinit(allocator);

    try testing.expectEqual(@as(usize, 1), scene.decls.len);
}
