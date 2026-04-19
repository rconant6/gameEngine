const std = @import("std");
const testing = std.testing;

const scene_format = @import("scene-format");
const Parser = scene_format.Parser;
const SceneFile = scene_format.SceneFile;
const serialize = scene_format.serialize;

fn parse(gpa: std.mem.Allocator, src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(gpa, src, "test.scene");
    return try parser.parse();
}

fn serializeToString(gpa: std.mem.Allocator, sf: *const SceneFile) ![]u8 {
    const backing = try gpa.alloc(u8, 64 * 1024);
    defer gpa.free(backing);
    var w = std.Io.Writer.fixed(backing);
    try serialize(sf, &w);
    return try gpa.dupe(u8, w.buffered());
}

const Reparsed = struct {
    scene: SceneFile,
    src: [:0]u8,

    fn deinit(self: *Reparsed, gpa: std.mem.Allocator) void {
        self.scene.deinit(gpa);
        gpa.free(self.src);
    }
};

fn reParse(gpa: std.mem.Allocator, out: []const u8) !Reparsed {
    const src = try gpa.dupeZ(u8, out);
    errdefer gpa.free(src);
    var parser = try Parser.init(gpa, src, "out.scene");
    const scene = try parser.parse();
    return .{ .scene = scene, .src = src };
}

// MARK: Empty

test "writer - empty scene file produces empty output" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    var sf = try parse(gpa, "");
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    try testing.expectEqualStrings("", out);
}

// MARK: Asset

test "writer - asset declaration round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[MainFont:asset font]
        \\  path:string "assets/fonts/font.ttf"
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .asset);
    try testing.expectEqualStrings("MainFont", result.decls[0].asset.name);
    try testing.expectEqual(scene_format.AssetType.font, result.decls[0].asset.asset_type);
    const props = result.decls[0].asset.properties.?;
    try testing.expectEqual(@as(usize, 1), props.len);
    try testing.expectEqualStrings("path", props[0].name);
    try testing.expectEqualStrings("assets/fonts/font.ttf", props[0].value.string);
}

// MARK: Scene

test "writer - empty scene declaration round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 = "[MyScene:scene]";

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .scene);
    try testing.expectEqualStrings("MyScene", result.decls[0].scene.name);
}

// MARK: Entity + generic block

test "writer - entity with transform round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec3 {0.0, 0.0, 0.0}
        \\    scale:f32 1.0
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    const entity = result.decls[0].entity;
    try testing.expectEqualStrings("Player", entity.name);
    try testing.expectEqual(@as(usize, 1), entity.components.len);

    const comp = entity.components[0].generic;
    try testing.expectEqualStrings("Transform", comp.name);
    const props = comp.properties.?;
    try testing.expectEqual(@as(usize, 2), props.len);
    try testing.expectEqualStrings("position", props[0].name);
    try testing.expectEqual(@as(usize, 3), props[0].value.vector.len);
    try testing.expectEqualStrings("scale", props[1].name);
    try testing.expectApproxEqAbs(@as(f64, 1.0), props[1].value.number, 0.0001);
}

// MARK: Sprite block

test "writer - sprite block round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Enemy:entity]
        \\  [Sprite:circle]
        \\    origin:vec2 {0.0, 0.0}
        \\    radius:f32 2.0
        \\    fill_color:color #ff0000
        \\    visible:bool true
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const comp = result.decls[0].entity.components[0];
    try testing.expect(comp == .sprite);
    try testing.expectEqualStrings("circle", comp.sprite.shape_type);
    const props = comp.sprite.properties.?;
    try testing.expectEqual(@as(usize, 4), props.len);
    try testing.expectEqual(@as(u32, 0xff0000), props[2].value.color);
    try testing.expectEqual(true, props[3].value.boolean);
}

// MARK: Collider block

test "writer - collider block round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Wall:entity]
        \\  [Collider:rectangle]
        \\    center:vec2 {0.0, 0.0}
        \\    half_width:f32 5.0
        \\    half_height:f32 1.0
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const comp = result.decls[0].entity.components[0];
    try testing.expect(comp == .collider);
    try testing.expectEqualStrings("rectangle", comp.collider.shape_type);
    try testing.expectEqual(@as(usize, 3), comp.collider.properties.?.len);
}

// MARK: Nested generic blocks

