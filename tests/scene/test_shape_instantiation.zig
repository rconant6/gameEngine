//! Scene-DSL → shape instantiation coverage for the Phase 3.1 shape set: each
//! new shape parses from the scene format and lands as the correct ShapeData
//! union variant with its fields populated. Exercises the comptime shape
//! registry + instantiator field-reflection + DSL lowercase lookup end to end.
//! (Vertex-level tessellation is covered separately in
//! tests/renderer/test_tessellation.zig.)

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

const Harness = struct {
    mem: GameMemory,
    world: World,
    assets: AssetManager,
    instantiator: Instantiator,

    fn init(self: *Harness, gpa: std.mem.Allocator) !void {
        self.mem = undefined;
        self.mem.init(gpa);
        self.world = try World.init(gpa);
        self.assets = try AssetManager.init(&self.mem, std.testing.io, undefined);
        self.instantiator = Instantiator.init(self.mem.persistent, &self.world, &self.assets);
    }
    fn deinit(self: *Harness) void {
        self.instantiator.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.mem.deinit();
    }

    /// Parse + instantiate a scene source, return the first entity's Sprite.
    /// The AST is freed here — these shapes carry only numeric fields + duped
    /// points, so the resulting Sprite is independent of the SceneFile.
    fn spriteFrom(self: *Harness, gpa: std.mem.Allocator, src: [:0]const u8) !*const Sprite {
        var sf = try scene_format.parseString(gpa, src, "test.scene");
        defer sf.deinit(gpa);
        try self.instantiator.instantiate(&sf);
        const entity = self.instantiator.last_instantiated_entities.items[0];
        return self.world.getComponent(entity, Sprite) orelse error.NoSprite;
    }
};

test "scene: NGon instantiates as .NGon with sides (u32 field path)" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:ngon]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 2.5
        \\      sides:u32 6
        \\      fill_color:color #8866ff
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .NGon => |ng| {
            try testing.expectEqual(@as(u32, 6), ng.sides);
            try testing.expectEqual(@as(f32, 2.5), ng.radius);
        },
        else => return error.WrongVariant,
    }
}

test "scene: Star instantiates as .Star with inner/outer radii + points" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:star]
        \\      origin:vec2 {0.0, 0.0}
        \\      outer_radius:f32 2.8
        \\      inner_radius:f32 1.2
        \\      points:u32 5
        \\      fill_color:color #ffdd00
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .Star => |st| {
            try testing.expectEqual(@as(u32, 5), st.points);
            try testing.expectEqual(@as(f32, 2.8), st.outer_radius);
            try testing.expectEqual(@as(f32, 1.2), st.inner_radius);
        },
        else => return error.WrongVariant,
    }
}

test "scene: Arc instantiates as .Arc with thickness + angles" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:arc]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 2.8
        \\      thickness:f32 0.8
        \\      start_angle:f32 0.5
        \\      end_angle:f32 5.0
        \\      fill_color:color #00ddff
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .Arc => |a| {
            try testing.expectEqual(@as(f32, 2.8), a.radius);
            try testing.expectEqual(@as(f32, 0.8), a.thickness);
            try testing.expectEqual(@as(f32, 0.5), a.start_angle);
        },
        else => return error.WrongVariant,
    }
}

test "scene: RoundedRect instantiates as .RoundedRect with radius" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:roundedrect]
        \\      center:vec2 {0.0, 0.0}
        \\      half_width:f32 3.0
        \\      half_height:f32 2.0
        \\      radius:f32 1.0
        \\      fill_color:color #4488ff
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .RoundedRect => |rr| {
            try testing.expectEqual(@as(f32, 1.0), rr.radius);
            try testing.expectEqual(@as(f32, 3.0), rr.half_width);
        },
        else => return error.WrongVariant,
    }
}

test "scene: Capsule instantiates as .Capsule" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:capsule]
        \\      center:vec2 {0.0, 0.0}
        \\      half_width:f32 3.5
        \\      half_height:f32 1.2
        \\      fill_color:color #22cc88
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .Capsule => |c| {
            try testing.expectEqual(@as(f32, 3.5), c.half_width);
            try testing.expectEqual(@as(f32, 1.2), c.half_height);
        },
        else => return error.WrongVariant,
    }
}

test "scene: PolyLine instantiates as .PolyLine with points" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:polyline]
        \\      points:vec2[] {{-6.0, 0.0}, {-3.0, 2.0}, {0.0, -1.0}, {3.0, 2.0}, {6.0, 0.0}}
        \\      stroke_color:color #00ffaa
        \\      stroke_width:f32 3.0
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    const geo = sprite.geometry orelse return error.NoGeometry;
    switch (geo) {
        .PolyLine => |pl| {
            try testing.expectEqual(@as(usize, 5), pl.points.len);
        },
        else => return error.WrongVariant,
    }
}

test "scene: opacity field defaults to 1.0 when omitted" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 1.0
        \\      fill_color:color #ffffff
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    try testing.expectEqual(@as(f32, 1.0), sprite.opacity);
}

test "scene: opacity override is parsed onto the Sprite" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    const src =
        \\[S:scene]
        \\  [E:entity]
        \\    [Transform]
        \\      position:vec3 {0.0, 0.0, 0.0}
        \\    [Sprite:circle]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 1.0
        \\      fill_color:color #ffffff
        \\      opacity:f32 0.25
        \\      visible:bool true
        \\
    ;
    const sprite = try h.spriteFrom(gpa, src);
    try testing.expectEqual(@as(f32, 0.25), sprite.opacity);
}
