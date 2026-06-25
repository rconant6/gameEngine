const std = @import("std");
const Allocator = std.mem.Allocator;
const act = @import("Action.zig");
const Action = act.Action;
const ActionRunContext = act.ActionRunContext;
const ActionTarget = act.ActionTarget;
const actReg = @import("ActionRegistry.zig");
const ActionRegistry = actReg.ActionRegistry;
const DecodeFn = actReg.DecodeFn;
const ecs = @import("ecs");
const Destroy = ecs.Destroy;
const Entity = ecs.Entity;
const Transform = ecs.Transform;
const Velocity = ecs.Velocity;
const World = ecs.World;
const math = @import("math");
const V2 = math.V2;
const game_state = @import("game_state");
const StateValue = game_state.StateValue;
const scene_fmt = @import("scene-format");
const Property = scene_fmt.Property;
const log = @import("debug").log;

pub const DestroySelf = struct {};
pub const DestroyOther = struct {};
pub const SpawnEntity = struct { template_name: []const u8, offset: V2 };
pub const SetVelocity = struct { target: ActionTarget, velocity: V2 };
pub const ReflectVelocity = struct {
    target: ActionTarget,
    x: bool = false,
    y: bool = false,
};
pub const Bounce = struct {
    target: ActionTarget = .self,
    restitution: f32 = 1.0,
    separate: bool = true,
};
pub const DebugPrint = struct { msg: []const u8 };
pub const PlaySound = struct { name: []const u8 };
// set_state_var has a custom decode (reads the value's type annotation to pick
// the StateValue variant); its decoded params are a plain key+value pair.
pub const SetStateVar = struct { key: []const u8, value: StateValue };
pub const AddStateInt = struct { key: []const u8, amount: i64 = 1 };
pub const TransitionState = struct { name: []const u8 };
pub const RestartState = struct {};
pub const RestartGame = struct { name: []const u8 };

pub fn registerBuiltins(reg: *ActionRegistry) !void {
    _ = try reg.register(SetStateVar, "set_state_var", setStateVar, setStateVarDecode);
    _ = try reg.register(DestroySelf, "destroy_self", destroySelf, null);
    _ = try reg.register(DestroyOther, "destroy_other", destroyOther, null);
    _ = try reg.register(SpawnEntity, "spawn_entity", spawnEntity, null);
    _ = try reg.register(SetVelocity, "set_velocity", setVelocity, null);
    _ = try reg.register(ReflectVelocity, "reflect_velocity", reflectVelocity, null);
    _ = try reg.register(Bounce, "bounce", bounce, null);
    _ = try reg.register(DebugPrint, "debug_print", debugPrint, null);
    _ = try reg.register(PlaySound, "play_sound", playSound, null);
    _ = try reg.register(AddStateInt, "add_state_int", addStateInt, null);
    _ = try reg.register(TransitionState, "transition_state", transitionState, null);
    _ = try reg.register(RestartState, "restart_state", restartState, null);
    _ = try reg.register(RestartGame, "restart_game", restartGame, null);
}

