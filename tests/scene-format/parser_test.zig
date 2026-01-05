const std = @import("std");
const testing = std.testing;

const scene = @import("scene-format");
const Parser = scene.Parser;
const SceneFile = scene.SceneFile;
const Declaration = scene.Declaration;
const Value = scene.Value;
const Property = scene.Property;
const ComponentDeclaration = scene.ComponentDeclaration;

fn parseSource(allocator: std.mem.Allocator, src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(allocator, src, "test.scene");
    return try parser.parse();
}

fn freeSceneFile(scene_file: *SceneFile, allocator: std.mem.Allocator) void {
    scene_file.deinit(allocator);
}

// MARK: Basic Declaration Tests

test "parser - parse empty scene file" {
    const src: [:0]const u8 = "";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 0), result.decls.len);
}

test "parser - parse simple scene declaration" {
    const src: [:0]const u8 = "[TestScene:scene]";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .scene);
    try testing.expectEqualStrings("TestScene", result.decls[0].scene.name);
    try testing.expectEqual(false, result.decls[0].scene.is_container);
}

test "parser - parse scene with nested entities" {
    const src: [:0]const u8 =
        \\[GameScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .scene);
    try testing.expectEqual(true, result.decls[0].scene.is_container);
    try testing.expectEqual(@as(usize, 1), result.decls[0].scene.decls.len);

    const entity = result.decls[0].scene.decls[0].entity;
    try testing.expectEqualStrings("Player", entity.name);
    try testing.expectEqual(@as(usize, 1), entity.components.len);
}

test "parser - parse entity declaration" {
    const src: [:0]const u8 =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec3 {0.0, 0.0, 0.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .entity);
    try testing.expectEqualStrings("Player", result.decls[0].entity.name);
    try testing.expectEqual(@as(usize, 1), result.decls[0].entity.components.len);

    const component = result.decls[0].entity.components[0];
    try testing.expect(component == .generic);
    try testing.expectEqualStrings("Transform", component.generic.name);
    try testing.expect(component.generic.properties != null);
    try testing.expectEqual(@as(usize, 3), component.generic.properties.?.len);
}

test "parser - parse asset declaration" {
    const src: [:0]const u8 =
        \\[MainFont:asset font]
        \\  abs_path:string "assets/fonts/arcadeFont.ttf"
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .asset);
    try testing.expectEqualStrings("MainFont", result.decls[0].asset.name);
    try testing.expectEqual(scene.AssetType.font, result.decls[0].asset.asset_type);
    try testing.expect(result.decls[0].asset.properties != null);
    try testing.expectEqual(@as(usize, 1), result.decls[0].asset.properties.?.len);

    const prop = result.decls[0].asset.properties.?[0];
    try testing.expectEqualStrings("abs_path", prop.name);
    try testing.expect(prop.value == .string);
    try testing.expectEqualStrings("assets/fonts/arcadeFont.ttf", prop.value.string);
}

// MARK: Component Tests

test "parser - generic component with properties" {
    const src: [:0]const u8 =
        \\[TestEntity:entity]
        \\  [Transform]
        \\    position:vec3 {1.0, 2.0, 3.0}
        \\    rotation:f32 45.0
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const entity = result.decls[0].entity;
    try testing.expectEqual(@as(usize, 1), entity.components.len);

    const component = entity.components[0].generic;
    try testing.expectEqualStrings("Transform", component.name);
    try testing.expect(component.properties != null);
    try testing.expectEqual(@as(usize, 2), component.properties.?.len);

    try testing.expectEqualStrings("position", component.properties.?[0].name);
    try testing.expect(component.properties.?[0].value == .vector);
    try testing.expectEqual(@as(usize, 3), component.properties.?[0].value.vector.len);
    try testing.expectEqual(@as(f64, 1.0), component.properties.?[0].value.vector[0]);
    try testing.expectEqual(@as(f64, 2.0), component.properties.?[0].value.vector[1]);
    try testing.expectEqual(@as(f64, 3.0), component.properties.?[0].value.vector[2]);
}

