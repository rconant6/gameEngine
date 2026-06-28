//! Phase 2B behavior, MIGRATED to the Phase 3 API.
//!
//! Two halves:
//!   1. Executor side — reflect_velocity flips an axis only when the velocity
//!      opposes the surface normal on that axis (vel·n < 0); null normal falls
//!      back to an unconditional flip. Driven through a registry builtin +
//!      the (world, queue, services, dt) executeActions.
//!   2. Trigger side — CollisionTrigger.process stamps ActionContext with a
//!      normal oriented TOWARD self_ent plus the contact penetration. (Trigger
//!      structure is unchanged by Phase 3; only the queued Action's shape is.)

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const ActionExecutor = Action.ActionExecutor;
const ActionRegistry = Action.ActionRegistry;
const ActionQueue = Action.ActionQueue;
const ActionContext = Action.ActionContext;
const CollisionTrigger = Action.CollisionTrigger;
const OnCollision = Action.OnCollision;
const TriggerContext = Action.TriggerContext;
const EngineServices = Action.EngineServices;
const builtins = Action.builtins;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Tag = ecs.Tag;
const Collision = ecs.Collision;

const math = @import("math");
const V2 = math.V2;
const GameMemory = math.GameMemory;

const game_state = @import("game_state");
const GameStateManager = game_state.GameStateManager;
const StateValue = game_state.StateValue;

const eps = 0.0001;

// MARK: stub EngineServices (reflect never calls into it)

fn svcSet(ctx: *anyopaque, key: []const u8, val: StateValue) anyerror!void {
    const mgr: *GameStateManager = @ptrCast(@alignCast(ctx));
    try mgr.setStateVar(key, val);
}
fn svcGet(ctx: *anyopaque, key: []const u8) ?StateValue {
    const mgr: *GameStateManager = @ptrCast(@alignCast(ctx));
    return mgr.getStateVar(key);
}
fn svcNoopName(ctx: *anyopaque, name: []const u8) void {
    _ = ctx;
    _ = name;
}
fn svcNoop(ctx: *anyopaque) void {
    _ = ctx;
}
const vtable = EngineServices.VTable{
    .set_state_var = svcSet,
    .get_state_var = svcGet,
    .transition_to = svcNoopName,
    .restart_state = svcNoop,
    .restart_game = svcNoopName,
};

// MARK: helpers

fn makeBall(world: *World, vel: V2) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Velocity, .{ .linear = vel, .angular = 0 });
    return e;
}

/// Register reflect_velocity, queue one reflect(self, x, y) carrying `normal`,
/// run the executor, return the ball's resulting velocity.
fn runReflect(world: *World, ball: Entity, flip_x: bool, flip_y: bool, normal: ?V2) V2 {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    Action.registerBuiltins(&reg) catch unreachable;

    var mem: GameMemory = undefined;
    mem.init(testing.allocator);
    defer mem.deinit();
    var mgr = GameStateManager.init(&mem);
    defer mgr.deinit();
    var services = EngineServices{ .ctx = &mgr, .vtable = &vtable };

    const params = builtins.ReflectVelocity{ .target = .self, .x = flip_x, .y = flip_y };
    const id = reg.lookup("reflect_velocity").?;
    const action = Action.Action{ .id = id, .params = &params, .priority = 0 };
    const ctx = ActionContext{
        .self_ent = ball,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = normal,
        .collision_penetration = 0.0,
    };

    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    queue.append(action, ctx) catch unreachable;
    ActionExecutor.executeActions(world, &queue, &reg, &services, 0.016);

    return world.getComponent(ball, Velocity).?.linear;
}

// MARK: Executor — normal-aware guard

test "reflect_velocity flips Y when ball moves into a floor" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 3, .y = -5 });
    const result = runReflect(&world, ball, false, true, .{ .x = 0, .y = 1 });

    try testing.expectApproxEqAbs(@as(f32, 3.0), result.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 5.0), result.y, eps); // bounced up
}

test "reflect_velocity does NOT flip Y when ball already moving away from floor" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 3, .y = 5 });
    const result = runReflect(&world, ball, false, true, .{ .x = 0, .y = 1 });

    try testing.expectApproxEqAbs(@as(f32, 3.0), result.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 5.0), result.y, eps);
}

test "reflect_velocity flips X when ball moves into a right wall" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 7, .y = 2 });
    const result = runReflect(&world, ball, true, false, .{ .x = -1, .y = 0 });

    try testing.expectApproxEqAbs(@as(f32, -7.0), result.x, eps); // bounced left
    try testing.expectApproxEqAbs(@as(f32, 2.0), result.y, eps);
}

