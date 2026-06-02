//! A structured allocator taxonomy for Zig applications.
//!
//! Wraps std allocators with named lifetimes so every allocation
//! declares its intent at the call site. If you need something
//! beyond what this provides, use std.mem directly.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Self = @This();

pub const AssetMemory = struct {
    fonts: Allocator = undefined,
    textures: Allocator = undefined,
};

// then as a field on the struct:
// pub fn Pool(comptime T: type, size: usize) *Pool(T) {
//     return struct {

//     };
// }

// Private backing of the memory system not to be exposed or used
// Should not be used outside of Memory.zig
_temp_arena: Arena,

// GameEngine Related
_frame_arena: Arena,
_font_arena: Arena,
_texture_arena: Arena,

// Public facing interfaces to force proper selection
persistent: Allocator, // raw backing, individual alloc/free
temp: Allocator, // reset by the caller (defer usage)

// GameEngine Related
frame: Allocator, // resets for each tickFrame() (endFrame/beginFrame)
asset: AssetMemory,

pub fn init(self: *Self, backing: Allocator) void {
    self._frame_arena = .init(backing);
    self._temp_arena = .init(backing);
    self._font_arena = .init(backing);
    self._texture_arena = .init(backing);
    self.persistent = backing;
    self.frame = self._frame_arena.allocator();
    self.temp = self._temp_arena.allocator();
    self.asset = .{
        .fonts = self._font_arena.allocator(),
        .textures = self._texture_arena.allocator(),
    };
}
pub fn deinit(self: *Self) void {
    self._frame_arena.deinit();
    self._temp_arena.deinit();
    self._font_arena.deinit();
    self._texture_arena.deinit();
}

// GameEngine Related
pub fn tickFrame(self: *Self) void {
    _ = self._frame_arena.reset(.retain_capacity);
}

// Requires the caller to destroy
pub fn persistentCreate(self: *Self, comptime T: type) !*T {
    return try self.persistent.create(T);
}
pub fn persistentAlloc(self: *Self, comptime T: type, count: usize) ![]T {
    return try self.persistent.alloc(T, count);
}
pub fn persistentDestroy(self: *Self, ptr: anytype) void {
    self.persistent.destroy(ptr);
}
pub fn persistentFree(self: *Self, ptr: anytype) void {
    self.persistent.free(ptr);
}

pub fn frameCreate(self: *Self, comptime T: type) !*T {
    return try self.frame.create(T);
}
pub fn frameAlloc(self: *Self, comptime T: type, count: usize) ![]T {
    return try self.frame.alloc(T, count);
}
pub fn frameDupe(self: *Self, comptime T: type, data: []const T) ![]T {
    return try self.frame.dupe(T, data);
}
pub fn frameDestroy(self: *Self, ptr: anytype) void {
    self.frame.destroy(ptr);
}
pub fn frameFree(self: *Self, ptr: anytype) void {
    self.frame.free(ptr);
}

pub fn tempAlloc(self: *Self, comptime T: type, count: usize) ![]T {
    return try self.temp.alloc(T, count);
}
pub fn tempDupe(self: *Self, comptime T: type, data: []const T) ![]T {
    return try self.temp.dupe(T, data);
}
pub fn tempFree(self: *Self, ptr: anytype) void {
    self.temp.free(ptr);
}
