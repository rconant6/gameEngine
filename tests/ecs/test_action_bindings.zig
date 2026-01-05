const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const ActionBindings = Action.ActionBindings;
const V2 = @import("core").V2;

// Mock trigger type for testing the generic
const TestTrigger = struct {
    condition: []const u8,
    actions: []const Action.Action,
};

test "ActionBindings - generic instantiation with TestTrigger" {
    const OnTest = ActionBindings(TestTrigger);

    const test_action = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const trigger = TestTrigger{
        .condition = "test_condition",
        .actions = &[_]Action.Action{test_action},
    };

    const test_bindings = OnTest{
        .triggers = &[_]TestTrigger{trigger},
    };

    try testing.expectEqual(@as(usize, 1), test_bindings.triggers.len);
    try testing.expectEqualStrings("test_condition", test_bindings.triggers[0].condition);
    try testing.expectEqual(@as(usize, 1), test_bindings.triggers[0].actions.len);
}

test "ActionBindings - hasTriggers helper" {
    const OnTest = ActionBindings(TestTrigger);

    const with_triggers = OnTest{
        .triggers = &[_]TestTrigger{.{
            .condition = "test",
            .actions = &[_]Action.Action{},
        }},
    };

    const without_triggers = OnTest{
        .triggers = &[_]TestTrigger{},
    };

    try testing.expect(with_triggers.hasTriggers());
    try testing.expect(!without_triggers.hasTriggers());
}

test "ActionBindings - multiple triggers" {
    const OnTest = ActionBindings(TestTrigger);

    const action1 = Action.Action{
        .action_type = .destroy_self,
        .priority = 0,
    };

    const action2 = Action.Action{
        .action_type = .destroy_other,
        .priority = 1,
    };

    const trigger1 = TestTrigger{
        .condition = "condition1",
        .actions = &[_]Action.Action{action1},
    };

    const trigger2 = TestTrigger{
        .condition = "condition2",
        .actions = &[_]Action.Action{action2},
    };

    const test_bindings = OnTest{
        .triggers = &[_]TestTrigger{ trigger1, trigger2 },
    };

    try testing.expectEqual(@as(usize, 2), test_bindings.triggers.len);
    try testing.expectEqualStrings("condition1", test_bindings.triggers[0].condition);
    try testing.expectEqualStrings("condition2", test_bindings.triggers[1].condition);
}

test "ActionBindings - trigger with multiple actions" {
    const OnTest = ActionBindings(TestTrigger);

    const actions = [_]Action.Action{
        .{ .action_type = .destroy_self, .priority = 0 },
        .{ .action_type = .destroy_other, .priority = 1 },
        .{ .action_type = .{ .play_sound = "boom" }, .priority = 2 },
    };

    const trigger = TestTrigger{
        .condition = "multi_action",
        .actions = &actions,
    };

    const test_bindings = OnTest{
        .triggers = &[_]TestTrigger{trigger},
    };

    try testing.expectEqual(@as(usize, 1), test_bindings.triggers.len);
    try testing.expectEqual(@as(usize, 3), test_bindings.triggers[0].actions.len);
}
