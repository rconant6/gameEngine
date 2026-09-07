//! Behavioral coverage for ActionExecutor builtin arms other than the bounce/
//! reflect rules (those live in test_reflect_velocity.zig / test_builtin_actions.zig).
//! Exercises the real executeActions path against a live World so latent bugs
//! in the rarely-hit arms can't hide.
//!
//! MIGRATED to the Phase 3 API: builds Actions via a local ActionRegistry +
//! registerBuiltins, runs the (world, queue, services, dt) executeActions.
//!
//! NOTE: spawn_entity is intentionally NOT covered here — it dereferences
//! world.template_manager, which is `undefined` on a bare World. It needs an
//! engine-level / template-manager fixture; see test_template_instantiation.zig.

const std = @import("std");
const testing = std.testing;

const Action = @import("Action");
const ActionExecutor = Action.ActionExecutor;
const ActionRegistry = Action.ActionRegistry;
const ActionQueue = Action.ActionQueue;
const ActionContext = Action.ActionContext;
const EngineServices = Action.EngineServices;
const builtins = Action.builtins;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const Destroy = ecs.Destroy;

const math = @import("math");
const V2 = math.V2;
const GameMemory = @import("memory");

const game_state = @import("game_state");
const GameStateManager = game_state.GameStateManager;
const StateValue = game_state.StateValue;

const eps = 0.0001;

// MARK: stub EngineServices (these arms never call into it, but the signature
// requires a non-null services pointer)

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

/// Shared fixture: world + state manager + registry-with-builtins + services.
const Fix = struct {
    world: World,
    mem: GameMemory,
    mgr: GameStateManager,
    reg: ActionRegistry,
    services: EngineServices,

    fn init(self: *Fix, gpa: std.mem.Allocator) !void {
        self.world = try World.init(gpa);
        self.mem = undefined;
        self.mem.init(gpa);
        self.mgr = GameStateManager.init(&self.mem);
        self.reg = ActionRegistry.init(gpa);
        try Action.registerBuiltins(&self.reg);
        self.services = .{ .ctx = &self.mgr, .vtable = &vtable };
    }
    fn deinit(self: *Fix) void {
        self.reg.deinit();
        self.mgr.deinit();
        self.mem.deinit();
        self.world.deinit();
    }
    fn action(self: *const Fix, name: []const u8, params: ?*const anyopaque, priority: i32) Action.Action {
        const id = self.reg.lookup(name).?;
        return .{ .id = id, .params = params, .priority = priority };
    }
    fn run(self: *Fix, act: Action.Action, ctx: ActionContext) void {
        var queue = ActionQueue.init(testing.allocator);
        defer queue.deinit();
        queue.append(act, ctx) catch unreachable;
        ActionExecutor.executeActions(&self.world, &queue, &self.reg, &self.services, 0.016);
    }
};

fn ctxSelf(self: Entity) ActionContext {
    return .{ .self_ent = self, .other_ent = null, .collision_loc = null };
}
fn ctxPair(self: Entity, other: Entity) ActionContext {
    return .{ .self_ent = self, .other_ent = other, .collision_loc = null };
}

// MARK: destroy_self

test "destroy_self tags the self entity with Destroy" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });
    try testing.expect(!f.world.hasComponent(e, Destroy));

    f.run(f.action("destroy_self", null, 0), ctxSelf(e));

    try testing.expect(f.world.hasComponent(e, Destroy));
}

test "destroy_self twice is a clean no-op (Destroy is a boolean tag)" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });

    f.run(f.action("destroy_self", null, 0), ctxSelf(e));
    f.run(f.action("destroy_self", null, 0), ctxSelf(e));

    try testing.expect(f.world.hasComponent(e, Destroy));
}

// MARK: destroy_other

test "destroy_other tags the other entity, not self" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const self = try f.world.createEntity();
    try f.world.addComponent(self, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });
    const other = try f.world.createEntity();
    try f.world.addComponent(other, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });

    f.run(f.action("destroy_other", null, 0), ctxPair(self, other));

    try testing.expect(f.world.hasComponent(other, Destroy));
    try testing.expect(!f.world.hasComponent(self, Destroy));
}

test "destroy_other with no other entity is a safe no-op" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const self = try f.world.createEntity();
    try f.world.addComponent(self, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });

    f.run(f.action("destroy_other", null, 0), ctxSelf(self));

    try testing.expect(!f.world.hasComponent(self, Destroy));
}