test "writer - nested generic blocks round-trip" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Player:entity]
        \\  [OnInput]
        \\    [trigger]
        \\      key:string "W"
        \\      [action]
        \\        type:string "set_velocity"
        \\        target:string "self"
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const comp = result.decls[0].entity.components[0].generic;
    try testing.expectEqualStrings("OnInput", comp.name);
    const trigger = comp.nested_blocks.?[0];
    try testing.expectEqualStrings("trigger", trigger.name);
    try testing.expectEqualStrings("W", trigger.properties.?[0].value.string);
    const action = trigger.nested_blocks.?[0];
    try testing.expectEqualStrings("action", action.name);
}

// MARK: Template

test "writer - template declaration round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Bullet:template]
        \\  [Transform]
        \\    position:vec3 {0.0, 0.0, 0.0}
        \\    scale:f32 1.0
        \\  [Sprite:circle]
        \\    radius:f32 0.3
        \\    fill_color:color #ffff00
        \\    visible:bool true
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .template);
    const tmpl = result.decls[0].template;
    try testing.expectEqualStrings("Bullet", tmpl.name);
    try testing.expectEqual(@as(usize, 2), tmpl.components.len);
}

// MARK: Value types

test "writer - integer value round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    priority:i32 0
        \\    count:i32 -5
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectApproxEqAbs(@as(f64, 0.0), props[0].value.number, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, -5.0), props[1].value.number, 0.0001);
}

test "writer - vec2 value round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Velocity]
        \\    linear:vec2 {3.5, -1.5}
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const v = result.decls[0].entity.components[0].generic.properties.?[0].value.vector;
    try testing.expectApproxEqAbs(@as(f64, 3.5), v[0], 0.0001);
    try testing.expectApproxEqAbs(@as(f64, -1.5), v[1], 0.0001);
}

test "writer - boolean values round-trip" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Component]
        \\    visible:bool true
        \\    enabled:bool false
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqual(true, props[0].value.boolean);
    try testing.expectEqual(false, props[1].value.boolean);
}

test "writer - color value round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Sprite:circle]
        \\    fill_color:color #00ff88
        \\    radius:f32 1.0
        \\    visible:bool true
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const props = result.decls[0].entity.components[0].sprite.properties.?;
    try testing.expectEqual(@as(u32, 0x00ff88), props[0].value.color);
}

test "writer - string value round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[Test:entity]
        \\  [Tag]
        \\    tags:string "player enemy"
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    const props = result.decls[0].entity.components[0].generic.properties.?;
    try testing.expectEqualStrings("player enemy", props[0].value.string);
}

// MARK: Full round-trip

test "writer - scene with entity inside scene container round-trips" {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const gpa = da.allocator();

    const src: [:0]const u8 =
        \\[MainFont:asset font]
        \\  path:string "assets/fonts/font.ttf"
        \\[GameScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.5}
        \\      scale:f32 1.0
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 1.5
        \\      fill_color:color #00ff00
        \\      visible:bool true
        \\    [Tag]
        \\      tags:string "player"
    ;

    var sf = try parse(gpa, src);
    defer sf.deinit(gpa);

    const out = try serializeToString(gpa, &sf);
    defer gpa.free(out);

    var reparsed = try reParse(gpa, out);
    defer reparsed.deinit(gpa);
    const result = reparsed.scene;

    try testing.expectEqual(@as(usize, 2), result.decls.len);
    try testing.expect(result.decls[0] == .asset);
    try testing.expectEqualStrings("MainFont", result.decls[0].asset.name);

    const scene_decl = result.decls[1].scene;
    try testing.expectEqualStrings("GameScene", scene_decl.name);
    try testing.expectEqual(@as(usize, 1), scene_decl.decls.len);

    const player = scene_decl.decls[0].entity;
    try testing.expectEqualStrings("Player", player.name);
    try testing.expectEqual(@as(usize, 3), player.components.len);

    const transform = player.components[0].generic;
    try testing.expectEqualStrings("Transform", transform.name);

    const sprite = player.components[1].sprite;
    try testing.expectEqualStrings("circle", sprite.shape_type);
    try testing.expectEqual(@as(u32, 0x00ff00), sprite.properties.?[2].value.color);

    const tag = player.components[2].generic;
    try testing.expectEqualStrings("player", tag.properties.?[0].value.string);
}
