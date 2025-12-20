const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Entity = @import("Entity.zig");

pub fn ComponentStorage(comptime T: type) type {
    return struct {
        pub const Iterator = struct {
            pub const Entry = struct {
                entity: Entity,
                component: *const T,
            };

            storage: *const ComponentStorage(T),
            index: usize,

            pub fn next(self: *Iterator) ?Entry {
                if (self.index >= self.storage.dense.items.len) return null;

                const res: Entry = .{
                    .entity = self.storage.entities.items[self.index],
                    .component = &self.storage.dense.items[self.index],
                };

                self.index += 1;

                return res;
            }
        };

        pub const ComponentType = T;

        sparse: ArrayList(?usize), // entity_id -> dense index
        dense: ArrayList(T), // component data
        entities: ArrayList(usize), // dense_index -> entity_id
        gpa: Allocator,

        const DEFAULT_SPARSE_CAPACITY = 1024;

        pub fn init(alloc: Allocator) !@This() {
            var sparse_arry: ArrayList(?usize) = try .initCapacity(
                alloc,
                DEFAULT_SPARSE_CAPACITY,
            );
            sparse_arry.items.len = DEFAULT_SPARSE_CAPACITY;
            @memset(sparse_arry.items, null);

            return .{
                .sparse = sparse_arry,
                .dense = .empty,
                .entities = .empty,
                .gpa = alloc,
            };
        }
        pub fn deinit(self: *@This()) void {
            self.sparse.deinit(self.gpa);
            self.dense.deinit(self.gpa);
            self.entities.deinit(self.gpa);
        }

        pub fn add(self: *@This(), entity_id: usize, component: T) !void {
            if (entity_id >= self.sparse.items.len) {
                const old_len = self.sparse.items.len;
                try self.sparse.resize(self.gpa, entity_id + 1);
                @memset(self.sparse.items[old_len..], null);
            }
            if (self.sparse.items[entity_id] != null) return error.ComponentAlreadyExists;

            const dense_index = self.dense.items.len;
            try self.dense.append(self.gpa, component);
            try self.entities.append(self.gpa, entity_id);
            self.sparse.items[entity_id] = dense_index;
        }
        pub fn remove(self: *@This(), entity_id: usize) void {
            if (entity_id >= self.sparse.items.len or
                self.sparse.items[entity_id] == null)
                return;

            const last_index = self.dense.items.len - 1;
            std.debug.assert(last_index == self.entities.items.len - 1);
            const dense_index = self.sparse.items[entity_id].?;

            if (@hasDecl(T, "deinit")) {
                self.dense.items[dense_index].deinit();
            }

            std.debug.assert(last_index == self.entities.items.len - 1);
            if (last_index != dense_index) {
                self.dense.items[dense_index] = self.dense.items[last_index];
                self.entities.items[dense_index] = self.entities.items[last_index];
                self.sparse.items[self.entities.items[dense_index]] = dense_index;
            }

            _ = self.dense.pop();
            _ = self.entities.pop();

            self.sparse.items[entity_id] = null;
        }

        pub fn get(self: *const @This(), entity_id: usize) ?*const T {
            if (entity_id >= self.sparse.items.len) return null;
            const dense_index = self.sparse.items[entity_id] orelse return null;
            return &self.dense.items[dense_index];
        }
        pub fn getMut(self: *@This(), entity_id: usize) ?*T {
            if (entity_id >= self.sparse.items.len) return null;
            const dense_index = self.sparse.items[entity_id] orelse return null;
            return &self.dense.items[dense_index];
        }
        pub fn set(self: *@This(), entity_id: usize, component: T) !void {
            if (entity_id >= self.sparse.items.len) return try self.add(
                entity_id,
                component,
            );
            const dense_index = self.sparse.items[entity_id] orelse return try self.add(
                entity_id,
                component,
            );
            self.dense.items[dense_index] = component;
        }

        pub fn has(self: *const @This(), entity_id: usize) bool {
            if (entity_id >= self.sparse.items.len) return false;
            return self.sparse.items[entity_id] != null;
        }

        pub fn clear(self: *@This()) void {
            self.sparse.clearRetainingCapacity();
            self.dense.clearRetainingCapacity();
            self.entities.clearRetainingCapacity();
        }

        pub fn iterator(self: *const @This()) Iterator {
            return .{
                .index = 0,
                .storage = self,
            };
        }
    };
}
