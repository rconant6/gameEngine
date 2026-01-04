const Self = @This();
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Storages = std.StringHashMap(StorageInterface);
const Entity = @import("Entity.zig");
const Query = @import("Query.zig").Query;
const ComponentStorage = @import("ComponentStorage.zig").ComponentStorage;

allocator: std.mem.Allocator,
next_entity_id: usize,
component_storages: Storages,

pub fn init(alloc: Allocator) !Self {
    return .{
        .allocator = alloc,
        .next_entity_id = 1, // 0 is dummy/invalid entity
        .component_storages = Storages.init(alloc),
    };
}
pub fn deinit(self: *Self) void {
    for (0..self.next_entity_id) |entity_id| {
        self.destroyEntity(Entity{ .id = entity_id });
    }

    var storage_iter = self.component_storages.valueIterator();
    while (storage_iter.next()) |interface| {
        interface.vtable.deinit(interface.ptr);
        interface.vtable.destroy(interface.ptr, self.allocator);
    }
    self.component_storages.deinit();
}

pub fn createEntity(self: *Self) !Entity {
    const entity: Entity = .{ .id = self.next_entity_id };
    self.next_entity_id += 1;
    return entity;
}
pub fn destroyEntity(self: *Self, entity: Entity) void {
    var iter = self.component_storages.valueIterator();
    while (iter.next()) |interface| {
        if (interface.vtable.has(interface.ptr, entity.id)) {
            interface.vtable.remove(interface.ptr, entity.id);
        }
    }
}

pub fn addComponent(self: *Self, entity: Entity, comptime T: type, value: T) !void {
    if (!self.component_storages.contains(@typeName(T))) {
        try self.registerComponent(T);
    }

    const storage = self.getStorage(T);
    try storage.add(entity.id, value);
}
pub fn removeComponent(self: *Self, entity: Entity, comptime T: type) void {
    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return;

    const storage = self.getStorage(T);
    storage.remove(entity.id);
}

pub fn hasComponent(self: *Self, entity: Entity, comptime T: type) bool {
    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return false;

    const storage = self.getStorage(T);
    return storage.has(entity.id);
}
pub fn getComponent(self: *Self, entity: Entity, comptime T: type) ?*const T {
    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return null;

    const storage = self.getStorage(T);
    return storage.get(entity.id);
}
pub fn getComponentMut(self: *Self, entity: Entity, comptime T: type) ?*T {
    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return null;

    const storage = self.getStorage(T);
    return storage.getMut(entity.id);
}

pub fn query(self: *Self, comptime component_types: anytype) Query(buildStorageTupleType(component_types)) {
    inline for (0..std.meta.fields(@TypeOf(component_types)).len) |i| {
        const T = component_types[i];
        const name = @typeName(T);
        if (!self.component_storages.contains(name)) {
            self.registerComponent(T) catch |err| {
                std.debug.panic("Failed to register component {s}: {}", .{ name, err });
            };
        }
    }

    const StorageTupleType = buildStorageTupleType(component_types);
    var storages: StorageTupleType = undefined;

    inline for (0..std.meta.fields(@TypeOf(component_types)).len) |i| {
        @field(storages, std.fmt.comptimePrint("{d}", .{i})) = self.getStorage(component_types[i]);
    }

    return Query(StorageTupleType).init(storages);
}
fn buildStorageTupleType(comptime component_types: anytype) type {
    const num = std.meta.fields(@TypeOf(component_types)).len;
    var fields: [num]std.builtin.Type.StructField = undefined;

    inline for (0..num) |i| {
        const T = component_types[i];
        fields[i] = .{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = *ComponentStorage(T),
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(*ComponentStorage(T)),
        };
    }

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = true,
    } });
}

fn getStorage(self: *const Self, comptime T: type) *ComponentStorage(T) {
    const name = @typeName(T);
    const interface = self.component_storages.get(name).?;
    return @ptrCast(@alignCast(interface.ptr));
}

fn registerComponent(self: *Self, comptime T: type) !void {
    const name = @typeName(T);
    if (self.component_storages.contains(name)) return error.ComponentAlreadyRegistered;

    const StorageType = ComponentStorage(T);
    const storage = try self.allocator.create(StorageType);
    storage.* = try ComponentStorage(T).init(self.allocator);

    try self.component_storages.put(name, wrapStorage(T, storage));
}

const StorageInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        remove: *const fn (*anyopaque, usize) void,
        has: *const fn (*anyopaque, usize) bool,
        deinit: *const fn (*anyopaque) void,
        destroy: *const fn (*anyopaque, Allocator) void,
    };
};

fn wrapStorage(comptime T: type, storage: *ComponentStorage(T)) StorageInterface {
    const Impl = struct {
        fn remove(ptr: *anyopaque, entity: usize) void {
            const self: *ComponentStorage(T) = @ptrCast(@alignCast(ptr));
            self.remove(entity);
        }
        fn has(ptr: *anyopaque, entity: usize) bool {
            const self: *ComponentStorage(T) = @ptrCast(@alignCast(ptr));
            return self.has(entity);
        }
        fn deinit(ptr: *anyopaque) void {
            const self: *ComponentStorage(T) = @ptrCast(@alignCast(ptr));
            self.deinit();
        }
        fn destroy(ptr: *anyopaque, allocator: Allocator) void {
            const self: *ComponentStorage(T) = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }

        const vtable = StorageInterface.VTable{
            .remove = remove,
            .has = has,
            .destroy = destroy,
            .deinit = @This().deinit,
        };
    };

    return .{ .ptr = storage, .vtable = &Impl.vtable };
}