fn destroySelf(ctx: *ActionRunContext, _: DestroySelf) void {
    // Re-marking an already-doomed entity is normal (two triggers in
    // one frame) — Destroy is a boolean tag, so a second add is a no-op.
    const self_ent = ctx.self_ent;
    if (!ctx.world.hasComponent(self_ent, Destroy)) {
        ctx.world.addComponent(self_ent, Destroy, .{}) catch |err| {
            log.err(
                .action,
                "destroy_self failed on entity-id: {d}    {any}",
                .{ self_ent.id, err },
            );
        };
    }
}
fn destroyOther(ctx: *ActionRunContext, _: DestroyOther) void {
    const other = ctx.other_ent orelse {
        log.warn(.action, "destroy_other has no other entity", .{});
        return;
    };
    if (!ctx.world.hasComponent(other, Destroy)) {
        ctx.world.addComponent(other, Destroy, .{}) catch |err| {
            log.err(
                .action,
                "destroy_other failed on entity-id: {d}   {any}",
                .{ other.id, err },
            );
        };
    }
}
fn spawnEntity(ctx: *ActionRunContext, sd: SpawnEntity) void {
    const name = sd.template_name;
    //BUG: this is wrong...need transform and sprite?
    var loc = ctx.collision_loc orelse V2.ZERO;
    loc = loc.add(sd.offset);

    const entity = ctx.world.createEntityFromTemplate(
        name,
        loc,
    ) catch |err| {
        log.err(
            .action,
            "Unable to create entity from template: {s} {any}",
            .{ name, err },
        );
        return;
    };
    log.info(.action, "Created entity: {d} from {s} at {f}", .{
        entity.id,
        name,
        loc,
    });
}
fn setVelocity(ctx: *ActionRunContext, sv: SetVelocity) void {
    const target = resolveTarget(ctx, sv.target) orelse {
        log.warn(
            .action,
            "set_velocity target=other but no other_entity",
            .{},
        );
        return;
    };

    if (ctx.world.getComponentMut(target, Velocity)) |velocity| {
        velocity.linear = sv.velocity;
    } else {
        log.warn(
            .action,
            "set_velocity: entity {d} has no Velocity component",
            .{target.id},
        );
    }
}
fn reflectVelocity(ctx: *ActionRunContext, rv: ReflectVelocity) void {
    const target = resolveTarget(ctx, rv.target) orelse {
        log.warn(.action, "reflect_velocity target=other but no other_entity", .{});
        return;
    };

    if (ctx.world.getComponentMut(target, Velocity)) |velocity| {
        if (ctx.collision_normal) |n| {
            if (rv.x and velocity.linear.x * n.x < 0) velocity.linear.x = -velocity.linear.x;
            if (rv.y and velocity.linear.y * n.y < 0) velocity.linear.y = -velocity.linear.y;
        } else {
            if (rv.x) velocity.linear.x = -velocity.linear.x;
            if (rv.y) velocity.linear.y = -velocity.linear.y;
        }
    } else {
        log.warn(
            .action,
            "reflect_velocity: entity {d} has no Velocity component",
            .{target.id},
        );
    }
}
fn bounce(ctx: *ActionRunContext, b: Bounce) void {
    const target = resolveTarget(ctx, b.target) orelse return;
    const n = ctx.collision_normal orelse {
        log.warn(.action, "bounce without a collision", .{});
        return;
    };
    const v = ctx.world.getComponentMut(target, Velocity) orelse return;
    const d = v.linear.dot(n);
    if (d < 0) {
        v.linear = v.linear.sub(n.mul((1.0 + b.restitution) * d));
    }
    if (b.separate) {
        if (ctx.collision_penetration) |pen| {
            if (ctx.world.getComponentMut(target, Transform)) |t| {
                t.position = t.position.add(n.mul(pen + 0.001));
            }
        }
    }
}
fn debugPrint(_: *ActionRunContext, dp: DebugPrint) void {
    log.debug(
        .action,
        "{s}",
        .{dp.msg},
    );
}
fn playSound(_: *ActionRunContext, ps: PlaySound) void {
    log.debug(.action, "play sound {s}", .{ps.name});
}
fn addStateInt(ctx: *ActionRunContext, as: AddStateInt) void {
    const base: i64 = if (ctx.services.getStateVar(as.key)) |c| switch (c) {
        .int => |v| v,
        else => blk: {
            log.warn(.action, "non-int state var '{s}' passed to add_state_int", .{as.key});
            break :blk 0;
        },
    } else 0;
    ctx.services.setStateVar(as.key, .{ .int = base + as.amount }) catch |err| {
        log.err(
            .action,
            "Unable to set {s} with val {d}:   {any}",
            .{ as.key, as.amount, err },
        );
    };
}
fn transitionState(ctx: *ActionRunContext, ts: TransitionState) void {
    ctx.services.transitionTo(ts.name);
}
fn restartState(ctx: *ActionRunContext, _: RestartState) void {
    ctx.services.restartState();
}
fn restartGame(ctx: *ActionRunContext, rs: RestartGame) void {
    ctx.services.restartGame(rs.name);
}
fn setStateVar(ctx: *ActionRunContext, kv: SetStateVar) void {
    ctx.services.setStateVar(kv.key, kv.value) catch |err| {
        log.err(
            .action,
            "unable to set {any} to key {s}:  {any}",
            .{ kv.value, kv.key, err },
        );
    };
}

fn resolveTarget(ctx: *ActionRunContext, target: ActionTarget) ?Entity {
    return switch (target) {
        .self => ctx.self_ent,
        .other => ctx.other_ent,
    };
}

// Custom decode for set_state_var: the StateValue variant is chosen by the
// value's TYPE ANNOTATION, not its Value kind — the lexer stores all numbers as
// f64, so .number alone can't tell int from float. Handed to register's
// decode_fn slot; signature must match ActionRegistry.DecodeFn exactly.
fn setStateVarDecode(
    game: Allocator,
    props: []const Property,
) anyerror!?*const anyopaque {
    const key_prop = getProperty(props, "key") orelse return error.MissingActionParam;
    const val_prop = getProperty(props, "value") orelse return error.MissingActionParam;

    const key = switch (key_prop.value) {
        .string => |s| try game.dupe(u8, s),
        else => return error.ActionStringTypeMismatch,
    };

    const value: StateValue = switch (val_prop.type_annotation.base_type) {
        .i32, .u32 => .{ .int = @intFromFloat(val_prop.value.number) },
        .f32 => .{ .float = @floatCast(val_prop.value.number) },
        .bool => .{ .bool = val_prop.value.boolean },
        .string => .{ .string = try game.dupe(u8, val_prop.value.string) },
        else => return error.ActionStateValueUnsupportedType, // color/vec2/vec3/asset
    };

    const out = try game.create(SetStateVar);
    out.* = .{ .key = key, .value = value };
    return out;
}

// Local copy — keeps builtin_actions self-contained (the registry's getProperty
// is file-private there).
fn getProperty(props: []const Property, name: []const u8) ?Property {
    for (props) |prop| {
        if (std.mem.eql(u8, prop.name, name)) return prop;
    }
    return null;
}
