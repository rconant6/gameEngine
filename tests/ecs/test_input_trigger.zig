const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const InputTrigger = Action.InputTrigger;
const V2 = @import("core").V2;
const platform = @import("platform");
const KeyCode = platform.KeyCode;
const MouseButton = platform.MouseButton;

test "InputTrigger - keyboard trigger" {
    const action = Action.Action{
        .action_type = .{
            .spawn_entity = .{
                .template_name = "missile",
                .offset = .{ .x = 0.0, .y = 1.0 },
            },
        },
        .priority = 0,
    };

    const trigger = InputTrigger{
        .input = .{ .key = KeyCode.Space },
        .actions = &[_]Action.Action{action},
    };

    switch (trigger.input) {
        .key => |k| try testing.expectEqual(KeyCode.Space, k),
        .mouse => try testing.expect(false),
    }
    try testing.expectEqual(@as(usize, 1), trigger.actions.len);
}

test "InputTrigger - mouse trigger" {
    const action = Action.Action{
        .action_type = .{ .play_sound = "shoot" },
        .priority = 0,
    };

    const trigger = InputTrigger{
        .input = .{ .mouse = MouseButton.Left },
        .actions = &[_]Action.Action{action},
    };

    switch (trigger.input) {
        .mouse => |button| try testing.expectEqual(MouseButton.Left, button),
        .key => try testing.expect(false),
    }
    try testing.expectEqual(@as(usize, 1), trigger.actions.len);
}

test "InputTrigger - keyboard with sound action" {
    const action = Action.Action{
        .action_type = .{ .play_sound = "shoot" },
        .priority = 0,
    };

    const trigger = InputTrigger{
        .input = .{ .key = KeyCode.Space },
        .actions = &[_]Action.Action{action},
    };

    switch (trigger.input) {
        .key => |k| try testing.expectEqual(KeyCode.Space, k),
        .mouse => try testing.expect(false),
    }
    switch (trigger.actions[0].action_type) {
        .play_sound => |sound| {
            try testing.expectEqualStrings("shoot", sound);
        },
        else => try testing.expect(false),
    }
}

test "InputTrigger - keyboard with multiple actions" {
    const actions = [_]Action.Action{
        .{
            .action_type = .{
                .spawn_entity = .{
                    .template_name = "missile",
                    .offset = .{ .x = 0.0, .y = 1.0 },
                },
            },
            .priority = 0,
        },
        .{ .action_type = .{ .play_sound = "fire" }, .priority = 1 },
        .{
            .action_type = .{
                .set_velocity = .{
                    .target = .self,
                    .velocity = .{ .x = 0.0, .y = -1.0 },
                },
            },
            .priority = 2,
        },
    };

    const trigger = InputTrigger{
        .input = .{ .key = KeyCode.Space },
        .actions = &actions,
    };

    try testing.expectEqual(@as(usize, 3), trigger.actions.len);
    try testing.expectEqual(@as(i32, 0), trigger.actions[0].priority);
    try testing.expectEqual(@as(i32, 1), trigger.actions[1].priority);
    try testing.expectEqual(@as(i32, 2), trigger.actions[2].priority);
}

test "InputTrigger - different keyboard keys" {
    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const space_trigger = InputTrigger{
        .input = .{ .key = KeyCode.Space },
        .actions = &[_]Action.Action{action},
    };

    const escape_trigger = InputTrigger{
        .input = .{ .key = KeyCode.Esc },
        .actions = &[_]Action.Action{action},
    };

    switch (space_trigger.input) {
        .key => |k| try testing.expectEqual(KeyCode.Space, k),
        .mouse => try testing.expect(false),
    }
    switch (escape_trigger.input) {
        .key => |k| try testing.expectEqual(KeyCode.Esc, k),
        .mouse => try testing.expect(false),
    }
}

test "InputTrigger - different mouse buttons" {
    const action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const left_trigger = InputTrigger{
        .input = .{ .mouse = MouseButton.Left },
        .actions = &[_]Action.Action{action},
    };

    const right_trigger = InputTrigger{
        .input = .{ .mouse = MouseButton.Right },
        .actions = &[_]Action.Action{action},
    };

    switch (left_trigger.input) {
        .mouse => |button| try testing.expectEqual(MouseButton.Left, button),
        .key => try testing.expect(false),
    }
    switch (right_trigger.input) {
        .mouse => |button| try testing.expectEqual(MouseButton.Right, button),
        .key => try testing.expect(false),
    }
}

test "InputTrigger - keyboard movement with velocity" {
    const move_up = Action.Action{
        .action_type = .{
            .set_velocity = .{
                .target = .self,
                .velocity = .{ .x = 0.0, .y = -5.0 },
            },
        },
        .priority = 0,
    };

    const trigger = InputTrigger{
        .input = .{ .key = KeyCode.W },
        .actions = &[_]Action.Action{move_up},
    };

    switch (trigger.input) {
        .key => |k| try testing.expectEqual(KeyCode.W, k),
        .mouse => try testing.expect(false),
    }
    switch (trigger.actions[0].action_type) {
        .set_velocity => |vel_data| {
            try testing.expectEqual(@as(f32, 0.0), vel_data.velocity.x);
            try testing.expectEqual(@as(f32, -5.0), vel_data.velocity.y);
        },
        else => try testing.expect(false),
    }
}
