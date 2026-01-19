const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const V2 = @import("math").V2;
const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;

// Custom time-based trigger type
const TimeTrigger = struct {
    interval: f32, // Time in seconds between triggers
    actions: []const Action.Action,

    pub fn deinit(self: *TimeTrigger, gpa: std.mem.Allocator) void {
        gpa.free(self.actions);
    }
};

// Component that holds time-based triggers
const OnTime = Action.ActionBindings(TimeTrigger);

// Component to track elapsed time for time-based triggers
const TimeAccumulator = struct {
    elapsed: []f32, // One elapsed time per trigger
};

// Trigger system that processes time-based triggers
const TimeBasedTriggerSystem = struct {
    pub fn process(
        world: *World,
        ctx: Action.TriggerContext,
    ) !void {
        const delta_time = ctx.delta_time orelse return error.NoDeltaTime;
        var query = world.query(.{OnTime});

        while (query.next()) |entry| {
            const on_time = entry.get(0);

            // Get or create time accumulator for this entity
            var accumulator = world.getComponentMut(entry.entity, TimeAccumulator) orelse continue;

            for (on_time.triggers, 0..) |trigger, i| {
                accumulator.elapsed[i] += delta_time;

                if (accumulator.elapsed[i] >= trigger.interval) {
                    accumulator.elapsed[i] = 0.0;

                    const context: Action.ActionContext = .{
                        .self_ent = entry.entity,
                        .other_ent = null,
                        .collision_loc = null,
                    };

                    for (trigger.actions) |action| {
                        try ctx.action_queue.append(action, context);
                    }
                }
            }
        }
    }
};

test "TimeTrigger - basic structure" {
    const action = Action.Action{
        .action_type = .{ .play_sound = "tick" },
        .priority = 0,
    };

    const trigger = TimeTrigger{
        .interval = 1.0,
        .actions = &[_]Action.Action{action},
    };

    try testing.expectEqual(@as(f32, 1.0), trigger.interval);
    try testing.expectEqual(@as(usize, 1), trigger.actions.len);
}

test "TimeAccumulator - tracking elapsed time" {
    var elapsed = [_]f32{ 0.0, 0.0 };
    var accumulator = TimeAccumulator{
        .elapsed = &elapsed,
    };

    // Simulate time passing
    accumulator.elapsed[0] += 0.3;
    accumulator.elapsed[1] += 0.5;

    try testing.expectEqual(@as(f32, 0.3), accumulator.elapsed[0]);
    try testing.expectEqual(@as(f32, 0.5), accumulator.elapsed[1]);

    // More time passes
    accumulator.elapsed[0] += 0.7;
    try testing.expectEqual(@as(f32, 1.0), accumulator.elapsed[0]);
}

test "TimeAccumulator - reset after threshold" {
    var elapsed = [_]f32{0.8};
    var accumulator = TimeAccumulator{
        .elapsed = &elapsed,
    };

    const interval: f32 = 1.0;
    accumulator.elapsed[0] += 0.3; // Now 1.1

    if (accumulator.elapsed[0] >= interval) {
        accumulator.elapsed[0] = 0.0; // Reset
    }

    try testing.expectEqual(@as(f32, 0.0), accumulator.elapsed[0]);
}

test "OnTime - ActionBindings with TimeTrigger" {
    const action = Action.Action{
        .action_type = .{ .play_sound = "alarm" },
        .priority = 0,
    };

    const trigger = TimeTrigger{
        .interval = 2.0,
        .actions = &[_]Action.Action{action},
    };

    var triggers_array = [_]TimeTrigger{trigger};
    const time_bindings = OnTime{
        .triggers = &triggers_array,
    };

    try testing.expect(time_bindings.hasTriggers());
    try testing.expectEqual(@as(usize, 1), time_bindings.triggers.len);
    try testing.expectEqual(@as(f32, 2.0), time_bindings.triggers[0].interval);
}

