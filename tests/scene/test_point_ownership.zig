//! Regression: point-owning shapes (PolyLine, Polygon) must DUPE their `points`
//! out of the parser/AST arena during instantiation — the scene AST is transient
//! and its `[]const V2` is freed when parsing memory is reclaimed. Before the
//! `shapeOwnsPoints` dupe path in buildSpriteComponent, a PolyLine's points were
//! the borrowed AST slice → dangling after teardown.
//!
//! Strategy: parse into a DEDICATED arena, instantiate (dupes into persistent),
//! then destroy the parse arena. If the dupe worked, the sprite's points survive
//! with correct values; if it regressed to a borrowed slice, we'd be reading
//! freed memory (caught by the testing allocator, or by a value mismatch after
//! we scribble over the reclaimed arena).

const std = @import("std");
const testing = std.testing;
const scene_format = @import("scene-format");
const ecs = @import("ecs");
const World = ecs.World;
const Sprite = ecs.Sprite;
const scene = @import("scene");
const Instantiator = scene.Instantiator;
const asset = @import("assets");
const AssetManager = asset.AssetManager;
const core = @import("math");
const V2 = core.V2;
const GameMemory = core.GameMemory;

const polyline_scene =
    \\[TestScene:scene]
    \\  [Trail:entity]
    \\    [Transform]
    \\      position:vec3 {0.0, 0.0, 0.0}
    \\    [Sprite:polyline]
    \\      points:vec2[] {{-6.0, 0.0}, {-3.0, 2.0}, {0.0, -1.0}, {3.0, 2.0}, {6.0, 0.0}}
    \\      stroke_color:color #00ffaa
    \\      stroke_width:f32 3.0
    \\      visible:bool true
    \\
;

test "PolyLine sprite points survive AST-arena teardown (dupe, not borrow)" {
    const gpa = testing.allocator;

    var world = try World.init(gpa);
    defer world.deinit();

    var mem_backing: GameMemory = undefined;
    mem_backing.init(gpa);
    defer mem_backing.deinit();
    const mem = &mem_backing;

    var assets = try AssetManager.init(mem, std.testing.io, undefined);
    defer assets.deinit();

    var instantiator = Instantiator.init(mem.persistent, &world, &assets);
    defer instantiator.deinit();

    // Parse into a DEDICATED arena we control the lifetime of.
    var parse_arena = std.heap.ArenaAllocator.init(gpa);
    var sf = try scene_format.parseString(parse_arena.allocator(), polyline_scene, "test.scene");
    _ = &sf;

    try instantiator.instantiate(&sf);

    // Reclaim the parse arena: any borrowed AST slice is now dangling.
    parse_arena.deinit();

    // Scribble fresh allocations over the reclaimed region to make a dangling
    // read produce wrong values rather than coincidentally-correct stale bytes.
    var scribble = std.heap.ArenaAllocator.init(gpa);
    defer scribble.deinit();
    const spray = try scribble.allocator().alloc(V2, 256);
    for (spray) |*p| p.* = .{ .x = -999, .y = -999 };

    // Find the instantiated entity's sprite and read its polyline points.
    const entity = instantiator.last_instantiated_entities.items[0];
    const sprite = world.getComponent(entity, Sprite) orelse return error.NoSprite;
    const geo = sprite.geometry orelse return error.NoGeometry;

    switch (geo) {
        .PolyLine => |pl| {
            try testing.expectEqual(@as(usize, 5), pl.points.len);
            // Exact authored values must survive the teardown + scribble.
            try testing.expectEqual(@as(f32, -6.0), pl.points[0].x);
            try testing.expectEqual(@as(f32, 0.0), pl.points[0].y);
            try testing.expectEqual(@as(f32, 0.0), pl.points[2].x);
            try testing.expectEqual(@as(f32, -1.0), pl.points[2].y);
            try testing.expectEqual(@as(f32, 6.0), pl.points[4].x);
        },
        else => return error.WrongShapeVariant,
    }
}