test "parser - sprite component with shape type" {
    const src: [:0]const u8 =
        \\[TestEntity:entity]
        \\  [Sprite:circle]
        \\    origin:vec2 {0.0, 0.0}
        \\    radius:f32 2.0
        \\    fill_color:color #00FF00
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const component = result.decls[0].entity.components[0];
    try testing.expect(component == .sprite);
    try testing.expectEqualStrings("Sprite", component.sprite.name);
    try testing.expectEqualStrings("circle", component.sprite.shape_type);
    try testing.expect(component.sprite.properties != null);
    try testing.expectEqual(@as(usize, 3), component.sprite.properties.?.len);
}

test "parser - collider component with shape type" {
    const src: [:0]const u8 =
        \\[TestEntity:entity]
        \\  [Collider:rectangle]
        \\    center:vec2 {0.0, 0.0}
        \\    half_width:f32 1.5
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const component = result.decls[0].entity.components[0];
    try testing.expect(component == .collider);
    try testing.expectEqualStrings("Collider", component.collider.name);
    try testing.expectEqualStrings("rectangle", component.collider.shape_type);
    try testing.expect(component.collider.properties != null);
    try testing.expectEqual(@as(usize, 2), component.collider.properties.?.len);
}

// MARK: Property Value Tests

test "parser - number values" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    int_value:i32 42
        \\    float_value:f32 3.14
        \\    negative:f32 -2.5
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 3), props.len);

    try testing.expect(props[0].value == .number);
    try testing.expectEqual(@as(f64, 42.0), props[0].value.number);

    try testing.expect(props[1].value == .number);
    try testing.expectApproxEqAbs(@as(f64, 3.14), props[1].value.number, 0.001);

    try testing.expect(props[2].value == .number);
    try testing.expectEqual(@as(f64, -2.5), props[2].value.number);
}

test "parser - string values" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    name:string "Hello World"
        \\    path:string "assets/fonts/font.ttf"
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 2), props.len);

    try testing.expect(props[0].value == .string);
    try testing.expectEqualStrings("Hello World", props[0].value.string);

    try testing.expect(props[1].value == .string);
    try testing.expectEqualStrings("assets/fonts/font.ttf", props[1].value.string);
}

test "parser - boolean values" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    visible:bool true
        \\    enabled:bool false
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 2), props.len);

    try testing.expect(props[0].value == .boolean);
    try testing.expectEqual(true, props[0].value.boolean);

    try testing.expect(props[1].value == .boolean);
    try testing.expectEqual(false, props[1].value.boolean);
}

test "parser - color values" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    fill_color:color #FF0000
        \\    stroke_color:color #00FF00
        \\    text_color:color #0000FF
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 3), props.len);

    try testing.expect(props[0].value == .color);
    try testing.expectEqual(@as(u32, 0xFF0000), props[0].value.color);

    try testing.expect(props[1].value == .color);
    try testing.expectEqual(@as(u32, 0x00FF00), props[1].value.color);

    try testing.expect(props[2].value == .color);
    try testing.expectEqual(@as(u32, 0x0000FF), props[2].value.color);
}

test "parser - vector values" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    pos2d:vec2 {1.0, 2.0}
        \\    pos3d:vec3 {3.0, 4.0, 5.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 2), props.len);

    try testing.expect(props[0].value == .vector);
    try testing.expectEqual(@as(usize, 2), props[0].value.vector.len);
    try testing.expectEqual(@as(f64, 1.0), props[0].value.vector[0]);
    try testing.expectEqual(@as(f64, 2.0), props[0].value.vector[1]);

    try testing.expect(props[1].value == .vector);
    try testing.expectEqual(@as(usize, 3), props[1].value.vector.len);
    try testing.expectEqual(@as(f64, 3.0), props[1].value.vector[0]);
    try testing.expectEqual(@as(f64, 4.0), props[1].value.vector[1]);
    try testing.expectEqual(@as(f64, 5.0), props[1].value.vector[2]);
}

test "parser - array of vectors" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Sprite:polygon]
        \\    points:vec2[] {{0.0, 1.0}, {0.951, 0.309}, {0.588, -0.809}}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].sprite.properties.?;
    try testing.expectEqual(@as(usize, 1), props.len);

    try testing.expect(props[0].value == .array);
    try testing.expectEqual(@as(usize, 3), props[0].value.array.len);

    const first_vec = props[0].value.array[0].vector;
    try testing.expectEqual(@as(f64, 0.0), first_vec[0]);
    try testing.expectEqual(@as(f64, 1.0), first_vec[1]);

    const second_vec = props[0].value.array[1].vector;
    try testing.expectEqual(@as(f64, 0.951), second_vec[0]);
    try testing.expectApproxEqAbs(@as(f64, 0.309), second_vec[1], 0.001);
}