test "reflect_velocity does NOT flip X when ball moving away from wall" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = -7, .y = 2 });
    const result = runReflect(&world, ball, true, false, .{ .x = -1, .y = 0 });

    try testing.expectApproxEqAbs(@as(f32, -7.0), result.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 2.0), result.y, eps);
}

test "reflect_velocity is corner-safe: a perpendicular normal flips nothing" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 3, .y = -5 });
    const result = runReflect(&world, ball, true, true, .{ .x = 0, .y = 1 });

    try testing.expectApproxEqAbs(@as(f32, 3.0), result.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 5.0), result.y, eps);
}

test "reflect_velocity double-frame: a trapped ball flips exactly once" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 0, .y = -4 });
    const after1 = runReflect(&world, ball, false, true, .{ .x = 0, .y = 1 });
    try testing.expectApproxEqAbs(@as(f32, 4.0), after1.y, eps);

    const after2 = runReflect(&world, ball, false, true, .{ .x = 0, .y = 1 });
    try testing.expectApproxEqAbs(@as(f32, 4.0), after2.y, eps);
}

test "reflect_velocity without a normal flips unconditionally (non-collision triggers)" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try makeBall(&world, .{ .x = 6, .y = -2 });
    const result = runReflect(&world, ball, true, true, null);

    try testing.expectApproxEqAbs(@as(f32, -6.0), result.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 2.0), result.y, eps);
}

// MARK: Trigger side — context carries an oriented normal + penetration
//
// These assert on the queued ActionContext (normal/penetration), not on the
// action payload, so the trigger's action can be any valid post-Phase-3 Action.
// OnCollision still OWNS its triggers/actions — teardown frees them, so the
// fixture hands it allocator-owned slices.


fn addWallReflect(world: *World, ent: Entity) !void {
    const actions = try testing.allocator.alloc(Action.Action, 1);
    actions[0] = .{ .id = 0, .params = null, .priority = 0 }; // placeholder handle; tests assert on context, not execution
    const triggers = try testing.allocator.alloc(CollisionTrigger, 1);
    // Hand-rolled trigger: pattern is a literal, pattern_owned defaults false, so
    // deinit leaves it alone. (This is exactly the no-DSL dev path the flag enables.)
    triggers[0] = .{ .other_tag_pattern = "wall", .actions = actions };
    try world.addComponent(ent, OnCollision, .{ .triggers = triggers });
}

test "CollisionTrigger orients normal toward self when self is entity_a" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const ball = try world.createEntity(); // created first → becomes entity_a
    try addWallReflect(&world, ball);

    const wall = try world.createEntity();
    try world.addComponent(wall, Tag, Tag.init("wall"));

    // detection convention: normal points entity_a → entity_b. Here that's +y.
    // Oriented toward self (the ball, = entity_a) it must come back as -y.
    const collision = Collision{
        .entity_a = ball,
        .entity_b = wall,
        .point = V2.ZERO,
        .normal = .{ .x = 0, .y = 1 },
        .penetration = 0.25,
    };

    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    const tctx = TriggerContext{
        .collision_events = &[_]Collision{collision},
        .action_queue = &queue,
    };

    try CollisionTrigger.process(&world, tctx);

    try testing.expectEqual(@as(usize, 1), queue.actions.items.len);
    const stamped = queue.actions.items[0].context;
    const n = stamped.collision_normal orelse return error.NoNormalStamped;
    try testing.expectApproxEqAbs(@as(f32, 0.0), n.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -1.0), n.y, eps); // toward entity_a
    try testing.expectApproxEqAbs(@as(f32, 0.25), stamped.collision_penetration.?, eps);
}

test "CollisionTrigger keeps normal as-is when self is entity_b" {
    var world = try World.init(testing.allocator);
    defer world.deinit();

    const wall = try world.createEntity(); // entity_a
    try world.addComponent(wall, Tag, Tag.init("wall"));

    const ball = try world.createEntity(); // entity_b, carries the trigger
    try addWallReflect(&world, ball);

    // normal entity_a(wall) → entity_b(ball) is +y, which already points
    // toward self (the ball = entity_b), so it must pass through unchanged.
    const collision = Collision{
        .entity_a = wall,
        .entity_b = ball,
        .point = V2.ZERO,
        .normal = .{ .x = 0, .y = 1 },
        .penetration = 0.5,
    };

    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    const tctx = TriggerContext{
        .collision_events = &[_]Collision{collision},
        .action_queue = &queue,
    };

    try CollisionTrigger.process(&world, tctx);

    try testing.expectEqual(@as(usize, 1), queue.actions.items.len);
    const n = queue.actions.items[0].context.collision_normal orelse return error.NoNormalStamped;
    try testing.expectApproxEqAbs(@as(f32, 0.0), n.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 1.0), n.y, eps); // unchanged, toward entity_b
}
