const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DrawCall(comptime Key: type) type {
    return struct {
        key: Key,
        sort_key: u64, // (band + z) | submission_seq (set at push)
        index_start: u32, // into the indices
        index_count: u32,
    };
}

pub fn IndexedBatch(comptime Vertex: type, comptime Key: type) type {
    return struct {
        const Self = @This();

        vertices: std.ArrayList(Vertex),
        indices: std.ArrayList(u32),
        draw_calls: std.ArrayList(DrawCall(Key)),
        persistent: Allocator, // renderer.persistent

        pub fn init(persistent: Allocator) Self {
            return .{
                .vertices = .empty,
                .draw_calls = .empty,
                .indices = .empty,
                .persistent = persistent,
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

        pub fn appendVertex(self: *Self, v: Vertex) !void {
            try self.vertices.append(self.persistent, v);
        }
        pub fn appendIndex(self: *Self, i: u32) !void {
            try self.indices.append(self.persistent, i);
        }
        pub fn appendIndices(self: *Self, idxs: []const u32) !void {
            try self.indices.appendSlice(self.persistent, idxs);
        }

        pub fn pushIndexed(
            self: *Self,
            key: Key,
            sort_key: u64,
            index_start: u32,
            index_count: u32,
        ) !void {
            try self.draw_calls.append(
                self.persistent,
                .{
                    .key = key,
                    .sort_key = sort_key,
                    .index_start = index_start,
                    .index_count = index_count,
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

        fn lessBySortKey(_: void, a: DrawCall(Key), b: DrawCall(Key)) bool {
            return a.sort_key < b.sort_key;
        }

        pub fn mergeAdjacent(self: *Self) void {
            const calls = self.draw_calls.items;
            if (calls.len <= 1) return;

            var write: usize = 0;
            for (calls[1..]) |cur| {
                const prev = &calls[write];
                const contiguous =
                    prev.index_start + prev.index_count == cur.index_start;
                if (prev.key.eql(cur.key) and contiguous) {
                    prev.index_count += cur.index_count;
                } else {
                    write += 1;
                    calls[write] = cur;
                }
            }
            self.draw_calls.shrinkRetainingCapacity(write + 1);
        }
    };
}
