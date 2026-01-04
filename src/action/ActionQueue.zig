const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ecs = @import("entity");
const Entity = ecs.Entity;
const action_mod = @import("Action.zig");
const Action = action_mod.Action;
const V2 = @import("core").V2;

pub const ActionContext = struct {
    self_ent: Entity,
    other_ent: ?Entity,
    collision_loc: ?V2,
};

pub const QueuedAction = struct {
    action: Action,
    context: ActionContext,
};

pub const ActionQueue = struct {
    allocator: Allocator,
    actions: ArrayList(QueuedAction),

    pub fn init(allocator: Allocator) ActionQueue {
        return .{ .allocator = allocator, .actions = .empty };
    }
    pub fn deinit(self: *ActionQueue) void {
        self.actions.deinit(self.allocator);
    }

    pub fn clear(self: *ActionQueue) void {
        self.actions.clearRetainingCapacity();
    }
    pub fn append(self: *ActionQueue, action: Action, context: ActionContext) !void {
        try self.actions.append(
            self.allocator,
            .{ .action = action, .context = context },
        );
    }
    pub fn sortByPriority(self: *ActionQueue) void {
        std.mem.sort(QueuedAction, self.actions.items[0..], {}, compareAction);
    }

    fn compareAction(_: void, lhs: QueuedAction, rhs: QueuedAction) bool {
        return lhs.action.priority < rhs.action.priority;
    }
};