test "parser - asset reference" {
    const src: [:0]const u8 =
        \\[Text:entity]
        \\  [Text]
        \\    font_asset:asset_ref "OrbitronFont"
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(@as(usize, 1), props.len);

    try testing.expect(props[0].value == .assetRef);
    try testing.expectEqualStrings("OrbitronFont", props[0].value.assetRef);
}

// MARK: Complex Integration Tests

test "parser - multiple entities with various components" {
    const src: [:0]const u8 =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec3 {0.0, 0.0, 0.0}
        \\  [Sprite:circle]
        \\    radius:f32 1.0
        \\[Enemy:entity]
        \\  [Transform]
        \\    position:vec3 {5.0, 5.0, 0.0}
        \\  [Velocity]
        \\    linear:vec2 {1.0, 0.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 2), result.decls.len);

    const player = result.decls[0].entity;
    try testing.expectEqualStrings("Player", player.name);
    try testing.expectEqual(@as(usize, 2), player.components.len);

    const enemy = result.decls[1].entity;
    try testing.expectEqualStrings("Enemy", enemy.name);
    try testing.expectEqual(@as(usize, 2), enemy.components.len);
}

test "parser - scene with multiple levels of nesting" {
    const src: [:0]const u8 =
        \\[GameScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\  [UI:scene]
        \\    [HealthBar:entity]
        \\      [Transform]
        \\        position:vec2 {-10.0, -8.0}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    const game_scene = result.decls[0].scene;
    try testing.expectEqualStrings("GameScene", game_scene.name);
    try testing.expectEqual(@as(usize, 2), game_scene.decls.len);

    const player = game_scene.decls[0].entity;
    try testing.expectEqualStrings("Player", player.name);

    const ui_scene = game_scene.decls[1].scene;
    try testing.expectEqualStrings("UI", ui_scene.name);
    try testing.expectEqual(@as(usize, 1), ui_scene.decls.len);
}

test "parser - full scene with assets, entities, and nested scenes" {
    const src: [:0]const u8 =
        \\[MainFont:asset font]
        \\  abs_path:string "assets/fonts/font.ttf"
        \\[GameScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\      scale:f32 1.0
        \\    [Sprite:circle]
        \\      radius:f32 1.0
        \\      fill_color:color #FFFFFF
        \\    [Text]
        \\      text:string "Player"
        \\      font_asset:asset_ref "MainFont"
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 2), result.decls.len);

    const font_asset = result.decls[0].asset;
    try testing.expectEqualStrings("MainFont", font_asset.name);

    const game_scene = result.decls[1].scene;
    try testing.expectEqualStrings("GameScene", game_scene.name);
    try testing.expectEqual(@as(usize, 1), game_scene.decls.len);

    const player = game_scene.decls[0].entity;
    try testing.expectEqual(@as(usize, 3), player.components.len);
}

test "parser - empty component" {
    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [ScreenClamp]
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    const component = result.decls[0].entity.components[0];
    try testing.expect(component == .generic);
    try testing.expectEqualStrings("ScreenClamp", component.generic.name);
    try testing.expect(component.generic.properties == null);
}

test "parser - various shape types" {
    const src: [:0]const u8 =
        \\[E1:entity]
        \\  [Sprite:circle]
        \\    radius:f32 1.0
        \\[E2:entity]
        \\  [Sprite:rectangle]
        \\    half_width:f32 2.0
        \\[E3:entity]
        \\  [Sprite:triangle]
        \\    v0:vec2 {0.0, 1.0}
        \\[E4:entity]
        \\  [Sprite:polygon]
        \\    points:vec2[] {{0.0, 1.0}, {1.0, 0.0}}
    ;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try parseSource(allocator, src);
    defer freeSceneFile(&result, allocator);

    try testing.expectEqual(@as(usize, 4), result.decls.len);

    try testing.expectEqualStrings("circle", result.decls[0].entity.components[0].sprite.shape_type);
    try testing.expectEqualStrings("rectangle", result.decls[1].entity.components[0].sprite.shape_type);
    try testing.expectEqualStrings("triangle", result.decls[2].entity.components[0].sprite.shape_type);
    try testing.expectEqualStrings("polygon", result.decls[3].entity.components[0].sprite.shape_type);
}
