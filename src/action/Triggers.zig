const std = @import("std");
const action_mod = @import("Action.zig");
const Action = action_mod.Action;
const ActionQueue = action_mod.ActionQueue;
const ActionContext = action_mod.ActionContext;
const platform = @import("platform");
const KeyCode = platform.KeyCode;
const MouseButton = platform.MouseButton;
const core = @import("core");
const Input = core.Input;
const ecs = @import("entity");
const Entity = ecs.Entity;
const World = ecs.World;
const Tag = ecs.Tag;
const OnCollision = ecs.OnCollision;
const OnInput = ecs.OnInput;
const Collision = ecs.Collision;

pub const Trigger = struct {
    other_tag_pattern: []const u8,
};

pub const TriggerSystem = struct {
    sys: *anyopaque,
    processFn: *const fn (
        ptr: *anyopaque,
        world: *World,
        ctx: TriggerContext,
    ) anyerror!void,
};

// NOTE as more triggers are added this needs to expand with it
pub const TriggerContext = struct {
    collision_events: ?[]Collision = null,
    input: ?*const Input = null,
    delta_time: ?f32 = null,
    action_queue: *ActionQueue,
};

// MARK: Collision Trigger System
pub const CollisionTrigger = struct {
    other_tag_pattern: []const u8,
    actions: []const Action,

    pub fn deinit(self: *CollisionTrigger, gpa: std.mem.Allocator) void {
        gpa.free(self.actions);
    }

    pub fn process(
        world: *World,
        ctx: TriggerContext,
    ) !void {
        const collision_events = ctx.collision_events orelse
            return error.NoCollisionEvents;
        for (collision_events) |*collision| {
            if (collision.actions_fired) continue;
            try checkEntityCollisionTriggers(
                world,
                collision.entity_a,
                collision.entity_b,
                collision,
                ctx.action_queue,
            );
            try checkEntityCollisionTriggers(
                world,
                collision.entity_b,
                collision.entity_a,
                collision,
                ctx.action_queue,
            );

            collision.actions_fired = true;
        }
    }

    fn checkEntityCollisionTriggers(
        world: *World,
        self: Entity,
        other: Entity,
        collision: *const Collision,
        action_queue: *ActionQueue,
    ) !void {
        if (world.getComponent(self, OnCollision)) |on_collision| {
            if (world.getComponent(other, Tag)) |other_tag| {
                for (on_collision.triggers) |trigger| {
                    if (other_tag.matchesPattern(trigger.other_tag_pattern)) {
                        const context: ActionContext = .{
                            .self_ent = self,
                            .other_ent = other,
                            .collision_loc = collision.point,
                        };
                        for (trigger.actions) |action| {
                            try action_queue.append(action, context);
                        }
                    }
                }
            }
        }
    }
};

// MARK: Input Trigger System
pub const InputTrigger = struct {
    input: union(enum) {
        key: KeyCode,
        mouse: MouseButton,
    },
    actions: []const Action,

    pub fn deinit(self: *InputTrigger, gpa: std.mem.Allocator) void {
        gpa.free(self.actions);
    }

    pub fn process(
        world: *World,
        ctx: TriggerContext,
    ) !void {
        const input = ctx.input orelse return error.NoInputProvided;
        var query = world.query(.{OnInput});

        while (query.next()) |entry| {
            const on_input = entry.get(0);

            for (on_input.triggers) |trigger| {
                const should_fire = switch (trigger.input) {
                    .key => |keycode| input.isPressed(keycode),
                    .mouse => |button| input.isPressed(button),
                };

                if (should_fire) {
                    const context: ActionContext = .{
                        .self_ent = entry.entity,
                        .other_ent = null,
                        .collision_loc = null,
                    };

                    for (trigger.actions) |action| {
                        try ctx.action_queue.append(
                            action,
                            context,
                        );
                    }
                }
            }
        }
    }
};
