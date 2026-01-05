const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const CollisionTrigger = Action.CollisionTrigger;
const V2 = @import("core").V2;

test "CollisionTrigger - basic structure" {
    const action = Action.Action{
        .action_type = .destroy_other,
        .priority = 0,
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "brick",
        .actions = &[_]Action.Action{action},
    };

    try testing.expectEqualStrings("brick", trigger.other_tag_pattern);
    try testing.expectEqual(@as(usize, 1), trigger.actions.len);
}

test "CollisionTrigger - exact tag pattern" {
    const actions = [_]Action.Action{
        .{ .action_type = .destroy_other, .priority = 0 },
        .{ .action_type = .{ .play_sound = "hit" }, .priority = 1 },
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "enemy",
        .actions = &actions,
    };

    try testing.expectEqualStrings("enemy", trigger.other_tag_pattern);
    try testing.expectEqual(@as(usize, 2), trigger.actions.len);
}

test "CollisionTrigger - prefix wildcard pattern" {
    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "enemy*",
        .actions = &[_]Action.Action{action},
    };

    try testing.expectEqualStrings("enemy*", trigger.other_tag_pattern);
}

test "CollisionTrigger - suffix wildcard pattern" {
    const action = Action.Action{
        .action_type = .destroy_other,
        .priority = 0,
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "*_boss",
        .actions = &[_]Action.Action{action},
    };

    try testing.expectEqualStrings("*_boss", trigger.other_tag_pattern);
}

test "CollisionTrigger - multiple actions with priorities" {
    const actions = [_]Action.Action{
        .{ .action_type = .destroy_other, .priority = 0 },
        .{ .action_type = .destroy_self, .priority = 5 },
        .{ .action_type = .{ .play_sound = "explosion" }, .priority = 10 },
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "wall",
        .actions = &actions,
    };

    try testing.expectEqual(@as(usize, 3), trigger.actions.len);
    try testing.expectEqual(@as(i32, 0), trigger.actions[0].priority);
    try testing.expectEqual(@as(i32, 5), trigger.actions[1].priority);
    try testing.expectEqual(@as(i32, 10), trigger.actions[2].priority);
}

test "CollisionTrigger - spawn action on collision" {
    const action = Action.Action{
        .action_type = .{
            .spawn_entity = .{
                .template_name = "explosion_particle",
                .offset = .{ .x = 0.0, .y = 0.0 },
            },
        },
        .priority = 0,
    };

    const trigger = CollisionTrigger{
        .other_tag_pattern = "destructible",
        .actions = &[_]Action.Action{action},
    };

    try testing.expectEqualStrings("destructible", trigger.other_tag_pattern);
    switch (trigger.actions[0].action_type) {
        .spawn_entity => |spawn_data| {
            try testing.expectEqualStrings("explosion_particle", spawn_data.template_name);
        },
        else => try testing.expect(false),
    }
}
