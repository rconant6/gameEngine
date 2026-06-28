const std = @import("std");
const action_mod = @import("Action.zig");
const Action = action_mod.Action;
const ActionQueue = action_mod.ActionQueue;
const ActionContext = action_mod.ActionContext;
const OnCollision = action_mod.OnCollision;
const OnInput = action_mod.OnInput;
const OnTimer = action_mod.OnTimer;
const platform = @import("platform");
const KeyCode = platform.KeyCode;
const MouseButton = platform.MouseButton;
const Input = platform.Input;
const ecs = @import("ecs");
const Entity = ecs.Entity;
const World = ecs.World;
const Tag = ecs.Tag;
const Collision = ecs.Collision;
const log = @import("debug").log;

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
    collision_events: ?[]const Collision = null,
    input: ?*const Input = null,
    delta_time: ?f32 = null,
    action_queue: *ActionQueue,
};

// MARK: Collision Trigger System
pub const CollisionTrigger = struct {
    pub const Phase = enum { enter, stay };
    pub const MAX_CONTACTS: u32 = 8;

    other_tag_pattern: []const u8,
    actions: []const Action,
    pattern_owned: bool = false,

    // runtime contact tracing
    contacts: [MAX_CONTACTS]usize = undefined, // other-entity ids touched last frame
    contacts_next: [MAX_CONTACTS]usize = undefined, // accumulator of this frame
    contact_count: u32 = 0,
    next_count: u32 = 0,
    phase: Phase = .enter,

    pub fn deinit(self: *CollisionTrigger, gpa: std.mem.Allocator) void {
        if (self.pattern_owned) gpa.free(self.other_tag_pattern);
        gpa.free(self.actions);
    }

    pub fn process(
        world: *World,
        ctx: TriggerContext,
    ) !void {
        const collision_events = ctx.collision_events orelse
            &.{};

        // Events
        for (collision_events) |collision| {
            try checkEntityCollisionTriggers(
                world,
                collision.entity_a,
                collision.entity_b,
                &collision,
                ctx.action_queue,
            );
            try checkEntityCollisionTriggers(
                world,
                collision.entity_b,
                collision.entity_a,
                &collision,
                ctx.action_queue,
            );
        }

        // Post-pass accum into last frame
        var accum = world.query(.{OnCollision});
        while (accum.next()) |entry| {
            const on_col = entry.get(0);
            for (on_col.triggers) |*trigger| {
                @memcpy(
                    trigger.contacts[0..trigger.next_count],
                    trigger.contacts_next[0..trigger.next_count],
                );
                trigger.contact_count = trigger.next_count;
                trigger.next_count = 0;
            }
        }
    }

    fn checkEntityCollisionTriggers(
        world: *World,
        self: Entity,
        other: Entity,
        collision: *const Collision,
        action_queue: *ActionQueue,
    ) !void {
        const on_collision = world.getComponentMut(self, OnCollision) orelse return;
        const other_tag = world.getComponent(other, Tag) orelse return;

        for (on_collision.triggers) |*trigger| {
            if (!other_tag.matchesPattern(trigger.other_tag_pattern)) continue;

            recordContact(trigger, other.id);

            const fire = switch (trigger.phase) {
                .stay => true,
                .enter => !wasContacting(trigger, other.id),
            };
            if (!fire) continue;

            const toward_self = if (self.id == collision.entity_a.id)
                collision.normal.negate()
            else
                collision.normal;

            const context: ActionContext = .{
                .self_ent = self,
                .other_ent = other,
                .collision_loc = collision.point,
                .collision_normal = toward_self,
                .collision_penetration = collision.penetration,
            };

            for (trigger.actions) |action| {
                try action_queue.append(action, context);
            }
        }
    }

    fn wasContacting(trigger: *const CollisionTrigger, id: usize) bool {
        for (trigger.contacts[0..trigger.contact_count]) |c| if (c == id) return true;
        return false;
    }

    fn recordContact(trigger: *CollisionTrigger, id: usize) void {
        for (trigger.contacts_next[0..trigger.next_count]) |c| if (c == id) return;
        if (trigger.next_count >= MAX_CONTACTS) {
            log.warn(
                .action,
                "CollisionTrigger contact overflow (>{d}); treating as continuous",
                .{MAX_CONTACTS},
            );
            return; // overflow not recorded: wasContacting() == false
            // this will materialize as firing when you wouldn't want it

        }
        trigger.contacts_next[trigger.next_count] = id;
        trigger.next_count += 1;
    }
};

// MARK: Input Trigger System
pub const InputTrigger = struct {
    pub const Phase = enum { pressed, held, released };

    input: union(enum) {
        key: KeyCode,
        mouse: MouseButton,
    },
    phase: Phase = .pressed,
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
                    .key => |k| switch (trigger.phase) {
                        .pressed => input.isPressed(k),
                        .held => input.isDown(k),
                        .released => input.isReleased(k),
                    },
                    .mouse => |b| switch (trigger.phase) {
                        .pressed => input.isPressed(b),
                        .held => input.isDown(b),
                        .released => input.isReleased(b),
                    },
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

//MARK: TimeTrigger
pub const TimeTrigger = struct {
    interval: f32, // seconds...required from the scene (can't default)
    repeat: bool = false, // false -> one-shot, true- multi shoot
    elapsed: f32 = 0, // accumulator
    fired: bool = false,
    actions: []const Action,

    pub fn deinit(self: *TimeTrigger, gpa: std.mem.Allocator) void {
        gpa.free(self.actions);
    }

    pub fn process(world: *World, ctx: TriggerContext) !void {
        const dt = ctx.delta_time orelse return error.NoDeltaTime;
        const MAX_CATCHUP = 4; // cap fires per frame (avoids spiral after a hitch)
        var query = world.query(.{OnTimer});
        while (query.next()) |entry| {
            for (entry.get(0).triggers) |*t| {
                if (t.fired and !t.repeat) continue;
                t.elapsed += dt;
                var fires: u32 = 0;
                while (t.elapsed >= t.interval and fires < MAX_CATCHUP) {
                    t.elapsed -= t.interval;
                    fires += 1;
                    t.fired = true;
                    const context: ActionContext = .{
                        .self_ent = entry.entity,
                        .other_ent = null,
                        .collision_loc = null,
                    };
                    for (t.actions) |action| {
                        try ctx.action_queue.append(action, context);
                    }
                    if (!t.repeat) break;
                }
            }
        }
    }
};
