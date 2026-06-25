//! Phase 3G — builtin action behavior tests.
//!
//! RED until Phase 3A–3F land. References the planned API:
//!   - Action.registerBuiltins(reg)        (src/action/builtin_actions.zig)
//!   - Action.builtins.{SetVelocity, ReflectVelocity, Bounce, AddStateInt, ...}
//!     param structs exported for fixture construction
//!   - Action.EngineServices                (vtable; src/action/EngineServices.zig)
//!   - Action.ActionRunContext / new Action shape / ActionExecutor.executeActions
//!     with the (world, queue, services, dt) signature
//!
//! Covers the 3G "Builtin behavior tests" bullet: set_velocity / reflect
//! (guarded) / bounce (reflects once + separates by penetration) / add_state_int
//! (driven through a stub EngineServices over a real GameStateManager).

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const ActionRegistry = Action.ActionRegistry;
const ActionQueue = Action.ActionQueue;
const ActionContext = Action.ActionContext;
const ActionExecutor = Action.ActionExecutor;
const EngineServices = Action.EngineServices;
const builtins = Action.builtins;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;

const math = @import("math");
const V2 = math.V2;
const GameMemory = math.GameMemory;

const game_state = @import("game_state");
const GameStateManager = game_state.GameStateManager;
const StateValue = game_state.StateValue;

const eps = 0.0001;

// MARK: stub EngineServices over a real GameStateManager
//
// The plan's "tiny test harness standing in for Engine": just enough vtable to
// let state-mutating builtins (add_state_int) reach a real state manager.

fn svcSetStateVar(ctx: *anyopaque, key: []const u8, val: StateValue) anyerror!void {
    const mgr: *GameStateManager = @ptrCast(@alignCast(ctx));
    try mgr.setStateVar(key, val);
}
fn svcGetStateVar(ctx: *anyopaque, key: []const u8) ?StateValue {
    const mgr: *GameStateManager = @ptrCast(@alignCast(ctx));
    return mgr.getStateVar(key);
}
fn svcTransitionTo(ctx: *anyopaque, name: []const u8) void {
    _ = ctx;
    _ = name;
}
fn svcRestartState(ctx: *anyopaque) void {
    _ = ctx;
}
fn svcRestartGame(ctx: *anyopaque, name: []const u8) void {
    _ = ctx;
    _ = name;
}

const stub_vtable = EngineServices.VTable{
    .set_state_var = svcSetStateVar,
    .get_state_var = svcGetStateVar,
    .transition_to = svcTransitionTo,
    .restart_state = svcRestartState,
    .restart_game = svcRestartGame,
};

fn stubServices(mgr: *GameStateManager) EngineServices {
    return .{ .ctx = mgr, .vtable = &stub_vtable };
}

// MARK: helpers

fn makeBall(world: *World, pos: V2, vel: V2) !Entity {
    const e = try world.createEntity();
    try world.addComponent(e, Transform, .{ .position = pos, .rotation = 0, .scale = 1 });
    try world.addComponent(e, Velocity, .{ .linear = vel, .angular = 0 });
    return e;
}

/// Queue one already-built Action against `ball` with the given collision info,
/// run the executor, return nothing — caller inspects the world/state after.
fn runAction(
    world: *World,
    reg: *const ActionRegistry,
    services: *EngineServices,
    action: Action.Action,
    ctx: ActionContext,
) void {
    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    queue.append(action, ctx) catch unreachable;
    ActionExecutor.executeActions(world, &queue, reg, services, 0.016);
}

/// Build an Action handle from a registered builtin name + a (stack-owned in
/// these tests) decoded params pointer. Behavior resolves through the registry
/// by id — the handle is just { id, params, priority }.
fn actionFor(reg: *const ActionRegistry, name: []const u8, params: ?*const anyopaque) Action.Action {
    const id = reg.lookup(name).?;
    return .{ .id = id, .params = params, .priority = 0 };
}

// MARK: set_velocity

test "builtin set_velocity overwrites the target velocity" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    const ball = try makeBall(&world, V2.ZERO, .{ .x = 1, .y = 1 });

    const params = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 8, .y = -2 } };
    const action = actionFor(&reg, "set_velocity", &params);
    runAction(&world, &reg, &services, action, .{ .self_ent = ball, .other_ent = null, .collision_loc = null });

    const v = world.getComponent(ball, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 8.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -2.0), v.y, eps);
}

// MARK: reflect_velocity (normal-guarded, same rule as Phase 2B)

