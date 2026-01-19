const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const V2 = @import("math").V2;

test "Action - destroy_self" {
    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    try testing.expectEqual(Action.ActionType.destroy_self, action.action_type);
    try testing.expectEqual(@as(i32, 0), action.priority);
}

test "Action - destroy_other" {
    const action = Action.Action{
        .action_type = .destroy_other,
        .priority = 1,
    };

    try testing.expectEqual(Action.ActionType.destroy_other, action.action_type);
    try testing.expectEqual(@as(i32, 1), action.priority);
}

test "Action - spawn_entity" {
    const action = Action.Action{
        .action_type = .{
            .spawn_entity = .{
                .template_name = "missile",
                .offset = .{ .x = 0.0, .y = 1.0 },
            },
        },
        .priority = 2,
    };

    switch (action.action_type) {
        .spawn_entity => |spawn_data| {
            try testing.expectEqualStrings("missile", spawn_data.template_name);
            try testing.expectEqual(@as(f32, 0.0), spawn_data.offset.x);
            try testing.expectEqual(@as(f32, 1.0), spawn_data.offset.y);
        },
        else => try testing.expect(false),
    }
}

test "Action - set_velocity self" {
    const action = Action.Action{
        .action_type = .{
            .set_velocity = .{
                .target = .self,
                .velocity = .{ .x = 5.0, .y = -3.0 },
            },
        },
        .priority = 0,
    };

    switch (action.action_type) {
        .set_velocity => |vel_data| {
            try testing.expectEqual(Action.ActionTarget.self, vel_data.target);
            try testing.expectEqual(@as(f32, 5.0), vel_data.velocity.x);
            try testing.expectEqual(@as(f32, -3.0), vel_data.velocity.y);
        },
        else => try testing.expect(false),
    }
}

test "Action - set_velocity other" {
    const action = Action.Action{
        .action_type = .{
            .set_velocity = .{
                .target = .other,
                .velocity = .{ .x = 0.0, .y = 0.0 },
            },
        },
        .priority = 5,
    };

    switch (action.action_type) {
        .set_velocity => |vel_data| {
            try testing.expectEqual(Action.ActionTarget.other, vel_data.target);
            try testing.expectEqual(@as(f32, 0.0), vel_data.velocity.x);
            try testing.expectEqual(@as(f32, 0.0), vel_data.velocity.y);
        },
        else => try testing.expect(false),
    }
}

test "Action - play_sound" {
    const action = Action.Action{
        .action_type = .{ .play_sound = "explosion" },
        .priority = 10,
    };

    switch (action.action_type) {
        .play_sound => |sound_name| {
            try testing.expectEqualStrings("explosion", sound_name);
        },
        else => try testing.expect(false),
    }
}

test "Action - priority ordering" {
    const action_low = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const action_high = Action.Action{
        .action_type = .destroy_other,
        .priority = 10,
    };

    try testing.expect(action_low.priority < action_high.priority);
}

test "Action - default priority" {
    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    try testing.expectEqual(@as(i32, 0), action.priority);
}
