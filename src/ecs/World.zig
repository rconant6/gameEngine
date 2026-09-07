const Self = @This();
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Storages = std.StringHashMap(StorageInterface);
const Entity = @import("Entity.zig");
const Query = @import("Query.zig").Query;
const ComponentStorage = @import("ComponentStorage.zig").ComponentStorage;
const math = @import("math");
const V2 = math.V2;
const scene = @import("scene");
const TemplateManager = scene.TemplateManager;
const comps = @import("Components.zig");
const Tag = comps.Tag;
const debug = @import("debug");
const log = debug.log;

persistent: std.mem.Allocator,
next_entity_id: usize,
free_ids: ArrayList(usize), // recycled ids, LIFO
generations: ArrayList(u32), // indexed by id; bumped when destroyed
alive: ArrayList(bool),
component_storages: Storages,
template_manager: *TemplateManager = undefined, // gets set by engine on init

pub fn init(p_gpa: Allocator) !Self {
    var w: Self = .{
        .persistent = p_gpa,
        .next_entity_id = 1, // 0 is dummy/invalid entity
        .generations = .empty,
        .free_ids = .empty,
        .alive = .empty,
        .component_storages = Storages.init(p_gpa),
    };
    try w.generations.append(p_gpa, 0); // keep in sync w/ 0 being dummy entity
    try w.alive.append(p_gpa, false); // keep in sync w/ 0 being dummy entity

    return w;
}

pub fn deinit(self: *Self) void {
    log.info(.ecs, "ECS(world) shutting down...", .{});
    for (0..self.next_entity_id) |id| {
        // Sweep by occupancy, going straight to the raw destroy — a synthesized
        // handle would either be rejected (gen 0) or double-free a free slot.
        // This runs each live component's deinit before storage teardown below.
        if (self.alive.items[id]) self.destroyById(id);
    }

    var storage_iter = self.component_storages.valueIterator();
    while (storage_iter.next()) |interface| {
        interface.vtable.deinit(interface.ptr);
        interface.vtable.destroy(interface.ptr, self.persistent);
    }

    self.generations.deinit(self.persistent);
    self.free_ids.deinit(self.persistent);
    self.alive.deinit(self.persistent);

    self.component_storages.deinit();
}

pub fn createEntity(self: *Self) !Entity {
    if (self.free_ids.pop()) |id| {
        self.alive.items[id] = true;
        return .{
            .id = id,
            .gen = self.generations.items[id],
        };
    }
    const id = self.next_entity_id;
    self.next_entity_id += 1;
    try self.generations.append(self.persistent, 0);
    try self.alive.append(self.persistent, true);

    return .{ .id = id, .gen = 0 };
}

// The single destroy implementation, keyed by raw id. Removes every component
// (running their deinit via ComponentStorage.remove), frees the slot, and bumps
// the generation. Both the public handle door (destroyEntity) and the bulk
// sweeps (destroyAllExcept/deinit) route through here so storage is always
// actually cleared — never just hidden behind the isAlive accessor guard.
fn destroyById(self: *Self, id: usize) void {
    var iter = self.component_storages.valueIterator();
    while (iter.next()) |interface| {
        if (interface.vtable.has(interface.ptr, id)) {
            interface.vtable.remove(interface.ptr, id);
        }
    }

    self.alive.items[id] = false;
    self.generations.items[id] +%= 1;
    self.free_ids.append(self.persistent, id) catch |err| {
        log.warn(
            .ecs,
            "Unable to append {d}, unable to recycle.  {any}",
            .{ id, err },
        );
    };
}

pub fn destroyEntity(self: *Self, e: Entity) void {
    if (!self.isAlive(e)) return;
    self.destroyById(e.id);
}

pub fn isAlive(self: *const Self, e: Entity) bool {
    return e.id != 0 and
        e.id < self.generations.items.len and
        self.alive.items[e.id] and // occupied — not merely gen-matched
        self.generations.items[e.id] == e.gen;
}