test "builtin reflect_velocity flips only when moving into the surface" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    // moving down into a floor whose normal points up → flips
    const into = try makeBall(&world, V2.ZERO, .{ .x = 3, .y = -5 });
    const params = builtins.ReflectVelocity{ .target = .self, .y = true };
    const a1 = actionFor(&reg, "reflect_velocity", &params);
    runAction(&world, &reg, &services, a1, .{
        .self_ent = into,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = .{ .x = 0, .y = 1 },
        .collision_penetration = 0,
    });
    try testing.expectApproxEqAbs(@as(f32, 5.0), world.getComponent(into, Velocity).?.linear.y, eps);

    // already moving away (up) but still overlapping → must NOT flip
    const away = try makeBall(&world, V2.ZERO, .{ .x = 3, .y = 5 });
    const a2 = actionFor(&reg, "reflect_velocity", &params);
    runAction(&world, &reg, &services, a2, .{
        .self_ent = away,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = .{ .x = 0, .y = 1 },
        .collision_penetration = 0,
    });
    try testing.expectApproxEqAbs(@as(f32, 5.0), world.getComponent(away, Velocity).?.linear.y, eps);
}

// MARK: bounce (new) — reflect about the normal once, separate by penetration

test "builtin bounce reflects velocity about the normal once" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    // ball at y=10 moving down, floor normal +y, restitution 1, no separation
    const ball = try makeBall(&world, .{ .x = 0, .y = 10 }, .{ .x = 2, .y = -6 });
    const params = builtins.Bounce{ .target = .self, .restitution = 1.0, .separate = false };
    const action = actionFor(&reg, "bounce", &params);
    runAction(&world, &reg, &services, action, .{
        .self_ent = ball,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = .{ .x = 0, .y = 1 },
        .collision_penetration = 0.0,
    });

    const v = world.getComponent(ball, Velocity).?.linear;
    // v - (1+e)(v·n) n  with v=(2,-6), n=(0,1), e=1 → (2, 6); x untouched
    try testing.expectApproxEqAbs(@as(f32, 2.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 6.0), v.y, eps);
}

test "builtin bounce does not flip a ball already moving away" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    // moving up (away from floor) but overlapping; bounce must leave it alone
    const ball = try makeBall(&world, V2.ZERO, .{ .x = 1, .y = 4 });
    const params = builtins.Bounce{ .target = .self, .restitution = 1.0, .separate = false };
    const action = actionFor(&reg, "bounce", &params);
    runAction(&world, &reg, &services, action, .{
        .self_ent = ball,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = .{ .x = 0, .y = 1 },
        .collision_penetration = 0.0,
    });

    try testing.expectApproxEqAbs(@as(f32, 4.0), world.getComponent(ball, Velocity).?.linear.y, eps);
}

test "builtin bounce separates the ball out by penetration when asked" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    // overlapping a floor by 0.5; separate=true pushes the ball along +n
    const ball = try makeBall(&world, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = -3 });
    const params = builtins.Bounce{ .target = .self, .restitution = 1.0, .separate = true };
    const action = actionFor(&reg, "bounce", &params);
    runAction(&world, &reg, &services, action, .{
        .self_ent = ball,
        .other_ent = null,
        .collision_loc = V2.ZERO,
        .collision_normal = .{ .x = 0, .y = 1 },
        .collision_penetration = 0.5,
    });

    // pushed out by penetration (+ a small epsilon) along the normal
    const pos = world.getComponent(ball, Transform).?.position;
    try testing.expect(pos.y >= 0.5);
}

// MARK: add_state_int (state-mutating builtin through services)

test "builtin add_state_int starts from zero on a missing var" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    const e = try world.createEntity();
    const params = builtins.AddStateInt{ .key = "score", .amount = 100 };
    const action = actionFor(&reg, "add_state_int", &params);
    runAction(&world, &reg, &services, action, .{ .self_ent = e, .other_ent = null, .collision_loc = null });

    const v = mgr.getStateVar("score") orelse return error.StateVarMissing;
    try testing.expect(v == .int);
    try testing.expectEqual(@as(i64, 100), v.int);
}

test "builtin add_state_int accumulates onto an existing int" {
    var reg = ActionRegistry.init(testing.allocator);
    defer reg.deinit();
    try Action.registerBuiltins(&reg);

    var world = try World.init(testing.allocator);
    defer world.deinit();
    var mgr_mem: GameMemory = undefined;
    mgr_mem.init(testing.allocator);
    defer mgr_mem.deinit();
    var mgr = GameStateManager.init(&mgr_mem);
    defer mgr.deinit();
    var services = stubServices(&mgr);

    try mgr.setStateVar("bricks", .{ .int = 10 });

    const e = try world.createEntity();
    const params = builtins.AddStateInt{ .key = "bricks", .amount = -1 };
    const action = actionFor(&reg, "add_state_int", &params);
    runAction(&world, &reg, &services, action, .{ .self_ent = e, .other_ent = null, .collision_loc = null });

    const v = mgr.getStateVar("bricks").?;
    try testing.expectEqual(@as(i64, 9), v.int);
}
