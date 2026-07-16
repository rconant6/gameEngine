const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DrawCall(comptime Key: type) type {
    return struct {
        key: Key,
        sort_key: u64, // (band + z) | submission_seq (set at push)
        index_start: u32, // into the indices
        index_count: u32,
        base_vertex: u32, // added to each index by the GPU
    };
}

pub fn IndexedBatch(comptime Vertex: type, comptime Key: type) type {
    return struct {
        const Self = @This();

        vertices: std.ArrayList(Vertex),
        idxs: std.ArrayList(u16),
        draw_calls: std.ArrayList(DrawCall(Key)),
        persistent: Allocator, // renderer.persistent

        pub fn init(gpa_p: Allocator) Self {
            return .{
                .vertices = .empty,
                .draw_calls = .empty,
                .indices = .empty,
                .persistent = gpa_p,
            };
        }
        pub fn deinit(self: *Self) void {
            self.indices.deinit(self.persistent);
            self.vertices.deinit(self.persistent);
            self.draw_calls.deinit(self.persistent);
        }
        pub fn clear(self: *Self) void {
            self.indices.clearRetainingCapacity();
            self.vertices.clearRetainingCapacity();
            self.draw_calls.clearRetainingCapacity();
        }

        pub fn vertexMark(self: *const Self) u32 {
            return @intCast(self.vertices.items.len);
        }
        pub fn indexMark(self: *const Self) u32 {
            return @intCast(self.indices.items.len);
        }

        pub fn vertex(self: *Self, v: Vertex) !void {
            try self.vertices.append(self.persistent, v);
        }
        pub fn index(self: *Self, i: u16) !void {
            try self.indices.append(self.persistent, i);
        }
        pub fn indices(self: *Self, idxs: []u16) !void {
            try self.indices.appendSlice(self.persistent, idxs);
        }

        pub fn pushIndexed(
            self: *Self,
            key: Key,
            sort_key: u64,
            index_start: u32,
            index_count: u32,
            base_vertex: u32,
        ) !void {
            try self.draw_calls.append(
                self.persistent,
                .{
                    .key = key,
                    .sort_key = sort_key,
                    .vertex_start = base_vertex,
                    .vertex_count = self.vertices.items.len - base_vertex,
                    .index_start = index_start,
                    .index_count = index_count,
                    .base_vertex = base_vertex,
                },
            );
        }

        pub fn sortCalls(self: *Self) void {
            std.sort.pdq(
                DrawCall(Key),
                self.draw_calls.items,
                {},
                lessBySortKey,
            );
        }

        fn lessBySortKey(a: DrawCall(Key), b: DrawCall(Key)) bool {
            return a.sort_key < b.sort_key;
        }
    };
}
