const std = @import("std");
const ArrayList = std.ArrayList;
const array_list = std.array_list;
const log = @import("debug").log;

pub fn CommandHistory(comptime T: type) type {
    return struct {
        const Self = @This();

        gpa: std.mem.Allocator,
        cmds: ArrayList(T),
        cursor: usize,

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{
                .gpa = alloc,
                .cmds = .empty,
                .cursor = 0,
            };
        }

        pub fn push(self: *Self, cmd: T) void {
            self.cmds.shrinkRetainingCapacity(self.cursor);

            self.cmds.append(self.gpa, cmd) catch |err| {
                log.err(
                    .application,
                    "Unable to store command: {any} for: {any}",
                    .{ cmd, err },
                );
            };
            self.cursor += 1;
        }
        pub fn undo(self: *Self) ?T {
            if (!self.canUndo()) return null;

            self.cursor -= 1;
            const res: ?T =
                self.cmds.items[self.cursor];

            return res;
        }
        pub fn redo(self: *Self) ?T {
            if (!self.canRedo()) return null;

            const res = self.cmds.items[self.cursor];
            self.cursor += 1;

            return res;
        }

        inline fn canUndo(self: Self) bool {
            return self.cursor > 0;
        }
        inline fn canRedo(self: Self) bool {
            return self.cursor < self.cmds.items.len;
        }
    };
}