test "OnTime - multiple triggers with different intervals" {
    const action1 = Action.Action{
        .action_type = .{ .play_sound = "tick" },
        .priority = 0,
    };

    const action2 = Action.Action{
        .action_type = .{ .play_sound = "tock" },
        .priority = 1,
    };

    const trigger1 = TimeTrigger{
        .interval = 0.5,
        .actions = &[_]Action.Action{action1},
    };

    const trigger2 = TimeTrigger{
        .interval = 1.0,
        .actions = &[_]Action.Action{action2},
    };

    var triggers_array = [_]TimeTrigger{ trigger1, trigger2 };
    const time_bindings = OnTime{
        .triggers = &triggers_array,
    };

    try testing.expectEqual(@as(usize, 2), time_bindings.triggers.len);
    try testing.expectEqual(@as(f32, 0.5), time_bindings.triggers[0].interval);
    try testing.expectEqual(@as(f32, 1.0), time_bindings.triggers[1].interval);
}

test "TimeBasedTriggerSystem - process with delta_time" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const entity = try world.createEntity();

    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    // Allocate actions array on heap for proper cleanup
    const actions = try allocator.alloc(Action.Action, 1);
    actions[0] = action;

    const trigger = TimeTrigger{
        .interval = 1.0,
        .actions = actions,
    };

    // Allocate triggers array on heap for proper cleanup
    const triggers = try allocator.alloc(TimeTrigger, 1);
    triggers[0] = trigger;

    try world.addComponent(entity, OnTime, .{
        .triggers = triggers,
    });

    var elapsed = [_]f32{0.0};
    try world.addComponent(entity, TimeAccumulator, .{
        .elapsed = &elapsed,
    });

    var action_queue = Action.ActionQueue.init(allocator);
    defer action_queue.deinit();

    const ctx = Action.TriggerContext{
        .delta_time = 0.5,
        .action_queue = &action_queue,
    };

    // First tick - should not fire
    try TimeBasedTriggerSystem.process(&world, ctx);
    try testing.expectEqual(@as(usize, 0), action_queue.actions.items.len);

    // Second tick - should fire (0.5 + 0.6 > 1.0)
    const ctx2 = Action.TriggerContext{
        .delta_time = 0.6,
        .action_queue = &action_queue,
    };
    try TimeBasedTriggerSystem.process(&world, ctx2);
    try testing.expectEqual(@as(usize, 1), action_queue.actions.items.len);
    try testing.expectEqual(entity, action_queue.actions.items[0].context.self_ent);
}

test "TimeBasedTriggerSystem - multiple entities" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    const entity1 = try world.createEntity();
    const entity2 = try world.createEntity();

    const action = Action.Action{
        .action_type = .{ .play_sound = "beep" },
        .priority = 0,
    };

    // Allocate for entity1
    const actions1 = try allocator.alloc(Action.Action, 1);
    actions1[0] = action;

    const trigger1 = TimeTrigger{
        .interval = 0.5,
        .actions = actions1,
    };

    const triggers1 = try allocator.alloc(TimeTrigger, 1);
    triggers1[0] = trigger1;

    try world.addComponent(entity1, OnTime, .{
        .triggers = triggers1,
    });
    var elapsed1 = [_]f32{0.0};
    try world.addComponent(entity1, TimeAccumulator, .{
        .elapsed = &elapsed1,
    });

    // Allocate for entity2
    const actions2 = try allocator.alloc(Action.Action, 1);
    actions2[0] = action;

    const trigger2 = TimeTrigger{
        .interval = 0.5,
        .actions = actions2,
    };

    const triggers2 = try allocator.alloc(TimeTrigger, 1);
    triggers2[0] = trigger2;

    try world.addComponent(entity2, OnTime, .{
        .triggers = triggers2,
    });
    var elapsed2 = [_]f32{0.0};
    try world.addComponent(entity2, TimeAccumulator, .{
        .elapsed = &elapsed2,
    });

    var action_queue = Action.ActionQueue.init(allocator);
    defer action_queue.deinit();

    const ctx = Action.TriggerContext{
        .delta_time = 0.6,
        .action_queue = &action_queue,
    };

    try TimeBasedTriggerSystem.process(&world, ctx);

    // Both entities should have triggered
    try testing.expectEqual(@as(usize, 2), action_queue.actions.items.len);
}

test "TimeBasedTriggerSystem - error when no delta_time" {
    const allocator = testing.allocator;

    var world = try World.init(allocator);
    defer world.deinit();

    var action_queue = Action.ActionQueue.init(allocator);
    defer action_queue.deinit();

    const ctx = Action.TriggerContext{
        .delta_time = null,
        .action_queue = &action_queue,
    };

    const result = TimeBasedTriggerSystem.process(&world, ctx);
    try testing.expectError(error.NoDeltaTime, result);
}
