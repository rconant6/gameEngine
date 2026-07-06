const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DrawCall(comptime Key: type) type {
    return struct {
        key: Key,
        vertex_start: u32,
        vertex_count: u32,
    };
}

pub fn Batch(comptime Vertex: type, comptime Key: type) type {
    return struct {
        const Self = @This();
        vertices: std.ArrayList(Vertex),
        draw_calls: std.ArrayList(DrawCall(Key)),
        persistent: Allocator, // renderer.persistent

        pub fn init(gpa_p: Allocator) Self {
            return .{
                .vertices = .empty,
                .draw_calls = .empty,
                .persistent = gpa_p,
            };
        }
        pub fn deinit(self: *Self) void {
            self.vertices.deinit(self.persistent);
            self.draw_calls.deinit(self.persistent);
        }

        pub fn clear(self: *Self) void {
            self.vertices.clearRetainingCapacity();
            self.draw_calls.clearRetainingCapacity();
        }

        pub fn mark(self: *const Self) u32 {
            return @intCast(self.vertices.items.len);
        }

        pub fn vertex(self: *Self, v: Vertex) !void {
            try self.vertices.append(self.persistent, v);
        }

        pub fn pushCall(
            self: *Self,
            key: Key,
            start: u32,
            count: u32,
        ) !void {
            if (self.draw_calls.items.len > 0) {
                const last = &self.draw_calls.items[self.draw_calls.items.len - 1];
                if (last.key.eql(key) and
                    (last.vertex_start + last.vertex_count) == start)
                {
                    last.vertex_count += count;
                    return;
                }
            }
            try self.draw_calls.append(
                self.persistent,
                .{ .key = key, .vertex_start = start, .vertex_count = count },
            );
        }
    };
}
