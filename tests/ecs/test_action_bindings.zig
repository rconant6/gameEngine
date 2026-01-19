const std = @import("std");
const testing = std.testing;
const Action = @import("Action");
const ActionBindings = Action.ActionBindings;
const V2 = @import("math").V2;

// Mock trigger type for testing the generic
const TestTrigger = struct {
    condition: []const u8,
    actions: []const Action.Action,

    pub fn deinit(self: *TestTrigger, gpa: std.mem.Allocator) void {
        // Test triggers don't own their data, so nothing to free
        _ = self;
        _ = gpa;
    }
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

    var triggers_array = [_]TestTrigger{trigger};
    const test_bindings = OnTest{
        .triggers = &triggers_array,
    };

    try testing.expectEqual(@as(usize, 1), test_bindings.triggers.len);
    try testing.expectEqualStrings("test_condition", test_bindings.triggers[0].condition);
    try testing.expectEqual(@as(usize, 1), test_bindings.triggers[0].actions.len);
}

test "ActionBindings - hasTriggers helper" {
    const OnTest = ActionBindings(TestTrigger);

    var with_triggers_array = [_]TestTrigger{.{
        .condition = "test",
        .actions = &[_]Action.Action{},
    }};
    const with_triggers = OnTest{
        .triggers = &with_triggers_array,
    };

    var without_triggers_array = [_]TestTrigger{};
    const without_triggers = OnTest{
        .triggers = &without_triggers_array,
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

    var triggers_array = [_]TestTrigger{ trigger1, trigger2 };
    const test_bindings = OnTest{
        .triggers = &triggers_array,
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

    var triggers_array = [_]TestTrigger{trigger};
    const test_bindings = OnTest{
        .triggers = &triggers_array,
    };

    try testing.expectEqual(@as(usize, 1), test_bindings.triggers.len);
    try testing.expectEqual(@as(usize, 3), test_bindings.triggers[0].actions.len);
}