pub fn destroyAllExcept(self: *Self, keep: Entity) void {
    for (0..self.next_entity_id) |id| {
        if (id == keep.id) continue;
        if (!self.alive.items[id]) continue;

        self.destroyById(id);
    }
}
pub fn createEntityFromTemplate(
    self: *Self,
    template: []const u8,
    offset: V2,
) !Entity {
    return self.template_manager.instantiate(template, offset);
}

pub fn addComponent(self: *Self, e: Entity, comptime T: type, value: T) !void {
    if (!self.isAlive(e)) return error.EntityDoesNotExist;

    if (!self.component_storages.contains(@typeName(T))) {
        try self.registerComponent(T);
    }

    const storage = self.getStorage(T);
    try storage.add(e.id, value);
}
pub fn removeComponent(self: *Self, e: Entity, comptime T: type) void {
    if (!self.isAlive(e)) return;

    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return;

    const storage = self.getStorage(T);
    storage.remove(e.id);
}

pub fn hasComponent(self: *Self, e: Entity, comptime T: type) bool {
    if (!self.isAlive(e)) return false;

    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return false;

    const storage = self.getStorage(T);
    return storage.has(e.id);
}
pub fn getComponent(self: *const Self, e: Entity, comptime T: type) ?*const T {
    if (!self.isAlive(e)) return null;

    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return null;

    const storage = self.getStorage(T);
    return storage.get(e.id);
}
pub fn getComponentMut(self: *Self, e: Entity, comptime T: type) ?*T {
    if (!self.isAlive(e)) return null;

    const name = @typeName(T);
    if (!self.component_storages.contains(name)) return null;

    const storage = self.getStorage(T);
    return storage.getMut(e.id);
}

pub fn findEntityByTag(self: *Self, tag: []const u8) ?Entity {
    var q = self.query(.{Tag});
    while (q.next()) |entry| {
        const tags = entry.get(0);
        if (tags.hasTag(tag)) return entry.entity;
    }
    return null;
}
pub fn findEntitiesByTag(
    self: *Self,
    tag: []const u8,
    frame: Allocator,
) []Entity {
    var entities: ArrayList(Entity) = .empty;
    errdefer entities.deinit(frame);
    var q = self.query(.{Tag});
    while (q.next()) |entry| {
        const tags = entry.get(0);
        if (tags.hasTag(tag))
            entities.append(frame, entry.entity) catch |e| {
                log.err(.ecs, "Unable to append entity(tag) {t}", .{e});
            };
    }
    return entities.toOwnedSlice(frame) catch &[_]Entity{};
}
pub fn findEntitiesByPattern(
    self: *Self,
    pattern: []const u8,
    frame: Allocator,
) []Entity {
    var entities: ArrayList(Entity) = .empty;
    errdefer entities.deinit(frame);
    var q = self.query(.{Tag});
    while (q.next()) |entry| {
        const tags = entry.get(0);
        if (tags.matchesPattern(pattern))
            entities.append(frame, entry.entity) catch |e| {
                log.err(.ecs, "Unable to append entity(pattern) {t}", .{e});
            };
    }
    return entities.toOwnedSlice(frame) catch &[_]Entity{};
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

    return Query(StorageTupleType).init(storages, self.generations.items);
}
fn buildStorageTupleType(comptime component_types: anytype) type {
    const num = std.meta.fields(@TypeOf(component_types)).len;
    var types: [num]type = undefined;
    inline for (0..num) |i| {
        types[i] = *ComponentStorage(component_types[i]);
    }
    return @Tuple(&types);
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
    const storage = try self.persistent.create(StorageType);
    storage.* = try ComponentStorage(T).init(self.persistent);

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
        fn destroy(ptr: *anyopaque, persistent: Allocator) void {
            const self: *ComponentStorage(T) = @ptrCast(@alignCast(ptr));
            persistent.destroy(self);
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