// MARK: set_velocity

test "set_velocity overwrites the target's velocity (self)" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Velocity, .{ .linear = .{ .x = 1, .y = 1 }, .angular = 0 });

    const p = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 10, .y = -4 } };
    f.run(f.action("set_velocity", &p, 0), ctxSelf(e));

    const v = f.world.getComponent(e, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 10.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, -4.0), v.y, eps);
}

test "set_velocity targets the other entity when asked" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const self = try f.world.createEntity();
    try f.world.addComponent(self, Velocity, .{ .linear = .{ .x = 1, .y = 1 }, .angular = 0 });
    const other = try f.world.createEntity();
    try f.world.addComponent(other, Velocity, .{ .linear = .{ .x = 1, .y = 1 }, .angular = 0 });

    const p = builtins.SetVelocity{ .target = .other, .velocity = .{ .x = 5, .y = 6 } };
    f.run(f.action("set_velocity", &p, 0), ctxPair(self, other));

    const ov = f.world.getComponent(other, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 5.0), ov.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 6.0), ov.y, eps);

    const sv = f.world.getComponent(self, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 1.0), sv.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 1.0), sv.y, eps);
}

test "set_velocity target=other with no other entity is a safe no-op" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const self = try f.world.createEntity();
    try f.world.addComponent(self, Velocity, .{ .linear = .{ .x = 1, .y = 2 }, .angular = 0 });

    const p = builtins.SetVelocity{ .target = .other, .velocity = .{ .x = 99, .y = 99 } };
    f.run(f.action("set_velocity", &p, 0), ctxSelf(self));

    const v = f.world.getComponent(self, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 1.0), v.x, eps);
    try testing.expectApproxEqAbs(@as(f32, 2.0), v.y, eps);
}

test "set_velocity on an entity without Velocity is a safe no-op" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Transform, .{ .position = V2.ZERO, .rotation = 0, .scale = 1 });

    const p = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 3, .y = 3 } };
    f.run(f.action("set_velocity", &p, 0), ctxSelf(e));

    try testing.expect(!f.world.hasComponent(e, Velocity));
}

// MARK: priority ordering

test "executeActions applies actions in ascending priority order" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Velocity, .{ .linear = V2.ZERO, .angular = 0 });

    // distinct params must each outlive the executeActions call
    const p_hi = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 1, .y = 0 } };
    const p_lo = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 2, .y = 0 } };
    const p_mid = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 3, .y = 0 } };

    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();

    // appended out of order; ascending sort runs highest priority LAST → it wins
    queue.append(f.action("set_velocity", &p_hi, 10), ctxSelf(e)) catch unreachable;
    queue.append(f.action("set_velocity", &p_lo, -5), ctxSelf(e)) catch unreachable;
    queue.append(f.action("set_velocity", &p_mid, 0), ctxSelf(e)) catch unreachable;

    ActionExecutor.executeActions(&f.world, &queue, &f.reg, &f.services, 0.016);

    // order: -5 (vx=2), 0 (vx=3), 10 (vx=1) → last write is vx=1
    const v = f.world.getComponent(e, Velocity).?.linear;
    try testing.expectApproxEqAbs(@as(f32, 1.0), v.x, eps);
}

test "executeActions clears the queue after running" {
    var f: Fix = undefined;
    try f.init(testing.allocator);
    defer f.deinit();

    const e = try f.world.createEntity();
    try f.world.addComponent(e, Velocity, .{ .linear = V2.ZERO, .angular = 0 });

    const p = builtins.SetVelocity{ .target = .self, .velocity = .{ .x = 7, .y = 0 } };

    var queue = ActionQueue.init(testing.allocator);
    defer queue.deinit();
    queue.append(f.action("set_velocity", &p, 0), ctxSelf(e)) catch unreachable;

    ActionExecutor.executeActions(&f.world, &queue, &f.reg, &f.services, 0.016);
    try testing.expectEqual(@as(usize, 0), queue.actions.items.len);

    // a second run with an empty queue is a harmless no-op
    ActionExecutor.executeActions(&f.world, &queue, &f.reg, &f.services, 0.016);
    try testing.expectEqual(@as(usize, 0), queue.actions.items.len);
}
