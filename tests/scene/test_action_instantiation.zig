//! Phase 3G — action instantiation integration tests.
//!
//! RED until Phase 3A–3F land. References the planned API:
//!   - Instantiator gains `actions: *const ActionRegistry` (wired by Engine;
//!     here we set it directly on the test instantiator)
//!   - buildAction decodes [action] blocks via the registry instead of the
//!     deleted ActionType union
//!   - InstantiatorError.UnknownActionType for an unregistered action name
//!
//! Covers the 3G "Integration" bullet: a scene with a registered (custom)
//! action instantiates + carries the decoded action; an unknown action name in
//! a scene is an instantiation error, not a crash.

const std = @import("std");
const testing = std.testing;

const scene_format = @import("scene-format");
const scene = @import("scene");
const Instantiator = scene.Instantiator;

const ecs = @import("ecs");
const World = ecs.World;
const Tag = ecs.Tag;

const asset = @import("assets");
const AssetManager = asset.AssetManager;

const Action = @import("Action");
const ActionRegistry = Action.ActionRegistry;
const ActionRunContext = Action.ActionRunContext;
const OnCollision = Action.OnCollision;

const math = @import("math");
const GameMemory = @import("memory");

// A trivial custom action a game might register. Body is irrelevant to these
// tests — they assert that scene → instantiation wires it up and that an
// unknown name fails cleanly.
const Nudge = struct { amount: f32 = 1.0 };
fn nudge(ctx: *ActionRunContext, p: Nudge) void {
    _ = ctx;
    _ = p;
}

const Harness = struct {
    mem: GameMemory,
    world: World,
    assets: AssetManager,
    registry: ActionRegistry,
    instantiator: Instantiator,

    fn init(self: *Harness, gpa: std.mem.Allocator) !void {
        self.mem = undefined;
        self.mem.init(gpa);
        self.world = try World.init(gpa);
        self.assets = try AssetManager.init(&self.mem, std.testing.io, undefined);
        self.registry = ActionRegistry.init(gpa);
        self.instantiator = Instantiator.init(self.mem.persistent, &self.world, &self.assets);
        self.instantiator.actions = &self.registry; // Phase 3F wiring
        self.instantiator.game = self.mem.game; // decode target arena
    }
    fn deinit(self: *Harness) void {
        self.instantiator.deinit();
        self.registry.deinit();
        self.assets.deinit();
        self.world.deinit();
        self.mem.deinit();
    }
};

const custom_action_scene =
    \\[TestScene:scene]
    \\  [Ball:entity]
    \\    [Transform]
    \\      position:vec3 {0.0, 0.0, 0.0}
    \\    [Tag]
    \\      tags:string "ball"
    \\    [OnCollision]
    \\      [trigger]
    \\        other_tag_pattern:string "wall"
    \\        [action]
    \\          type:string "nudge"
    \\          amount:f32 2.5
    \\
;

const unknown_action_scene =
    \\[TestScene:scene]
    \\  [Ball:entity]
    \\    [Tag]
    \\      tags:string "ball"
    \\    [OnCollision]
    \\      [trigger]
    \\        other_tag_pattern:string "wall"
    \\        [action]
    \\          type:string "does_not_exist"
    \\
;

test "a scene referencing a registered custom action instantiates it" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    _ = try h.registry.register(Nudge, "nudge", nudge, null);

    const src = try std.mem.concatWithSentinel(gpa, u8, &.{custom_action_scene}, 0);
    defer gpa.free(src);
    var sf = try scene_format.parseString(gpa, src, "test.scene");
    defer sf.deinit(gpa);

    try h.instantiator.instantiate(&sf);

    // the ball entity exists and carries an OnCollision trigger with one action
    const ball = h.world.findEntityByTag("ball") orelse return error.BallNotFound;
    const on_col = h.world.getComponent(ball, OnCollision) orelse return error.NoOnCollision;
    try testing.expectEqual(@as(usize, 1), on_col.triggers.len);
    try testing.expectEqual(@as(usize, 1), on_col.triggers[0].actions.len);

    // the decoded action resolves to the registered "nudge" id
    const expected_id = h.registry.lookup("nudge").?;
    try testing.expectEqual(expected_id, on_col.triggers[0].actions[0].id);
}

test "a scene referencing an unknown action is an instantiation error, not a crash" {
    const gpa = testing.allocator;
    var h: Harness = undefined;
    try h.init(gpa);
    defer h.deinit();

    // note: "does_not_exist" is never registered

    const src = try std.mem.concatWithSentinel(gpa, u8, &.{unknown_action_scene}, 0);
    defer gpa.free(src);
    var sf = try scene_format.parseString(gpa, src, "test.scene");
    defer sf.deinit(gpa);

    try testing.expectError(error.UnknownActionType, h.instantiator.instantiate(&sf));
}
